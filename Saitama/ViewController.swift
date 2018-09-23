//
//  ViewController.swift
//  Saitama
//
//  Created by Akifumi Fujita on 2018/09/20.
//  Copyright © 2018年 Yenom. All rights reserved.
//

import UIKit
import BitcoinKit

class CustomAddressProvider: AddressProvider {
    var addresses: [Address] = []
    
    func add(address: Address) {
        addresses.append(address)
    }
    
    func reload(keys: [PrivateKey], completion: (([Address]) -> Void)?) {
        addresses = keys.map { $0.publicKey().toCashaddr() }
        completion?(addresses)
    }
    
    func list() -> [Address] {
        return addresses
    }
}

class ViewController: UIViewController {
    @IBOutlet weak var qrCodeImageView: UIImageView!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var balanceLabel: UILabel!
    @IBOutlet private weak var destinationAddressTextField: UITextField!
    @IBOutlet private weak var nfcButton: UIButton! {
        didSet {
            nfcButton.layer.cornerRadius = 4.0
            nfcButton.layer.masksToBounds = true
        }
    }
    @IBOutlet weak var leaveButton: UIButton! {
        didSet {
            leaveButton.layer.cornerRadius = 4.0
            leaveButton.layer.masksToBounds = true
        }
    }
    
    private lazy var dataStore: BitcoinKitDataStoreProtocol = {
        if Config.isMainNet {
            return UserDefaults.bitcoinKit
        } else {
            return UserDefaults(suiteName: "Test")!
        }
    }()
    
    private let addressProvider = CustomAddressProvider()
    
    private lazy var wallet: Wallet? = {
        let privateKey: PrivateKey
        if let wif = dataStore.getString(forKey: "wif") {
            privateKey = try! PrivateKey(wif: wif)
        } else {
            privateKey = PrivateKey(network: Config.network)
        }
        addressProvider.add(address: privateKey.publicKey().toCashaddr())
        return Wallet(privateKey: privateKey, dataStore: dataStore, addressProvider: addressProvider)
    }()
    
    private var seatPublicKeyDataString: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        createWalletIfNeeded()
        updateLabels()
        
        let pubKeyDataString = wallet?.publicKey.data.base64EncodedString() ?? ""
        print("pubKeyDataString: \(wallet?.publicKey.data.hex)")
        testMockScript()
        
