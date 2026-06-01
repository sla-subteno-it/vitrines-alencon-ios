//
//  ContentView.swift
//  VitrinesiOS
//
//  Created by Sébastien LANGE on 31/05/2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var auth = AuthViewModel()

    var body: some View {
        Group {
            if auth.isInitializing {
                SplashView()
            } else if auth.isAuthenticated {
                MainTabView()
            } else {
                PublicHomeView()
            }
        }
        .environmentObject(auth)
        .animation(.default, value: auth.isAuthenticated)
        .animation(.default, value: auth.isInitializing)
        .task { await auth.bootstrap() }
    }
}

/// Écran de chargement affiché pendant la vérification de session au lancement.
private struct SplashView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image("VitrinesLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
            ProgressView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    ContentView()
}
