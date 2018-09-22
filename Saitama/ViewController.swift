//
//  ViewController.swift
//  Saitama
//
//  Created by Akifumi Fujita on 2018/09/20.
//  Copyright © 2018年 Yenom. All rights reserved.
//

import UIKit
import BitcoinKit

class ViewController: UIViewController {
    @IBOutlet weak var qrCodeImageView: UIImageView!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var balanceLabel: UILabel!
    @IBOutlet private weak var destinationAddressTextField: UITextField!
    
    private lazy var dataStore: BitcoinKitDataStoreProtocol = {
        if Config.isMainNet {
            return UserDefaults.bitcoinKit
        } else {
            return UserDefaults(suiteName: "Test")!
        }
    }()
    
    private lazy var wallet: Wallet? = {
        if Config.isMainNet {
            return Wallet(dataStore: dataStore)
        } else {
            return Wallet()
        }
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        createWalletIfNeeded()
        updateLabels()
        
        testMockScript()
    }
    
    func createWalletIfNeeded() {
        if wallet == nil {
            // TODO: - 1. Walletの作成
            // TODO: 1-1. Private Keyの生成
            let privateKey: PrivateKey
            if Config.isMainNet {
                privateKey = PrivateKey(network: .mainnet)
            } else {
                privateKey = PrivateKey(network: .testnet)
            }
            
            // TODO: 1-2. Walletの生成
            wallet = Wallet(privateKey: privateKey, dataStore: dataStore)
            
            // TODO: 1-3. Walletの保存
            // wallet?."WRITE ME"
            wallet?.save()
        }
    }
    
    func updateLabels() {
        // TODO: - 2. Addressの表示
        // TODO: 2-1. Addressのprint
        print(wallet?.address.cashaddr ?? "")
        // TODO: 2-2. Addressを表示
        addressLabel.text = wallet?.address.cashaddr
        // TODO: 2-3. AddressのQRCodeを表示
        qrCodeImageView.image = wallet?.address.qrImage(size: qrCodeImageView.frame.size)
        
        
        // TODO: - 3. Balanceの表示
        // TODO: 3-1. Balanceの表示
        if let balance = wallet?.balance() {
            balanceLabel.text = "Balance : \(balance) satoshi"
        }
    }
    
    func reloadBalance() {
        // TODO: 3-2. Balanceの更新
        // "WRITE ME"
        wallet?.reloadBalance(completion: { [weak self] (_) in
            DispatchQueue.main.async {
                self?.updateLabels()
            }
        })
    }
    
    @IBAction func didTapReloadBalanceButton(_ sender: UIButton) {
        reloadBalance()
    }
    
    @IBAction func didTapSendButton(_ sender: UIButton) {
        // TODO: NFCから読み取り
        let seatPublicKeyData: Data = MockKey.keyB.pubkey.data
        let amount: Int64 = 1000
        sendToSeat(seatPublicKeyData: seatPublicKeyData, amount: amount)
    }
    
    private func send() {
//        let addressString = "bchtest:qpytf7xczxf2mxa3gd6s30rthpts0tmtgyw8ud2sy3"
        guard let addressString = destinationAddressTextField.text else {
            return
        }

        do {
            // TODO: - 4. 送金する
            // TODO: 4-1. アドレスの生成
            // let address: Address = "WRITE ME"
            let address = try AddressFactory.create(addressString)
            
            // TODO: 4-2. ウォレットから送金 [送金完了後、reloadBalanceもやろう！]
            try wallet?.send(to: address, amount: 1000, completion: { [weak self] (response) in
                print("送金完了　txid : ", response ?? "")
                self?.reloadBalance()
            })
        } catch {
            print(error)
        }
    }
    
    private func sendToSeat(seatPublicKeyData: Data, amount: Int64) {
        let amount: UInt64 = 1000
        do {
            try customSend(to: seatPublicKeyData, amount: amount) { [weak self] (response) in
                print("送金完了　txid : ", response ?? "")
                self?.reloadBalance()
            }
        } catch {
            print(error)
        }
    }
    
    func customSend(to seatPublicKeyData: Data, amount: UInt64, completion: ((String?) -> Void)?) throws {
        guard let wallet = wallet else {
            return
        }
        // TODO: Output address も集める必要がある
        let utxos = wallet.utxos()
        let (utxosToSpend, fee) = try StandardUtxoSelector().select(from: utxos, targetValue: amount)
        let totalAmount: UInt64 = utxosToSpend.reduce(UInt64()) { $0 + $1.output.value }
        let change: UInt64 = totalAmount - amount - fee
        
        // ここがカスタム！
        let unsignedTx = try SendUtility.customTransactionBuild(to: (wallet.address, amount), change: (wallet.address, change), keys: (wallet.publicKey.data, seatPublicKeyData), utxos: utxosToSpend)
        let signedTx = try SendUtility.customTransactionSign(unsignedTx, with: [wallet.privateKey])
        
        let rawtx = signedTx.serialized().hex
        if Config.isMainNet {
            BitcoinComTransactionBroadcaster(network: .mainnet).post(rawtx, completion: completion)
        } else {
            BitcoinComTransactionBroadcaster(network: .testnet).post(rawtx, completion: completion)
        }
    }
}

// MARK: - Hello, Bitcoin Script!以降で使用します
func testMockScript() {
    do {
//        // 5. 単純な計算のScript
//        let result1 = try MockHelper.verifySingleKey(lockScript: simpleCalculation.lockScript, unlockScriptBuilder: simpleCalculation.UnlockScriptBuilder(), key: MockKey.keyA)
//        print("Mock result1: \(result1)")
//
//        // 6. P2PKHのScript
//        let result2 = try MockHelper.verifySingleKey(lockScript: P2PKH.lockScript, unlockScriptBuilder: P2PKH.UnlockScriptBuilder(), key: MockKey.keyA)
//        print("Mock result2: \(result2)")
//
//        // 7. 2 of 3 の MultisigのScript
//        let result3 = try MockHelper.verifyMultiKey(lockScript: Multisig2of3.lockScript, unlockScriptBuilder: Multisig2of3.UnlockScriptBuilder(), keys: [MockKey.keyA, MockKey.keyB], verbose: true)
//        print("Mock result3: \(result3)")
//
//        // 8. P2SH形式のMultisig
//        let result4 = try MockHelper.verifySingleKey(lockScript: P2SHMultisig.lockScript, unlockScriptBuilder: P2SHMultisig.UnlockScriptBuilder(), key: MockKey.keyA)
//        print("Mock result4: \(result4)")
//
//        // 9. OP_IFを使ったScript
//        let result5 = try MockHelper.verifySingleKey(lockScript: OPIF.lockScript, unlockScriptBuilder: OPIF.UnlockScriptBuilder(), key: MockKey.keyB, verbose: true)
//        print("Mock result5: \(result5)")
    } catch let error {
        print("Mock Script Error: \(error)")
    }
}
