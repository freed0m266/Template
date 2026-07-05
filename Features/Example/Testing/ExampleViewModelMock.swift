//
//  ExampleViewModelMock.swift
//  Example
//
//  Created by Martin Svoboda on 26.04.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import Foundation

@Observable
@MainActor
final class ExampleViewModelMock: ExampleViewModeling {
	func refreshData() async { }
}
