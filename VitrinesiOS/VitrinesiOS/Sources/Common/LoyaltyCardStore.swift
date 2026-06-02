// LoyaltyCardStore.swift
// Vitrines d'Alençon — iOS
// Cache local de la carte de fidélité (numéro, titulaire, solde) pour afficher
// la carte + le code-barres instantanément et HORS-LIGNE (cas d'usage caisse).

import Foundation

enum LoyaltyCardStore {
    private static let defaults = UserDefaults.standard
    private static let kCard = "loyalty_cardnumber"
    private static let kName = "loyalty_holder_name"
    private static let kBalance = "loyalty_balance"
    private static let kHasBalance = "loyalty_has_balance"

    static var cardnumber: String? {
        get { defaults.string(forKey: kCard) }
        set {
            if let v = newValue, !v.isEmpty { defaults.set(v, forKey: kCard) }
            else { defaults.removeObject(forKey: kCard) }
        }
    }

    static var holderName: String? {
        get { defaults.string(forKey: kName) }
        set {
            if let v = newValue, !v.isEmpty { defaults.set(v, forKey: kName) }
            else { defaults.removeObject(forKey: kName) }
        }
    }

    static var balance: Double? {
        get { defaults.bool(forKey: kHasBalance) ? defaults.double(forKey: kBalance) : nil }
        set {
            if let v = newValue {
                defaults.set(v, forKey: kBalance)
                defaults.set(true, forKey: kHasBalance)
            } else {
                defaults.removeObject(forKey: kBalance)
                defaults.removeObject(forKey: kHasBalance)
            }
        }
    }

    /// Vide le cache (déconnexion, changement d'environnement).
    static func clear() {
        [kCard, kName, kBalance, kHasBalance].forEach { defaults.removeObject(forKey: $0) }
    }
}
