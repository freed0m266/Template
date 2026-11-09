//
//  View+Extensions.swift
//  TemplateUI
//
//  Created by Martin Svoboda on 26.04.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI
import TemplateCore

public extension View {
	func maxWidthLeading() -> some View {
		frame(maxWidth: .infinity, alignment: .leading)
	}

	/// iOS 27 turned the automatic top scroll edge effect into `.hard`, a flat opaque bar.
	/// Apply it to every `NavigationStack`, a presented one included.
	func softTopScrollEdge() -> some View {
		scrollEdgeEffectStyle(.soft, for: .top)
	}
}

public extension View {
	func hideKeyboardOnTap() -> some View {
		onTapGesture {
			UIApplication.resignFirstResponder()
		}
	}

	func openSystemSettings() {
		UIApplication.openSystemSettings()
	}
}
