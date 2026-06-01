// MerchantModels.swift
// Vitrines d'Alençon — iOS
// Modèles de données correspondant exactement aux champs Odoo
// (res.partner, local.rewards.tag, merchant.reference, merchant.reference.tag)

import Foundation

// MARK: - Commerçant (res.partner côté merchant)

struct Merchant: Identifiable, Decodable, Hashable {
    let id: Int
    let name: String

    // Champs visuels
    let companyBrief: String?          // Accroche courte
    let salesDescr: String?            // Description commerciale
    let shortSalesDescr: String?       // Description courte
    let openingHours: String?          // Horaires d'ouverture
    let defaultImageUrl: String?       // Fallback image Adelya
    let hasImage: Bool                 // image_1920 présente côté Odoo

    // Adresse
    let street: String?
    let zip: String?
    let city: String?
    let phone: String?
    let website: String?
    let email: String?

    // Cartes acceptées
    let acceptFidelityCard: Bool
    let acceptGiftCard: Bool

    // Classement (somme des fvalue addCA)
    let fvalueSum: Double

    // Tags (catégories de commerçants ex: Mode, Restauration...)
    let localRewardsTagIds: [Int]      // IDs des tags

    // Références (marques/enseignes ex: Zara, Sephora...)
    let orderedReferenceIds: [Int]     // IDs des références ordonnées

    // Categories produits directement associées
    let referenceTagIds: [Int]

    // Identifiant Adelya (api_unique_id)
    let apiUniqueId: String?

