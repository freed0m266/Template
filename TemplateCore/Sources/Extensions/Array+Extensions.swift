//
//  Array+Extensions.swift
//  Template
//
//  Created by Martin Svoboda on 21.07.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import Foundation

public extension Array {
	func minBy<T: Comparable>(_ keyPath: KeyPath<Element, T>) -> Element? {
		self.min { $0[keyPath: keyPath] < $1[keyPath: keyPath] }
	}

	func maxBy<T: Comparable>(_ keyPath: KeyPath<Element, T>) -> Element? {
		self.max { $0[keyPath: keyPath] < $1[keyPath: keyPath] }
	}

	func sortedBy<T: Comparable>(_ keyPath: KeyPath<Element, T>, descending: Bool = false) -> Array {
		if descending {
			sorted { $0[keyPath: keyPath] > $1[keyPath: keyPath] }
		} else {
			sorted { $0[keyPath: keyPath] < $1[keyPath: keyPath] }
		}
	}

	func sortedByOptional<T: Comparable>(_ keyPath: KeyPath<Element, T?>, nilsFirst: Bool = false) -> Array {
		sorted {
			let lhs = $0[keyPath: keyPath]
			let rhs = $1[keyPath: keyPath]

			switch (lhs, rhs) {
			case (nil, nil):
				return false
			case (nil, _):
				return nilsFirst
			case (_, nil):
				return !nilsFirst
			case let (a?, b?):
				return a < b
			}
		}
	}
}
