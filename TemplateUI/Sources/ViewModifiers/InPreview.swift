//
//  InPreview.swift
//  Template
//
//  Created by Martin Svoboda on 21.07.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI

struct InPreviewModifier: ViewModifier {
	func body(content: Content) -> some View {
		NavigationStack {
			content
		}
	}
}

/// Use it only for #Preview and snapshot testing.
public extension View {
	func inPreview() -> some View {
		modifier(InPreviewModifier())
	}
}
