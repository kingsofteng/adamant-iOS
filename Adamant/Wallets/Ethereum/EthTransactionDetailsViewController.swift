//
//  EthTransactionDetailsViewController.swift
//  Adamant
//
//  Created by Anokhov Pavel on 05.10.2018.
//  Copyright © 2018 Adamant. All rights reserved.
//

import UIKit

class EthTransactionDetailsViewController: TransactionDetailsViewControllerBase {
    // MARK: - Overrides
    
    override func viewDidLoad() {
        currencySymbol = EthWalletService.currencySymbol
        
        super.viewDidLoad()
    }
    
    override func explorerUrl(for transaction: TransactionDetails) -> URL? {
        return URL(string: "\(AdamantResources.ethereumExplorerAddress)\(transaction.id)")
    }
}