    // Visible dans l'annuaire
    let isVisible: Bool

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id, name
        case companyBrief         = "company_brief"
        case salesDescr           = "sales_descr"
        case shortSalesDescr      = "short_sales_descr"
        case openingHours         = "opening_hours"
        case defaultImageUrl      = "default_image_url"
        case hasImage             = "image_1920"          // Odoo renvoie bool si on demande le champ
        case street, zip, city, phone, website, email
        case acceptFidelityCard   = "accept_fidelity_card"
        case acceptGiftCard       = "accept_gift_card"
        case fvalueSum            = "fvalue_sum"
        case localRewardsTagIds   = "local_rewards_tag_ids"
        case orderedReferenceIds  = "ordered_reference_ids"
        case referenceTagIds      = "reference_tag_ids"
        case apiUniqueId          = "api_unique_id"
        case isVisible            = "is_visible"
    }

    // Décodage custom car Odoo renvoie false ou [Int] pour les Many2many
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decode(Int.self, forKey: .id)
        name            = try c.decode(String.self, forKey: .name)
        companyBrief    = try? c.decode(String.self, forKey: .companyBrief)
        salesDescr      = try? c.decode(String.self, forKey: .salesDescr)
        shortSalesDescr = try? c.decode(String.self, forKey: .shortSalesDescr)
        openingHours    = try? c.decode(String.self, forKey: .openingHours)
        defaultImageUrl = try? c.decode(String.self, forKey: .defaultImageUrl)
        street          = try? c.decode(String.self, forKey: .street)
        zip             = try? c.decode(String.self, forKey: .zip)
        city            = try? c.decode(String.self, forKey: .city)
        phone           = try? c.decode(String.self, forKey: .phone)
        website         = try? c.decode(String.self, forKey: .website)
        email           = try? c.decode(String.self, forKey: .email)
        apiUniqueId     = try? c.decode(String.self, forKey: .apiUniqueId)
        fvalueSum       = (try? c.decode(Double.self, forKey: .fvalueSum)) ?? 0
        isVisible       = (try? c.decode(Bool.self, forKey: .isVisible)) ?? true
        acceptFidelityCard = (try? c.decode(Bool.self, forKey: .acceptFidelityCard)) ?? false
        acceptGiftCard     = (try? c.decode(Bool.self, forKey: .acceptGiftCard)) ?? false

        // image_1920 : Odoo renvoie false ou les bytes base64 (on veut juste savoir si ≠ false)
        if let b = try? c.decode(Bool.self, forKey: .hasImage) {
            hasImage = b
        } else {
            hasImage = true // Si autre chose que false → image présente
        }

        // Many2many : Odoo renvoie [Int] ou false
        localRewardsTagIds  = (try? c.decode([Int].self, forKey: .localRewardsTagIds))  ?? []
        orderedReferenceIds = (try? c.decode([Int].self, forKey: .orderedReferenceIds)) ?? []
        referenceTagIds     = (try? c.decode([Int].self, forKey: .referenceTagIds))     ?? []
    }

    // URL image Odoo
    var imageURL: URL? {
        if hasImage {
            return URL(string: "\(OdooConfig.baseURL)/web/image/res.partner/\(id)/image_1920?width=400")
        } else if let url = defaultImageUrl, !url.isEmpty {
            return URL(string: url.hasPrefix("http") ? url : OdooConfig.baseURL + url)
        }
        return nil
    }

    // Adresse formatée
    var formattedAddress: String? {
        let parts = [street, zip.flatMap { z in city.map { "\(z) \($0)" } }].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    // Hashable
    static func == (lhs: Merchant, rhs: Merchant) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Tag commerçant (local.rewards.tag)

struct RewardsTag: Identifiable, Decodable, Hashable {
    let id: Int
    let name: String

    static func == (lhs: RewardsTag, rhs: RewardsTag) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Référence / Enseigne (merchant.reference)

struct MerchantReference: Identifiable, Decodable, Hashable {
    let id: Int
    let name: String
    let description: String?
    let referenceTagIds: [Int]

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case referenceTagIds = "reference_tag_ids"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(Int.self, forKey: .id)
        name        = try c.decode(String.self, forKey: .name)
        description = try? c.decode(String.self, forKey: .description)
        referenceTagIds = (try? c.decode([Int].self, forKey: .referenceTagIds)) ?? []
    }

    static func == (lhs: MerchantReference, rhs: MerchantReference) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Catégorie produit (merchant.reference.tag)

struct MerchantReferenceTag: Identifiable, Decodable, Hashable {
    let id: Int
    let name: String

    static func == (lhs: MerchantReferenceTag, rhs: MerchantReferenceTag) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Avis / Commentaire (local.rewards.event type Quizz_Session)

struct MerchantReview: Identifiable {
    let id: Int
    let date: String
    let rating: Double   // fvalue (1–5)
    let comment: String
    let memberFirstName: String
    let memberLastName: String

    var displayName: String {
        let first = memberFirstName.isEmpty ? "" : memberFirstName
        let initial = memberLastName.first.map { "\($0)." } ?? ""
        return [first, initial].filter { !$0.isEmpty }.joined(separator: " ")
    }
}

// MARK: - Coupon lié à un commerçant (local.rewards.offer)

struct MerchantCoupon: Identifiable, Decodable, Hashable {
    let id: Int
    let name: String
    let couponValue: Double
    let couponUnit: String?
    let dateValidUntil: String?
    let shortTextContent: String?
    let imageUrl: String?
    let merchantId: Int?
    let merchantName: String?
    let hasEndDate: Bool

    enum CodingKeys: String, CodingKey {
        case id, name
        case couponValue      = "coupon_value"
        case couponUnit       = "coupon_unit"
        case dateValidUntil   = "date_valid_until"
        case shortTextContent = "short_text_content"
        case imageUrl         = "image_url"
        case merchantId       = "merchant_id"
        case hasEndDate       = "has_end_date"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try c.decode(Int.self, forKey: .id)
        name             = (try? c.decode(String.self, forKey: .name)) ?? ""
        couponValue      = (try? c.decode(Double.self, forKey: .couponValue)) ?? 0
        couponUnit       = try? c.decode(String.self, forKey: .couponUnit)
        dateValidUntil   = try? c.decode(String.self, forKey: .dateValidUntil)
        shortTextContent = try? c.decode(String.self, forKey: .shortTextContent)
        imageUrl         = try? c.decode(String.self, forKey: .imageUrl)
        hasEndDate       = (try? c.decode(Bool.self, forKey: .hasEndDate)) ?? false

        // merchant_id (Many2one) : Odoo renvoie [id, "name"] ou false
        if var m2o = try? c.nestedUnkeyedContainer(forKey: .merchantId) {
            merchantId   = try? m2o.decode(Int.self)
            merchantName = try? m2o.decode(String.self)
        } else {
            merchantId   = nil
            merchantName = nil
        }
    }

    /// URL de l'image du bon plan (image_url Adelya, sinon image Odoo de l'offre).
    var imageURL: URL? {
        if let url = imageUrl, !url.isEmpty {
            return URL(string: url.hasPrefix("http") ? url : OdooConfig.baseURL + url)
        }
        return nil
    }

    static func == (lhs: MerchantCoupon, rhs: MerchantCoupon) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Filtres actifs

struct MerchantFilters: Equatable {
    var search: String = ""
    var tagId: Int? = nil
    var referenceIds: [Int] = []
    var referenceTagIds: [Int] = []
    var acceptGiftCard: Bool = false
    var acceptFidelityCard: Bool = false

    var isEmpty: Bool {
        search.isEmpty
        && tagId == nil
        && referenceIds.isEmpty
        && referenceTagIds.isEmpty
        && !acceptGiftCard
        && !acceptFidelityCard
    }

    var activeCount: Int {
        var count = 0
        if tagId != nil { count += 1 }
        count += referenceIds.count
        count += referenceTagIds.count
        if acceptGiftCard { count += 1 }
        if acceptFidelityCard { count += 1 }
        return count
    }
}

// MARK: - Catégories d'un commerçant (léger, pour le filtre Bons Plans)

struct PartnerCategories: Decodable {
    let id: Int
    let localRewardsTagIds: [Int]

    enum CodingKeys: String, CodingKey {
        case id
        case localRewardsTagIds = "local_rewards_tag_ids"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        localRewardsTagIds = (try? c.decode([Int].self, forKey: .localRewardsTagIds)) ?? []
    }
}

// MARK: - Réponse search_read Odoo

struct OdooSearchReadResponse<T: Decodable>: Decodable {
    let records: [T]
}
