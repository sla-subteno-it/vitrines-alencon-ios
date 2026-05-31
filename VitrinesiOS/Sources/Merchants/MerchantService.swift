// MerchantService.swift
// Vitrines d'Alençon — iOS
// Service unique pour toutes les données commerçants.
// Utilise search_read Odoo (JSON-RPC) — pas de parsing HTML.

import Foundation

final class MerchantService {
    static let shared = MerchantService()
    private let client = OdooClient.shared
    private init() {}

    // MARK: - Champs à récupérer pour la liste

    private let listFields = [
        "id", "name",
        "company_brief", "short_sales_descr",
        "image_1920", "default_image_url",
        "accept_fidelity_card", "accept_gift_card",
        "fvalue_sum", "is_visible",
        "local_rewards_tag_ids",
        "ordered_reference_ids",
        "reference_tag_ids",
        "street", "zip", "city"
    ]

    // MARK: - Champs pour la fiche détail

    private let detailFields = [
        "id", "name",
        "company_brief", "sales_descr", "short_sales_descr",
        "image_1920", "default_image_url",
        "accept_fidelity_card", "accept_gift_card",
        "fvalue_sum", "is_visible",
        "local_rewards_tag_ids",
        "ordered_reference_ids",
        "reference_tag_ids",
        "street", "zip", "city", "phone", "website", "email",
        "opening_hours", "api_unique_id"
    ]

    // MARK: - Domain Odoo de base (commerçants visibles)

    private var baseDomain: [[Any]] {
        [
            ["is_company", "=", true],
            ["api_unique_id", "!=", false],
            ["is_visible", "=", true],
            "|",
            ["accept_fidelity_card", "=", true],
            ["accept_gift_card", "=", true]
        ]
    }

    // MARK: - Liste des commerçants

    func fetchMerchants(filters: MerchantFilters = MerchantFilters()) async throws -> [Merchant] {
        var domain = baseDomain

        // Filtre par tag (catégorie commerçant)
        if let tagId = filters.tagId {
            domain.append(["local_rewards_tag_ids", "in", [tagId]])
        }

        // Filtre multi-références (OR)
        if !filters.referenceIds.isEmpty {
            domain.append(["ordered_reference_ids", "in", filters.referenceIds])
        }

        // Filtre multi-univers / reference_tag (OR)
        if !filters.referenceTagIds.isEmpty {
            domain.append(["reference_tag_ids", "in", filters.referenceTagIds])
        }

        // Filtre carte cadeau
        if filters.acceptGiftCard {
            domain.append(["accept_gift_card", "=", true])
        }

        // Filtre carte fidélité
        if filters.acceptFidelityCard {
            domain.append(["accept_fidelity_card", "=", true])
        }

        let kwargs: [String: Any] = [
            "domain": domain,
            "fields": listFields,
            "order": "fvalue_sum desc, name asc",
            "limit": 200
        ]

        let results: [Merchant] = try await client.call(
            model: "res.partner",
            method: "search_read",
            args: [],
            kwargs: kwargs
        )

        // Filtre recherche textuelle côté client (comme Odoo)
        if !filters.search.isEmpty {
            let q = filters.search.lowercased()
            return results.filter { merchant in
                merchant.name.lowercased().contains(q)
            }
        }

        return results
    }

    // MARK: - Détail d'un commerçant

    func fetchMerchant(id: Int) async throws -> Merchant {
        let kwargs: [String: Any] = [
            "domain": [["id", "=", id]],
            "fields": detailFields,
            "limit": 1
        ]

        let results: [Merchant] = try await client.call(
            model: "res.partner",
            method: "search_read",
            args: [],
            kwargs: kwargs
        )

        guard let merchant = results.first else {
            throw OdooError.odooError(code: 404, message: "Commerçant introuvable")
        }

        return merchant
    }

    // MARK: - Tags (local.rewards.tag)

    func fetchTags() async throws -> [RewardsTag] {
        let kwargs: [String: Any] = [
            "domain": [],
            "fields": ["id", "name"],
            "order": "name asc"
        ]

        return try await client.call(
            model: "local.rewards.tag",
            method: "search_read",
            args: [],
            kwargs: kwargs
        )
    }

    // MARK: - Références / Enseignes (merchant.reference)

