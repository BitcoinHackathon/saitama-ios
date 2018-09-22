//
//  SendUtility.swift
//  BitcoinKit-HandsOn
//
//  Created by Akifumi Fujita on 2018/09/20.
//  Copyright © 2018年 Yenom. All rights reserved.
//

import Foundation
import BitcoinKit

class SendUtility {
    
    static func customTransactionBuild(to: (address: Address, amount: UInt64), change: (address: Address, amount: UInt64), utxos: [UnspentTransaction]) throws -> UnsignedTransaction {
        let lockScriptTo = try! Script()
            .append(.OP_DUP)
            .append(.OP_HASH160)
            .appendData(to.address.data)
            .append(.OP_EQUALVERIFY)
            .append(.OP_CHECKSIG)
        
        let lockScriptChange = Script(address: change.address)!
        
        // 9. OP_RETURNのOutputを作成する
        
        // 10. OP_CLTVのOutputを作成する
        
        let toOutput = TransactionOutput(value: to.amount, lockingScript: lockScriptTo.data)
        let changeOutput = TransactionOutput(value: change.amount, lockingScript: lockScriptChange.data)
        
        let outputs = [toOutput, changeOutput]
        
        let unsignedInputs = utxos.map { TransactionInput(previousOutput: $0.outpoint, signatureScript: Data(), sequence: UInt32.max) }
        let tx = Transaction(version: 1, inputs: unsignedInputs, outputs: outputs, lockTime: 0)
        return UnsignedTransaction(tx: tx, utxos: utxos)
    }
    
    static func customTransactionSign(_ unsignedTransaction: UnsignedTransaction, with keys: [PrivateKey]) throws -> Transaction {
        // Define Transaction
        var signingInputs: [TransactionInput]
        var signingTransaction: Transaction {
            let tx: Transaction = unsignedTransaction.tx
            return Transaction(version: tx.version, inputs: signingInputs, outputs: tx.outputs, lockTime: tx.lockTime)
        }
        
        // Sign
        signingInputs = unsignedTransaction.tx.inputs
        let hashType = SighashType.BCH.ALL
        for (i, utxo) in unsignedTransaction.utxos.enumerated() {
            // Select key
            let pubkeyHash: Data = Script.getPublicKeyHash(from: utxo.output.lockingScript)
            
            let keysOfUtxo: [PrivateKey] = keys.filter { $0.publicKey().pubkeyHash == pubkeyHash }
            guard let key = keysOfUtxo.first else {
                continue
            }
            
            // Sign transaction hash
            let sighash: Data = signingTransaction.signatureHash(for: utxo.output, inputIndex: i, hashType: SighashType.BCH.ALL)
            let signature: Data = try Crypto.sign(sighash, privateKey: key)
            let txin = signingInputs[i]
            let pubkey = key.publicKey()
            
            // Create Signature Script
            let sigWithHashType: Data = signature + UInt8(hashType)
            let unlockingScript: Script = try Script()
                .appendData(sigWithHashType)
                .appendData(pubkey.data)
            
            // Update TransactionInput
            signingInputs[i] = TransactionInput(previousOutput: txin.previousOutput, signatureScript: unlockingScript.data, sequence: txin.sequence)
        }
        return signingTransaction
    }
    
    static func string2ExpiryTime(dateString: String) -> Data {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let date = formatter.date(from: dateString)!
        let dateUnix: TimeInterval = date.timeIntervalSince1970
        return Data(from: Int32(dateUnix).littleEndian)
    }
    
    // 11. MultisigのP2SH形式のアドレスを作る
    static func createMultisigAddress() -> Address {
        return MockKey.keyA.pubkey.toCashaddr() // この一行は消して下さい
    }
}
