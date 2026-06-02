// AuthViewModel.swift
// Vitrines d'Alençon — iOS
// État d'authentification global de l'app (login Odoo → session cookie).

import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {

    // MARK: - État

    /// `true` une fois la session valide (login réussi ou cookie restauré).
    @Published var isAuthenticated = false

    /// `true` pendant la vérification de session au lancement (écran de chargement).
    @Published var isInitializing = true

    /// `true` pendant une tentative de connexion.
    @Published var isLoading = false

    /// Message d'erreur à afficher sous le formulaire.
    @Published var errorMessage: String?

    /// Saisie du formulaire de connexion.
    @Published var email = ""
    @Published var password = ""

    /// Nom de l'utilisateur connecté (pour l'onglet Mon Compte).
    @Published var userName: String?

    private let client = OdooClient.shared

    // MARK: - Lancement

    /// Restaure une éventuelle session persistante au démarrage.
    func bootstrap() async {
        isInitializing = true
        isAuthenticated = await client.restoreSession()
        if isAuthenticated {
            userName = await OdooSession.shared.getUserName()
            await PushManager.shared.registerWithBackend()
        }
        isInitializing = false
    }

    // MARK: - Connexion

    func login() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            errorMessage = "Saisissez votre identifiant et votre mot de passe."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            _ = try await client.authenticate(login: trimmedEmail, password: password)
            userName = await OdooSession.shared.getUserName()
            password = ""
            isAuthenticated = true
            PushManager.shared.requestPermission()
            await PushManager.shared.registerWithBackend()
        } catch {
            errorMessage = (error as? OdooError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Recharge l'état d'authentification depuis le cookie de session
    /// (à appeler après une inscription réussie qui a connecté l'utilisateur).
    func refreshSession() async {
        isAuthenticated = await client.restoreSession()
        if isAuthenticated {
            userName = await OdooSession.shared.getUserName()
            PushManager.shared.requestPermission()
            await PushManager.shared.registerWithBackend()
        }
    }

    // MARK: - Déconnexion

    func logout() async {
        await PushManager.shared.unregisterFromBackend()
        await client.logout()
        email = ""
        password = ""
        userName = nil
        errorMessage = nil
        isAuthenticated = false
    }
}
