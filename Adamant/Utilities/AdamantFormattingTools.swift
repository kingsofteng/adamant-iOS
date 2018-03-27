//
//  AdamantFormattingTools.swift
//  Adamant
//
//  Created by Anokhov Pavel on 04.02.2018.
//  Copyright © 2018 Adamant. All rights reserved.
//

import UIKit

extension String.adamantLocalized.chat {
	static let sended = NSLocalizedString("ChatScene.Sended", comment: "Chat: 'Sended funds' bubble title")
	static let tapForDetails = NSLocalizedString("ChatScene.tapForDetails", comment: "Chat: 'Sended funds' buble 'Tap for details' tip")
}

class AdamantFormattingTools {
	static func summaryFor(transaction: BaseTransaction, url: URL) -> String {
		return summaryFor(id: transaction.blockId!, sender: transaction.senderId!, recipient: transaction.recipientId!, date: transaction.date as Date!, amount: transaction.amount as Decimal!, fee: transaction.fee as Decimal!, confirmations: transaction.confirmations, blockId: transaction.blockId!, url: url)
	}
	
	static func summaryFor(transaction: Transaction, url: URL) -> String {
		return summaryFor(id: String(transaction.id), sender: transaction.senderId, recipient: transaction.recipientId, date: transaction.date, amount: transaction.amount, fee: transaction.fee, confirmations: transaction.confirmations, blockId: transaction.blockId, url: url)
	}
	
	private static func summaryFor(id: String, sender: String, recipient: String, date: Date, amount: Decimal, fee: Decimal, confirmations: Int64, blockId: String, url: URL) -> String {
		
		return """
Transaction #\(id)

Summary
Sender: \(sender)
Recipient: \(recipient)
Date: \(DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .medium))
Amount: \(AdamantUtilities.format(balance: amount))
Fee: \(AdamantUtilities.format(balance: fee))
Confirmations: \(String(confirmations))
Block: \(blockId)
URL: \(url)
"""
	}
	
	static func formatTransferTransaction(_ transfer: TransferTransaction) -> NSAttributedString {
		let balance: String
		if let raw = transfer.amount {
			balance = AdamantUtilities.format(balance: raw)
		} else {
			balance = AdamantUtilities.format(balance: Decimal(0.0))
		}
		
		let sended = String.adamantLocalized.chat.sended
		
		let attributedString = NSMutableAttributedString(string: "\(sended)\n\(balance)\n\n\(String.adamantLocalized.chat.tapForDetails)")
		
		let rangeReference = attributedString.string as NSString
		let sendedRange = rangeReference.range(of: sended)
		let amountRange = rangeReference.range(of: balance)
		
		attributedString.setAttributes([.font: UIFont.adamantPrimary(size: 14)], range: sendedRange)
		attributedString.setAttributes([.font: UIFont.adamantPrimary(size: 28)], range: amountRange)
		
		return attributedString
	}
	
	private init() {}
}