        for utxo in wallet?.utxos() ?? [] {
            print("My utxo : ", Script(data: utxo.output.lockingScript)?.string)
        }
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
                print(self?.wallet?.utxos())
                self?.updateLabels()
            }
        })
    }
    
    @IBAction func didTapReloadBalanceButton(_ sender: UIButton) {
        reloadBalance()
    }
    
    @IBAction func didTapSendButton(_ sender: UIButton) {
        send()
    }
    
    private var redeemScript: Script?
    
    @IBAction func onNfcButtonTap(_ sender: Any) {
        // TODO: NFCから読み取り
        let pubKeyDataString = "A+/0m57I7oie5smTFallLudAjA5znuFCLZ8h0lrAfGrY" // iPhone X
        seatPublicKeyDataString = pubKeyDataString
        guard let seatPublicKeyDataString = seatPublicKeyDataString else { return }
        let seatPublicKeyData: Data = Data(base64Encoded: seatPublicKeyDataString)!
        let amount: UInt64 = 50000
        
        guard let wallet = wallet else { return }
        let utxos = wallet.utxos().filter { $0.output.lockingScript.count == 25 } // P2PKH only
        
        do {
            let (utxosToSpend, fee) = try StandardUtxoSelector().select(from: utxos, targetValue: amount)
            let totalAmount: UInt64 = utxosToSpend.reduce(UInt64()) { $0 + $1.output.value }
            let change: UInt64 = totalAmount - amount - fee * 2
            
            let (unsignedTx, redeemScript) = try SendUtility.customTransactionBuild(to: (wallet.address, amount), change: (wallet.address, change), keys: (wallet.publicKey.data, seatPublicKeyData), utxos: utxosToSpend)
            let signedTx = try SendUtility.customTransactionSign(unsignedTx, transactionType: .open, keys: [wallet.privateKey], pubKeyBData: seatPublicKeyData, redeemScript: redeemScript)
            
            let rawtx = signedTx.serialized().hex
            let network: BitcoinKit.Network = Config.isMainNet ? .mainnet : .testnet
            BitcoinComTransactionBroadcaster(network: network).post(rawtx) { [weak self] (response) in
                print("送金完了　txid : ", response ?? "")
                // TODO: UserDefaults
                self?.redeemScript = redeemScript
                print("redeeme script: \(redeemScript.data.hex)")
                
                let p2shAddress = redeemScript.standardP2SHAddress(network: network)
                print("P2SH address : \(p2shAddress)") // Cashaddr(data: redeemScript.toP2SH(), type: AddressType.scriptHash, network: .testnet)
                self?.addressProvider.add(address: p2shAddress)
                self?.reloadBalance()
            }
        } catch {
            print(error)
        }
    }
    
    @IBAction func onLeaveButtonTap(_ sender: Any) {
        guard let seatPublicKeyDataString = seatPublicKeyDataString, let seatPublicKeyData = Data(base64Encoded: seatPublicKeyDataString) else { return }
        guard let redeemScript = redeemScript else { return }
        guard let wallet = wallet else { return }
        
        let utxos = wallet.utxos().filter { $0.output.lockingScript.count == 23 } // P2SH only
        
        do {
            let utxo: UnspentTransaction = utxos.first!
            let utxosToSpend: [UnspentTransaction] = [utxo]
            let fee: UInt64 = 500
            let totalAmount: UInt64 = utxosToSpend.reduce(UInt64()) { $0 + $1.output.value }
//            let change: UInt64 = totalAmount - amount - fee
            
            let unsignedTx = SendUtility.leaveTransactionBuild(to: (seatPublicKeyData, utxo.output.value - fee), utxos: utxosToSpend)
            
            // outputを作り直す
            // let output = utxo.output
            let p2shOutput = TransactionOutput(value: utxo.output.value, lockingScript: redeemScript.data)
            
            // Sign transaction hash
            let sighash: Data = unsignedTx.tx.signatureHash(for: p2shOutput, inputIndex: 0, hashType: SighashType.BCH.ALL)
            let signature: Data = try Crypto.sign(sighash, privateKey: wallet.privateKey)
            let hashType = SighashType.BCH.ALL
            let sigWithHashType: Data = signature + UInt8(hashType)
            let rawtx = unsignedTx.tx.serialized().hex
            
            if let url = URL(string: "https://asia-northeast1-hackathon-217301.cloudfunctions.net/broadcast-transaction-endpoint") {
                var request = URLRequest(url: url)
                let body = "clientSig=\(sigWithHashType.hex)&clientRedeemScript=\(redeemScript.hex)&rawTx=\(rawtx)"
                let bodyData = Data(hex: body)
                request.httpBody = bodyData
                print(body)
                URLSession.shared.dataTask(with: request) { (data, response, error) in
                    print(data)
                    print(response)
                    print(error)
                }.resume()
            }
            
            print("rawtx: \(rawtx), signature: \(signature), redeemScript: \(redeemScript)")
        } catch {
            print(error)
        }
    }
    
    private func send() {
//        let addressString = "bchtest:qpytf7xczxf2mxa3gd6s30rthpts0tmtgyw8ud2sy3"
//        let addressString = "bchtest:qzdhquzataatnyrqnrnuhrhm26z8fxzn8gx7qwzqn5"
        let addressString = "bitcoincash:qqlljtdvfm6qtw0w8p7d20vp8pppan55xuhq8s4cq9"
//        guard let addressString = destinationAddressTextField.text else {
//            return
//        }

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
    
    private func sendToSeat(seatPublicKeyData: Data, amount: UInt64, transactionType: SendUtility.TransactionType) {
        do {
            try customSend(to: seatPublicKeyData, amount: amount, transactionType: transactionType) { [weak self] (response) in
                print("送金完了　txid : ", response ?? "")
                self?.reloadBalance()
            }
        } catch {
            print(error)
        }
    }
    
    func customSend(to seatPublicKeyData: Data, amount: UInt64, transactionType: SendUtility.TransactionType, completion: ((String?) -> Void)?) throws {
        guard let wallet = wallet else {
            return
        }
        let utxos = wallet.utxos()
        let (utxosToSpend, fee) = try StandardUtxoSelector().select(from: utxos, targetValue: amount)
        let totalAmount: UInt64 = utxosToSpend.reduce(UInt64()) { $0 + $1.output.value }
        let change: UInt64 = totalAmount - amount - fee * 2
        
        let (unsignedTx, redeemScript) = try SendUtility.customTransactionBuild(to: (wallet.address, amount), change: (wallet.address, change), keys: (wallet.publicKey.data, seatPublicKeyData), utxos: utxosToSpend)
        let signedTx = try SendUtility.customTransactionSign(unsignedTx, transactionType: transactionType, keys: [wallet.privateKey], pubKeyBData: seatPublicKeyData, redeemScript: redeemScript)
        
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
