// CarteCadeauModels.swift
// Vitrines d'Alençon — iOS
// Modèles pour la carte cadeau (local.rewards.gift.card) et l'endpoint /scanner-carte-cadeau/scan.

import Foundation

// MARK: - Carte cadeau (ligne de liste "Mes cartes cadeaux")

/// Décodage d'un enregistrement `local.rewards.gift.card` (search_read).
/// Odoo renvoie `false` pour les champs vides → décodage défensif.
struct GiftCard: Identifiable, Decodable, Hashable {
    let id: Int
    let cardnumber: String
    let credit: Double
    let initialAmount: Double?
    let status: String?
    let endDate: String?
    let isExpired: Bool

    enum CodingKeys: String, CodingKey {
        case id, cardnumber, credit, status
        case initialAmount = "initial_amount"
        case endDate = "end_date"
        case isExpired = "is_expired"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int.self, forKey: .id)) ?? 0
        cardnumber = (try? c.decode(String.self, forKey: .cardnumber)) ?? ""
        credit = (try? c.decode(Double.self, forKey: .credit)) ?? 0
        initialAmount = try? c.decode(Double.self, forKey: .initialAmount)
        status = (try? c.decode(String.self, forKey: .status))?.nilIfFalseEmpty
        endDate = (try? c.decode(String.self, forKey: .endDate))?.nilIfFalseEmpty
        isExpired = (try? c.decode(Bool.self, forKey: .isExpired)) ?? false
    }

    /// Statut lisible affiché dans le badge.
    var statusLabel: String {
        if isExpired { return "Expirée" }
        switch status {
        case "ACTIVE": return "Active"
        case "BLOCKED": return "Bloquée"
        default: return status ?? "—"
        }
    }
}

// MARK: - Résultat du scan (/scanner-carte-cadeau/scan)

struct GiftCardScanResult: Decodable {
    let success: Bool
    let linked: Bool?
    let error: String?
    let giftcard: GiftCardInfo?
    let events: [GiftCardEvent]?
}

struct GiftCardInfo: Decodable, Hashable {
    let id: Int
    let cardnumber: String
    let credit: Double
    let initialAmount: Double?
    let status: String?
    let startDate: String?
    let endDate: String?
    let isExpired: Bool

    enum CodingKeys: String, CodingKey {
        case id, cardnumber, credit, status
        case initialAmount = "initial_amount"
        case startDate = "start_date"
        case endDate = "end_date"
        case isExpired = "is_expired"
    }

    var statusLabel: String {
        if isExpired { return "Expirée" }
        switch status {
        case "ACTIVE": return "Active"
        case "BLOCKED": return "Bloquée"
        default: return status ?? "—"
        }
    }
}

struct GiftCardEvent: Decodable, Identifiable, Hashable {
    let id: Int
    let date: String?
    let type: String?
    let amount: Double?
    let merchant: String?
    let comment: String?

    /// true si la transaction crédite la carte (rechargement), false si elle débite (achat).
    var isCredit: Bool {
        guard let amount else { return false }
        return amount >= 0
    }
}

// MARK: - Helpers

extension String {
    /// Renvoie nil si la chaîne est vide ou égale à "false" (Odoo).
    var nilIfFalseEmpty: String? {
        let t = trimmingCharacters(in: .whitespaces)
        return (t.isEmpty || t == "false") ? nil : self
    }
}

enum GiftCardFormat {
    /// "2026-12-31 00:00:00" ou ISO "2026-12-31T00:00:00" → "31/12/2026"
    static func frenchDate(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        let datePart = raw.replacingOccurrences(of: "T", with: " ")
            .split(separator: " ").first.map(String.init) ?? raw
        let comps = datePart.split(separator: "-")
        guard comps.count == 3 else { return nil }
        return "\(comps[2])/\(comps[1])/\(comps[0])"
    }

    /// 10.0 → "10,00 €"
    static func euros(_ value: Double) -> String {
        let s = String(format: "%.2f", value).replacingOccurrences(of: ".", with: ",")
        return "\(s) €"
    }

    static func signedEuros(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "−"
        return "\(sign)\(euros(abs(value)))"
    }
}
