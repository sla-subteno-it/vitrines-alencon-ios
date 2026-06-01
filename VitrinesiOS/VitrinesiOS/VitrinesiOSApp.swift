//
//  VitrinesiOSApp.swift
//  VitrinesiOS
//
//  Created by Sébastien LANGE on 31/05/2026.
//

import SwiftUI

@main
struct VitrinesiOSApp: App {
    init() {
        BrandFont.registerEmbeddedFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
