//
//  Image+Extensions.swift
//  Template
//
//  Created by Martin Svoboda on 21.07.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI

public extension Image {
	func size(_ size: CGFloat) -> some View {
		resizable()
			.frame(width: size, height: size)
	}
}
