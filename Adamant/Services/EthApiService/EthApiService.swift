//
//  EthApiService.swift
//  Adamant
//
//  Created by Anton Boyarkin on 16/06/2018.
//  Copyright © 2018 Adamant. All rights reserved.
//

import Foundation
import web3swift
import BigInt

// MARK: - Notifications
extension Notification.Name {
    struct EthApiService {
        /// Raised when user has logged out.
        static let userLoggedOut = Notification.Name("adamant.ethApiService.userHasLoggedOut")
        
        /// Raised when user has successfully logged in.
        static let userLoggedIn = Notification.Name("adamant.ethApiService.userHasLoggedIn")
        
        private init() {}
    }
}

struct EthAccount {
    let wallet: BIP32Keystore
    let address: String?
    var balance: BigUInt?
    var balanceString: String?
}

class EthApiService: EthApiServiceProtocol {
    
    // MARK: - Constans
    static let transferGas = 21000
    static let kvsAddress = "eth:address"
    static let defaultGasPrice = 20000000000 // 20 Gwei
    
    // MARK: - Dependencies
    var apiService: ApiService!
    var accountService: AccountService!
    
    // MARK: - Properties
    var apiUrl: String
    var web3: web3!
    
    private(set) var account: EthAccount?
    
    // MARK: - Initialization
    
    init(apiUrl: String) {
        self.apiUrl = apiUrl
        
        // test network
        self.apiUrl = "https://ropsten.infura.io/"
        
        if let url = URL(string: self.apiUrl), let web3 = Web3.new(url) {
            self.web3 = web3
        } else {
            print("Unable init Web3")
            return
        }
        
        let gasPriceResult = self.web3.eth.getGasPrice()
        guard case .success(let gasPrice) = gasPriceResult else { return }
        
        print("ETH Server gas Price: \(gasPrice)")
        
        if let network = self.web3.provider.network { print("ETH Server network: \(network)") }
    }
    
