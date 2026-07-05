//
//  ContentView.swift
//  Template
//
//  Created by Martin Svoboda on 26.04.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI
import Example

struct ContentView: View {
	var body: some View {
		ExampleView(viewModel: exampleVM())
	}
}

#Preview {
	ContentView()
}
