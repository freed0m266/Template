//
//  __FEATURE__ViewModel.swift
//  __FEATURE__
//
//  Created by Martin Svoboda on __CREATED_DATE__.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import Observation
import TemplateCore

@MainActor
public protocol __FEATURE__ViewModeling: Observable, AnyObject {
}

@MainActor
public func __feature__VM() -> some __FEATURE__ViewModeling {
	__FEATURE__ViewModel(dependencies: dependencies.__feature__)
}

@MainActor
@Observable
final class __FEATURE__ViewModel: BaseViewModel, __FEATURE__ViewModeling {

	private let dependencies: __FEATURE__Dependencies

	// MARK: - Init

	init(dependencies: __FEATURE__Dependencies) {
		self.dependencies = dependencies
		super.init()
	}
}