    func newAccount(byPassphrase passphrase: String, completion: @escaping (ApiServiceResult<EthAccount>) -> Void) {
        DispatchQueue.global().async {
            guard let keystore = try? BIP32Keystore(mnemonics: passphrase,
                                                    password: "",
                                                    mnemonicsPassword: "",
                                                    language: .english),
                let wallet = keystore else {
                    DispatchQueue.main.async {
                        completion(.failure(.internalError(message: "ETH Wallet: fail to create Keystore", error: nil)))
                    }
                    return
            }
            
            self.account = EthAccount(wallet: wallet, address: wallet.addresses?.first?.address, balance: nil, balanceString: nil)
            if let account = self.account {
                NotificationCenter.default.post(name: Notification.Name.EthApiService.userLoggedIn, object: self)
                DispatchQueue.main.async {
                    completion(.success(account))
                }
                
                if let address = self.accountService.account?.address, let keypair = self.accountService.keypair {
                    self.getEthAddress(byAdamandAddress: address) { (result) in
                        switch result {
                        case .success(let value):
                            if value == nil {
                                guard let loggedAccount = self.accountService.account else {
                                    DispatchQueue.main.async {
                                        completion(.failure(.notLogged))
                                    }
                                    return
                                }
                                
                                guard loggedAccount.balance >= AdamantApiService.KVSfee else {
                                    DispatchQueue.main.async {
                                        completion(.failure(.internalError(message: "ETH Wallet: Not enought ADM to save address to KVS", error: nil)))
                                    }
                                    return
                                }
                                
                                self.apiService.store(key: EthApiService.kvsAddress, value: account.address!, type: StateType.keyValue, sender: address, keypair: keypair, completion: { (result) in
                                    switch result {
                                    case .success(let transactionId):
                                        print("SAVED: \(transactionId)")
                                        break
                                    case .failure(let error):
                                        DispatchQueue.main.async {
                                            completion(.failure(.internalError(message: "ETH Wallet: fail to save address to KVS", error: error)))
                                        }
                                        break
                                    }
                                })
                            } else {
                                print("FOUND: \(value!)")
                            }
                            break
                        case .failure(let error):
                            DispatchQueue.main.async {
                                completion(.failure(.internalError(message: "ETH Wallet: fail to get address from KVS", error: error)))
                            }
                            break
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(.internalError(message: "ETH Wallet: fail to create Account", error: nil)))
                }
            }
        }
    }
    
    func sendFunds(toAddress address: String, amount: Double, completion: @escaping (ApiServiceResult<String>) -> Void) {
        DispatchQueue.global().async {
            guard let destinationEthAddress = EthereumAddress(address) else {
                DispatchQueue.main.async {
                    completion(.failure(.internalError(message: "ETH Wallet: Send - invalid destination address", error: nil)))
                }
                return
            }
            guard let amount = Web3.Utils.parseToBigUInt("\(amount)", units: .eth) else {
                DispatchQueue.main.async {
                    completion(.failure(.internalError(message: "ETH Wallet: Send - invalid amount format", error: nil)))
                }
                return
            }
            
            guard let ethAddressFrom = self.account?.wallet.addresses?.first else {
                DispatchQueue.main.async {
                    completion(.failure(.internalError(message: "ETH Wallet: Send - no address found", error: nil)))
                }
                return
            }
            
            guard let keystore = self.account?.wallet else {
                DispatchQueue.main.async {
                    completion(.failure(.internalError(message: "ETH Wallet: Send - no keystore found", error: nil)))
                }
                return
            }
            
            self.web3.addKeystoreManager(KeystoreManager([keystore]))
            var options = Web3Options.defaultOptions()
//            options.gasLimit = BigUInt(gasLimit)
            options.from = ethAddressFrom
            options.value = BigUInt(amount)
            guard let contract = self.web3.contract(Web3.Utils.coldWalletABI, at: destinationEthAddress) else {
                DispatchQueue.main.async {
                    completion(.failure(.internalError(message: "ETH Wallet: Send - contract loading error", error: nil)))
                }
                return
            }
            
            guard let estimatedGas = contract.method(options: options)?.estimateGas(options: nil).value else {
                DispatchQueue.main.async {
                    completion(.failure(.internalError(message: "ETH Wallet: Send - retrieving estimated gas error", error: nil)))
                }
                return
            }
            options.gasLimit = estimatedGas
            guard let gasPrice = self.web3.eth.getGasPrice().value else {
                DispatchQueue.main.async {
                    completion(.failure(.internalError(message: "ETH Wallet: Send - retrieving gas price error", error: nil)))
                }
                return
            }
            options.gasPrice = gasPrice
            guard let transaction = contract.method(options: options) else {
                DispatchQueue.main.async {
                    completion(.failure(.internalError(message: "ETH Wallet: Send - create transaction issue", error: nil)))
                }
                return
            }
            
            guard let sendResult = transaction.send(password: "", options: nil).value else {
                DispatchQueue.main.async {
                    completion(.failure(.internalError(message: "ETH Wallet: Send - sending transaction error", error: nil)))
                }
                return
            }
            
            guard let hash = sendResult["txhash"] else {
                DispatchQueue.main.async {
                    completion(.failure(.internalError(message: "ETH Wallet: Send - fail to get transaction hash", error: nil)))
                }
                return
            }
            guard let formattedAmount = Web3.Utils.formatToEthereumUnits(amount, toUnits: .wei) else {
                DispatchQueue.main.async {
                    completion(.failure(.internalError(message: "ETH Wallet: Send - fail to get transaction amount", error: nil)))
                }
                return
            }
            
            let result = ["type": "eth_transaction", "amount": formattedAmount, "hash": hash, "comments":""]
            
            do {
                let data = try JSONEncoder().encode(result)
                guard let raw = String(data: data, encoding: String.Encoding.utf8) else {
                    return
                }
                
                DispatchQueue.main.async {
                    completion(.success(raw))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.internalError(message: "ETH Wallet: Send - wrong data issue", error: nil)))
                }
            }
        }
    }
    
    func getBalance(_ completion: @escaping (ApiServiceResult<String>) -> Void) {
        if let walletAddress = self.account?.wallet.addresses?.first {
            self.getBalance(byAddress: walletAddress) { (result) in
                switch result {
                case .success(let balance):
                    self.account?.balance = balance
                    
                    if let formattedAmount = Web3.Utils.formatToEthereumUnits(balance,
                                                                              toUnits: .eth,
                                                                              decimals: 8,
                                                                              fallbackToScientific: true), let amount = Double(formattedAmount) {
                        completion(.success("\(amount) ETH"))
                    } else {
                        completion(.failure(.internalError(message: "ETH Wallet: fail to get balance amount", error: nil)))
                    }
                    break
                case .failure(let error):
                    completion(.failure(.internalError(message: "ETH Wallet: Can't load balance", error: error)))
                }
            }
        } else {
            completion(.failure(.internalError(message: "ETH Wallet: not found", error: nil)))
        }
    }
    
    func getBalance(byAddress address: String, completion: @escaping (ApiServiceResult<String>) -> Void) {
        if let walletAddress = EthereumAddress(address) {
            self.getBalance(byAddress: walletAddress) { (result) in
                switch result {
                case .success(let balance):
                    if let formattedAmount = Web3.Utils.formatToEthereumUnits(balance,
                                                                              toUnits: .eth,
                                                                              decimals: 8,
                                                                              fallbackToScientific: true), let amount = Double(formattedAmount)  {
                        completion(.success("\(amount) ETH"))
                    } else {
                        completion(.failure(.internalError(message: "ETH Wallet: fail to get balance amount", error: nil)))
                    }
                    break
                case .failure(let error):
                    completion(.failure(.internalError(message: "ETH Wallet: Can't load balance", error: error)))
                }
            }
        } else {
            completion(.failure(.internalError(message: "ETH Wallet: not found", error: nil)))
        }
    }
    
    func getEthAddress(byAdamandAddress address: String, completion: @escaping (ApiServiceResult<String?>) -> Void) {
        apiService.get(key: EthApiService.kvsAddress, sender: address) { (result) in
            switch result {
            case .success(let value):
                if let value = value {
                    completion(.success(value))
                } else {
                    completion(.success(nil))
                }
                break
            case .failure(let error):
                completion(.failure(.internalError(message: "ETH Wallet: fail to get address from KVS", error: error)))
                break
            }
        }
    }
    
    // MARK: - Private
    func getBalance(byAddress address: EthereumAddress, completion: @escaping (ApiServiceResult<BigUInt>) -> Void) {
        DispatchQueue.global().async {
            let balanceResult = self.web3.eth.getBalance(address: address)
            guard case .success(let balance) = balanceResult else {
                DispatchQueue.main.async {
                    completion(.failure(.internalError(message: "ETH Wallet: fail to get balance", error: nil)))
                }
                return
            }
            
            DispatchQueue.main.async {
                completion(.success(balance))
            }
        }
    }
}