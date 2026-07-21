//
//  __FEATURE__View.swift
//  __FEATURE__
//
//  Created by Martin Svoboda on __CREATED_DATE__.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI
import TemplateUI

public struct __FEATURE__View<ViewModel: __FEATURE__ViewModeling>: View {
	@State private var viewModel: ViewModel

	public init(viewModel: ViewModel) {
		_viewModel = .init(wrappedValue: viewModel)
	}

	public var body: some View {
		Text("__FEATURE__")
	}
}

#if DEBUG
#Preview {
	__FEATURE__View(viewModel: __FEATURE__ViewModelMock()).inPreview()
}
#endif
