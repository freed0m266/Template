//
//  ExampleView.swift
//  Example
//
//  Created by Martin Svoboda on 26.04.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI
import TemplateUI
import TemplateResources

public struct ExampleView<ViewModel: ExampleViewModeling>: View {
	@State private var viewModel: ViewModel

	typealias Texts = L10n.Example

	init(viewModel: ViewModel) {
		_viewModel = .init(wrappedValue: viewModel)
	}

	public var body: some View {
		Text(Texts.welcomeText)
	}
}

#if DEBUG
#Preview {
	ExampleView(viewModel: ExampleViewModelMock())
}
#endif
