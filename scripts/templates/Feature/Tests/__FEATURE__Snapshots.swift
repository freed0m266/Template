//
//  __FEATURE__Snapshots.swift
//  __FEATURE___Tests
//
//  Created by Martin Svoboda on __CREATED_DATE__.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import TemplateTesting
import XCTest
@testable import __FEATURE__

@MainActor
final class __FEATURE__Snapshots: XCTestCase {
	func testPreviews() {
		AssertSnapshot(__FEATURE__View(viewModel: __FEATURE__ViewModelMock()))
	}
}
