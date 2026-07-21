//
//  UIApplication+Extensions.swift
//  Template
//
//  Created by Martin Svoboda on 21.07.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import UIKit

public extension UIApplication {
	static func resignFirstResponder() {
		UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
	}

	static func openSystemSettings() {
		if let settingsURL = URL(string: openSettingsURLString) {
			shared.open(settingsURL)
		}
	}
}
