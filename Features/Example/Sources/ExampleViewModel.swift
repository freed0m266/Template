//
//  ExampleViewModel.swift
//  Example
//
//  Created by Martin Svoboda on 26.04.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import Observation
import TemplateCore

@MainActor
public protocol ExampleViewModeling: Observable {
	func refreshData() async
}

@MainActor
public func exampleVM() -> some ExampleViewModeling {
	ExampleViewModel(dependencies: dependencies.example)
}

@Observable
final class ExampleViewModel: BaseViewModel, ExampleViewModeling {

	private let dependencies: ExampleDependencies

	// MARK: - Init

	init(dependencies: ExampleDependencies) {
		self.dependencies = dependencies
		super.init()
	}

	// MARK: - Public API

	func refreshData() async {

	}

	// MARK: - Private API

	private func setupBindings() {

	}
}
