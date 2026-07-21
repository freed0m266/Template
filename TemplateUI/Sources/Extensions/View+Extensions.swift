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
