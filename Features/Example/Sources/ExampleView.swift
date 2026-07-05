//
//  ExampleView.swift
//  Example
//
//  Created by Martin Svoboda on 26.04.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import BaseKitX
import SwiftUI
import TemplateResources

public struct ExampleView<ViewModel: ExampleViewModeling>: View {
	@State private var viewModel: ViewModel

	typealias Texts = L10n.Example

	public init(viewModel: ViewModel) {
		_viewModel = .init(wrappedValue: viewModel)
	}

	public var body: some View {
		VStack(spacing: 0) {
			exampleText
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(exampleBackground)
		.task {
			await viewModel.refreshData()
		}
	}

	private var exampleText: some View {
		Text(Texts.welcomeText)
			.font(.title2.weight(.semibold))
			.foregroundStyle(.white)
	}

	private var exampleBackground: some View {
		RadialGradient(
			colors: [
				Color(hexString: "285C23").opacity(0.65),
				Color(hexString: "285C23").opacity(0.18),
				.black.opacity(0.0)
			],
			center: .topLeading,
			startRadius: 40,
			endRadius: 500
		)
		.ignoresSafeArea()
	}
}

#if DEBUG
#Preview {
	ExampleView(viewModel: ExampleViewModelMock())
}
#endif
