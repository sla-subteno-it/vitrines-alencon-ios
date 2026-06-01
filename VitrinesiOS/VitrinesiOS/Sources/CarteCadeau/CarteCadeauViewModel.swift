// CarteCadeauViewModel.swift
// Vitrines d'Alençon — iOS
// Logique de la page carte cadeau : liste des cartes du membre + scan.

import Foundation
import Combine

@MainActor
final class CarteCadeauViewModel: ObservableObject {
    @Published var giftCards: [GiftCard] = []
    @Published var isLoadingList = false
    @Published var listError: String?

    // Scan / recherche
    @Published var isScanning = false        // recherche réseau en cours
    @Published var scanError: String?
    @Published var scanResult: GiftCardScanResult?

    private let client = OdooClient.shared
    private var partnerId: Int?
    private var cardId: Int?

    private struct PartnerRef: Decodable {
        let refId: Int?
        enum CodingKeys: String, CodingKey { case partnerId = "partner_id" }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            if var m2o = try? c.nestedUnkeyedContainer(forKey: .partnerId) {
                refId = try? m2o.decode(Int.self)
            } else { refId = nil }
        }
    }

    private struct PartnerCardRow: Decodable {
        let cardId: Int?
        enum CodingKeys: String, CodingKey { case cardId = "local_rewards_card_id" }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            if var m2o = try? c.nestedUnkeyedContainer(forKey: .cardId) {
                cardId = try? m2o.decode(Int.self)
            } else { cardId = nil }
        }
    }

    private struct IdRow: Decodable { let id: Int }

    // MARK: - Chargement de la liste "Mes cartes cadeaux"

    func loadGiftCards() async {
        isLoadingList = true
        defer { isLoadingList = false }
        do {
            let memberIds = try await resolveMemberIds()
            guard !memberIds.isEmpty else { giftCards = []; return }

            let cards: [GiftCard] = try await client.call(
                model: "local.rewards.gift.card", method: "search_read", args: [],
                kwargs: ["domain": [["member_id", "in", memberIds],
                                    ["status", "=", "ACTIVE"],
                                    ["is_expired", "=", false]],
                         "fields": ["cardnumber", "credit", "initial_amount",
                                    "status", "end_date", "is_expired"],
                         "order": "date_create desc"]
            )
            giftCards = cards
            listError = nil
        } catch {
            listError = (error as? OdooError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Résout les partner ids partageant la même carte de fidélité.
    private func resolveMemberIds() async throws -> [Int] {
        if let pid = partnerId {
            return try await relatedMembers(partnerId: pid, cardId: cardId)
        }
        guard let uid = await OdooSession.shared.getUID() else { return [] }
        let users: [PartnerRef] = try await client.call(
            model: "res.users", method: "search_read", args: [],
            kwargs: ["domain": [["id", "=", uid]], "fields": ["partner_id"], "limit": 1]
        )
        guard let pid = users.first?.refId else { return [] }
        partnerId = pid

        let partners: [PartnerCardRow] = try await client.call(
            model: "res.partner", method: "search_read", args: [],
            kwargs: ["domain": [["id", "=", pid]],
                     "fields": ["local_rewards_card_id"], "limit": 1]
        )
        cardId = partners.first?.cardId
        return try await relatedMembers(partnerId: pid, cardId: cardId)
    }

    private func relatedMembers(partnerId pid: Int, cardId: Int?) async throws -> [Int] {
        guard let cardId else { return [pid] }
        let members: [IdRow] = try await client.call(
            model: "res.partner", method: "search_read", args: [],
            kwargs: ["domain": [["local_rewards_card_id", "=", cardId],
                                ["is_company", "=", false]],
                     "fields": ["id"],
                     "context": ["active_test": false]]
        )
        return members.isEmpty ? [pid] : members.map { $0.id }
    }

    // MARK: - Scan d'un numéro de carte

    /// Appelle l'endpoint Odoo qui interroge Adelya, lie la carte au membre et
    /// renvoie le solde + l'historique.
    func scan(cardnumber raw: String) async {
        let cardnumber = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cardnumber.isEmpty else { return }
        isScanning = true
        scanError = nil
        defer { isScanning = false }
        do {
            let result: GiftCardScanResult = try await client.callRoute(
                "/scanner-carte-cadeau/scan",
                params: ["cardnumber": cardnumber]
            )
            if result.success {
                scanResult = result
                scanError = nil
                await loadGiftCards()   // rafraîchir la liste (nouvelle carte liée)
            } else {
                scanResult = nil
                scanError = result.error ?? "Carte cadeau introuvable."
            }
        } catch {
            scanResult = nil
            scanError = (error as? OdooError)?.errorDescription ?? error.localizedDescription
        }
    }

    func clearResult() {
        scanResult = nil
        scanError = nil
    }
}
