//
//  InPreview.swift
//  Template
//
//  Created by Martin Svoboda on 21.07.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

#if DEBUG
import SwiftUI

struct InPreviewModifier: ViewModifier {
	let colorScheme: ColorScheme

	func body(content: Content) -> some View {
		NavigationStack {
			content
		}
		.softTopScrollEdge()
		.preferredColorScheme(colorScheme)
	}
}

/// Use it only for #Preview and snapshot testing.
public extension View {
	@ViewBuilder
	func inPreview(isSheet: Bool = false, colorScheme: ColorScheme = .dark) -> some View {
		if isSheet {
			Rectangle()
				.fill(.clear)
				.sheet(isPresented: .constant(true)) {
					NavigationStack {
						self
							.preferredColorScheme(colorScheme)
							.interactiveDismissDisabled()
					}
					.softTopScrollEdge()
				}
		} else {
			modifier(InPreviewModifier(colorScheme: colorScheme))
		}
	}
}
#endif
