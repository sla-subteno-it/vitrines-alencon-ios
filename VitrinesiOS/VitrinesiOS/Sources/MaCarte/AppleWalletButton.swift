// AppleWalletButton.swift
// Vitrines d'Alençon — iOS
// Bouton « Ajouter à Apple Wallet » : télécharge le .pkpass généré par Odoo
// (module vda_wallet, endpoint /my/wallet/loyalty.pkpass) et l'ajoute à Wallet.

import SwiftUI
import PassKit
import Combine

enum WalletConfig {
    /// Passer à `true` une fois le module Odoo `vda_wallet` configuré
    /// (certificats Apple Pass Type ID en place). Tant que c'est `false`,
    /// le bouton n'est pas affiché.
    static let enabled = false
}

@MainActor
final class WalletLoader: ObservableObject {
    @Published var pass: PKPass?
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let data = try await OdooClient.shared.get(path: "/my/wallet/loyalty.pkpass")
            pass = try PKPass(data: data)
        } catch {
            pass = nil
            errorMessage = "Apple Wallet n'est pas disponible pour le moment."
        }
    }
}

struct AddToWalletButton: View {
    @StateObject private var loader = WalletLoader()
    @State private var showAdd = false
    @State private var showError = false

    var body: some View {
        if WalletConfig.enabled && PKAddPassesViewController.canAddPasses() {
            PassButton {
                Task {
                    await loader.load()
                    if loader.pass != nil { showAdd = true }
                    else { showError = true }
                }
            }
            .frame(height: 48)
            .frame(maxWidth: .infinity)
            .sheet(isPresented: $showAdd) {
                if let pass = loader.pass { AddPassesSheet(pass: pass) }
            }
            .alert("Apple Wallet", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(loader.errorMessage ?? "Indisponible pour le moment.")
            }
        }
    }
}

// MARK: - Wrappers UIKit

private struct PassButton: UIViewRepresentable {
    let action: () -> Void

    func makeUIView(context: Context) -> PKAddPassButton {
        let button = PKAddPassButton(addPassButtonStyle: .black)
        button.addTarget(context.coordinator, action: #selector(Coordinator.tap), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: PKAddPassButton, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    final class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func tap() { action() }
    }
}

private struct AddPassesSheet: UIViewControllerRepresentable {
    let pass: PKPass

    func makeUIViewController(context: Context) -> UIViewController {
        PKAddPassesViewController(pass: pass) ?? UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
