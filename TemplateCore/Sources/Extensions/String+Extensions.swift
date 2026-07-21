//
//  String+Extensions.swift
//  Template
//
//  Created by Martin Svoboda on 21.07.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import UIKit

public extension String {
	func copyToClipboard() {
		UIPasteboard.general.string = self
	}
}
