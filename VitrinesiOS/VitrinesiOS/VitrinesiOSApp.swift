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
        PushManager.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // L'app conserve la charte Vitrines (claire) quel que soit le
                // réglage système — pas de mode sombre pour l'instant.
                .preferredColorScheme(.light)
        }
    }
}