    func fetchReferences(tagId: Int? = nil) async throws -> [MerchantReference] {
        var domain: [[Any]] = []
        if let tagId = tagId {
            domain.append(["local_rewards_tag_ids", "in", [tagId]])
        }

        let kwargs: [String: Any] = [
            "domain": domain,
            "fields": ["id", "name", "description", "reference_tag_ids"],
            "order": "name asc"
        ]

        return try await client.call(
            model: "merchant.reference",
            method: "search_read",
            args: [],
            kwargs: kwargs
        )
    }

    // MARK: - Catégories produits (merchant.reference.tag)

    func fetchReferenceTags() async throws -> [MerchantReferenceTag] {
        let kwargs: [String: Any] = [
            "domain": [["active", "=", true]],
            "fields": ["id", "name"],
            "order": "name asc"
        ]

        return try await client.call(
            model: "merchant.reference.tag",
            method: "search_read",
            args: [],
            kwargs: kwargs
        )
    }

    // MARK: - Avis d'un commerçant (local.rewards.event type Quizz_Session)

    func fetchReviews(merchantId: Int) async throws -> [MerchantReview] {
        let kwargs: [String: Any] = [
            "domain": [
                ["merchant_id", "=", merchantId],
                ["type", "=", "Quizz_Session"],
                ["status2", "=", true]
            ],
            "fields": ["id", "date", "fvalue", "comment", "member_id"],
            "order": "date desc",
            "limit": 50
        ]

        // Odoo renvoie member_id comme [id, name] — on décode manuellement
        let raw: [[String: Any]] = try await callRaw(
            model: "local.rewards.event",
            method: "search_read",
            kwargs: kwargs
        )

        return raw.compactMap { dict -> MerchantReview? in
            guard let id = dict["id"] as? Int else { return nil }
            let date   = dict["date"] as? String ?? ""
            let fvalue = dict["fvalue"] as? Double ?? 0
            let comment = dict["comment"] as? String ?? ""
            var firstName = ""
            var lastName = ""

            // member_id = [id, "Prénom NOM"] ou false
            if let memberTuple = dict["member_id"] as? [Any],
               memberTuple.count >= 2,
               let fullName = memberTuple[1] as? String {
                let parts = fullName.split(separator: " ", maxSplits: 1)
                firstName = String(parts.first ?? "")
                lastName  = parts.count > 1 ? String(parts[1]) : ""
            }

            return MerchantReview(
                id: id, date: date, rating: fvalue,
                comment: comment,
                memberFirstName: firstName, memberLastName: lastName
            )
        }
    }

    // MARK: - Coupons actifs d'un commerçant (local.rewards.offer)

    func fetchActiveCoupons(merchantId: Int) async throws -> [MerchantCoupon] {
        let kwargs: [String: Any] = [
            "domain": [
                ["merchant_id", "=", merchantId],
                ["active", "=", true],
                ["status", "=", "ACTIVE"],
                ["is_expired", "=", false]
            ],
            "fields": ["id", "name", "coupon_value", "coupon_unit", "date_valid_until", "short_text_content"],
            "order": "date_valid_until asc",
            "limit": 5
        ]

        return try await client.call(
            model: "local.rewards.offer",
            method: "search_read",
            args: [],
            kwargs: kwargs
        )
    }

    // MARK: - Ajouter aux favoris (nécessite auth)

    func toggleFavorite(merchantApiUniqueId: String, isFavorite: Bool) async throws {
        // Délégué à Odoo qui appelle Adelya
        let method = isFavorite ? "remove_from_favorite" : "add_to_favorite"
        let _: Bool = try await client.call(
            model: "adelya.api",
            method: method,
            args: [],
            kwargs: ["merchant_unique_id": merchantApiUniqueId]
        )
    }

    // MARK: - Soumettre un avis

    func submitReview(merchantApiUniqueId: String, rating: Int, comment: String) async throws {
        let _: Bool = try await client.call(
            model: "adelya.api",
            method: "create_quizz_session_comment",
            args: [],
            kwargs: [
                "merchant_unique_id": merchantApiUniqueId,
                "rating": rating,
                "comment": comment
            ]
        )
    }

    // MARK: - Appel brut (réponse non typée)

    private func callRaw(model: String, method: String, kwargs: [String: Any]) async throws -> [[String: Any]] {
        let url = URL(string: OdooConfig.baseURL + OdooConfig.jsonRPCPath)!
        let body: [String: Any] = [
            "jsonrpc": "2.0", "method": "call", "id": 1,
            "params": ["model": model, "method": method, "args": [], "kwargs": kwargs]
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let session = URLSession.shared
        let (data, _) = try await session.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [[String: Any]] else {
            return []
        }

        return result
    }
}
