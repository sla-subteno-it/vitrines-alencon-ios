// PushManager.swift
// Vitrines d'Alençon — iOS
// Notifications push via OneSignal (même projet que le PWA).
//
// ⚠️ Le SDK OneSignal doit être ajouté via Swift Package Manager :
//    https://github.com/OneSignal/OneSignal-iOS-SDK  (produit « OneSignalFramework »)
// Tant que le package n'est pas ajouté, `canImport(OneSignalFramework)` est faux
// et des stubs no-op permettent au projet de compiler.

import Foundation

enum PushConfig {
    /// App ID OneSignal (identique au PWA, exposé par /onesignal/config).
    static let oneSignalAppID = "e79881b6-f5eb-462c-b971-11a59d7bdd83"
}

#if canImport(OneSignalFramework)
import OneSignalFramework

@MainActor
final class PushManager {
    static let shared = PushManager()
    private init() {}

    private var initialized = false

    /// Initialise le SDK OneSignal. À appeler au lancement de l'app.
    func start() {
        guard !initialized else { return }
        initialized = true
        OneSignal.initialize(PushConfig.oneSignalAppID, withLaunchOptions: nil)
        OneSignal.User.pushSubscription.addObserver(self)
    }

    /// Demande l'autorisation d'envoyer des notifications (renvoie vers les
    /// Réglages si déjà refusée).
    func requestPermission() {
        OneSignal.Notifications.requestPermission({ _ in }, fallbackToSettings: true)
    }

    /// Enregistre l'abonnement courant auprès d'Odoo (lié au partenaire connecté).
    func registerWithBackend() async {
        guard let id = OneSignal.User.pushSubscription.id, !id.isEmpty else { return }
        await OdooClient.shared.registerPushPlayer(playerId: id)
    }

    /// Désactive l'abonnement côté Odoo (à la déconnexion).
    func unregisterFromBackend() async {
        guard let id = OneSignal.User.pushSubscription.id, !id.isEmpty else { return }
        await OdooClient.shared.unregisterPushPlayer(playerId: id)
    }
}

extension PushManager: OSPushSubscriptionObserver {
    nonisolated func onPushSubscriptionDidChange(state: OSPushSubscriptionChangedState) {
        // L'ID d'abonnement peut arriver de façon asynchrone : (ré)enregistrer.
        Task { @MainActor in await PushManager.shared.registerWithBackend() }
    }
}

#else

// SDK OneSignal absent : stubs no-op (le projet compile, push inactif).
@MainActor
final class PushManager {
    static let shared = PushManager()
    private init() {}

    func start() {
        #if DEBUG
        print("[Push] SDK OneSignal absent — ajouter le package SPM OneSignal-iOS-SDK pour activer les notifications.")
        #endif
    }
    func requestPermission() {}
    func registerWithBackend() async {}
    func unregisterFromBackend() async {}
}

#endif
