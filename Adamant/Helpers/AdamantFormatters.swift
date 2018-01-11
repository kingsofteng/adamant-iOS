//
//  AdamantFormatters.swift
//  Adamant-ios
//
//  Created by Anokhov Pavel on 08.01.2018.
//  Copyright © 2018 Adamant. All rights reserved.
//

import Foundation

class AdamantFormatters {
	private init() { }
}


// MARK: - Currency
extension AdamantFormatters {
	static let currencyShift: Double = 0.00_000_001
	static let currencyCode = "ADM"
	
	static func format(balance: Int64) -> String {
		return "\(Double(balance) * currencyShift) \(currencyCode)"
	}
	
	static func from(double: Double) -> UInt {
		return UInt(double / currencyShift)
	}
	
	static func from(int: UInt) -> Double{
		return Double(int) * currencyShift
	}
}


// MARK: - Address
extension AdamantFormatters {
	static let addressRegex = "^U([0-9]{6,})$"
	
	static func validateAdamantAddress(address: String) -> Bool {
		if let regex = try? NSRegularExpression(pattern: addressRegex, options: []) {
			let matches = regex.matches(in: address, options: [], range: NSRange(location: 0, length: address.count))
			
			return matches.count == 1
		} else {
			print("Wrong address regex: \(addressRegex)")
			return false
		}
	}
}



// MARK: - Dates
extension AdamantFormatters {
	static func decodeAdamantDate(timestamp: TimeInterval) -> Date {
		return Date(timeIntervalSince1970: timestamp + magicAdamantTimeInterval)
	}
	
	private static var magicAdamantTimeInterval: TimeInterval = {
		// JS handles moth as 0-based number, swift handles month as 1-based number.
		let components = DateComponents(calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(abbreviation: "UTC"), year: 2017, month: 9, day: 2, hour: 17)
		return components.date!.timeIntervalSince1970
	}()
}