// AuthViewModel.swift
// Vitrines d'Alençon — iOS
// État d'authentification global de l'app (login Odoo → session cookie).

import Foundation
import Combine

/// Mémorise l'état « connecté » entre les lancements pour permettre l'usage
/// hors-ligne (afficher la carte fidélité en cache même sans réseau).
enum AuthStore {
    private static let d = UserDefaults.standard
    private static let kLoggedIn = "auth_logged_in"
    private static let kUserName = "auth_user_name"

    static var isLoggedIn: Bool {
        get { d.bool(forKey: kLoggedIn) }
        set { d.set(newValue, forKey: kLoggedIn) }
    }
    static var userName: String? {
        get { d.string(forKey: kUserName) }
        set {
            if let v = newValue, !v.isEmpty { d.set(v, forKey: kUserName) }
            else { d.removeObject(forKey: kUserName) }
        }
    }
    static func clear() {
        d.removeObject(forKey: kLoggedIn)
        d.removeObject(forKey: kUserName)
    }
}

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

    // MARK: - Mot de passe oublié (réinitialisation in-app)
    @Published var showResetSheet = false
    @Published var resetEmail = ""
    @Published var resetLoading = false
    @Published var resetError: String?
    @Published var resetDone = false

    private let client = OdooClient.shared

    // MARK: - Lancement

    /// Restaure une éventuelle session persistante au démarrage.
    func bootstrap() async {
        isInitializing = true
        switch await client.restoreSession() {
        case .authenticated:
            isAuthenticated = true
            userName = await OdooSession.shared.getUserName() ?? AuthStore.userName
            AuthStore.isLoggedIn = true
            AuthStore.userName = userName
            await PushManager.shared.registerWithBackend()
        case .offline:
            // Pas de réseau : si l'utilisateur était connecté, on le garde
            // connecté en mode hors-ligne (la carte fidélité en cache reste accessible).
            isAuthenticated = AuthStore.isLoggedIn
            if isAuthenticated { userName = AuthStore.userName }
        case .expired:
            isAuthenticated = false
            AuthStore.clear()
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
            AuthStore.isLoggedIn = true
            AuthStore.userName = userName
            PushManager.shared.requestPermission()
            await PushManager.shared.registerWithBackend()
        } catch {
            errorMessage = (error as? OdooError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Mot de passe oublié

    /// Ouvre la feuille « mot de passe oublié » (pré-remplie avec l'identifiant saisi).
    func openResetSheet() {
        resetEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        resetError = nil
        resetDone = false
        showResetSheet = true
    }

    /// Déclenche l'envoi de l'email de réinitialisation par Odoo.
    func requestPasswordReset() async {
        let login = resetEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !login.isEmpty else {
            resetError = "Saisissez votre identifiant (e-mail)."
            return
        }
        resetLoading = true
        resetError = nil
        defer { resetLoading = false }
        do {
            try await client.requestPasswordReset(login: login)
            resetDone = true
        } catch {
            resetError = (error as? OdooError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Recharge l'état d'authentification depuis le cookie de session
    /// (à appeler après une inscription réussie qui a connecté l'utilisateur).
    func refreshSession() async {
        if case .authenticated = await client.restoreSession() {
            isAuthenticated = true
            userName = await OdooSession.shared.getUserName()
            AuthStore.isLoggedIn = true
            AuthStore.userName = userName
            PushManager.shared.requestPermission()
            await PushManager.shared.registerWithBackend()
        }
    }

    // MARK: - Déconnexion

    func logout() async {
        await PushManager.shared.unregisterFromBackend()
        LoyaltyCardStore.clear()
        AuthStore.clear()
        await client.logout()
        email = ""
        password = ""
        userName = nil
        errorMessage = nil
        isAuthenticated = false
    }
}
