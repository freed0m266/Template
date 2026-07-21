//
//  CGFloat+Extensions.swift
//  Template
//
//  Created by Martin Svoboda on 21.07.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import Foundation

public extension CGFloat {
	static func / (lhs: CGFloat, rhs: Int) -> CGFloat { lhs / CGFloat(rhs) }
	static func / (lhs: Int, rhs: CGFloat) -> CGFloat { CGFloat(lhs) / rhs }

	static func * (lhs: CGFloat, rhs: Int) -> CGFloat { lhs * CGFloat(rhs) }
	static func * (lhs: Int, rhs: CGFloat) -> CGFloat { CGFloat(lhs) * rhs }

	static func + (lhs: CGFloat, rhs: Int) -> CGFloat { lhs + CGFloat(rhs) }
	static func + (lhs: Int, rhs: CGFloat) -> CGFloat { CGFloat(lhs) + rhs }

	static func - (lhs: CGFloat, rhs: Int) -> CGFloat { lhs - CGFloat(rhs) }
	static func - (lhs: Int, rhs: CGFloat) -> CGFloat { CGFloat(lhs) - rhs }
}

public extension [CGFloat] {
	func average() -> CGFloat? {
		guard count > 0 else { return nil }
		return reduce(0, +) / CGFloat(count)
	}
}

extension CGFloat {
	public func formatted(maxPrecision: Int? = nil) -> String {
		let formatter: NumberFormatter

		if let maxPrecision {
			let copy = Self.decimalFormatter.copy() as? NumberFormatter
			copy?.maximumFractionDigits = maxPrecision
			formatter = copy ?? CGFloat.decimalFormatter
		} else {
			formatter = CGFloat.decimalFormatter
		}

		return formatter.string(from: self) ?? String(describing: self)
	}

	private static let decimalFormatter = {
		let formatter = NumberFormatter()
		formatter.locale = .autoupdatingCurrent
		formatter.numberStyle = .decimal
		return formatter
	}()
}
