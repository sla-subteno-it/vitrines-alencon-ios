// MerchantViewModel.swift
// Vitrines d'Alençon — iOS
// ViewModel pour la liste et la fiche commerçant.
// Architecture : ObservableObject + async/await

import Foundation
import Combine

// MARK: - ViewModel liste

@MainActor
final class MerchantsViewModel: ObservableObject {

    // MARK: - État

    @Published var merchants: [Merchant] = []
    @Published var allTags: [RewardsTag] = []
    @Published var allReferences: [MerchantReference] = []
    @Published var allReferenceTags: [MerchantReferenceTag] = []

    @Published var filters = MerchantFilters()
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Vues disponibles (comme la PWA : liste / catégories / enseignes)
    enum DirectoryView: String, CaseIterable {
        case list       = "Liste"
        case categories = "Catégories"
        case brands     = "Enseignes"
    }
    @Published var currentView: DirectoryView = .list

    private let service = MerchantService.shared

    /// Liste complète des commerçants visibles (filtrage appliqué côté client).
    private var allMerchants: [Merchant] = []

    /// Index id → nom d'enseigne, pour afficher les marques sur les cartes.
    private var referenceNameById: [Int: String] = [:]
    /// Index id enseigne → ses univers (reference_tag_ids), pour le filtre univers.
    private var refTagsById: [Int: [Int]] = [:]

    /// Noms des marques/enseignes d'un commerçant, dans l'ordre Odoo.
    func brandNames(for merchant: Merchant) -> [String] {
        merchant.orderedReferenceIds.compactMap { referenceNameById[$0] }
    }

    // MARK: - Chargement initial

    func loadAll() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let merchantsResult = service.fetchMerchants()
            async let tagsResult = service.fetchTags()
            async let referencesResult = service.fetchReferences()
            async let referenceTagsResult = service.fetchReferenceTags()

            let (m, t, r, rt) = try await (merchantsResult, tagsResult, referencesResult, referenceTagsResult)
            allMerchants     = m
            allTags          = t
            allReferences    = r
            allReferenceTags = rt
            referenceNameById = Dictionary(r.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
            refTagsById = Dictionary(r.map { ($0.id, $0.referenceTagIds) }, uniquingKeysWith: { a, _ in a })
            applyFilters()

        } catch {
            errorMessage = (error as? OdooError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Filtres (100% côté client)
    // Les champs ordered_reference_ids / reference_tag_ids ne sont PAS stockés côté
    // Odoo → impossible de filtrer via le domaine. On filtre donc en Swift, comme la PWA.

    func onSearchChanged() { applyFilters() }

    func applyFilters() {
        merchants = filtered(allMerchants)
    }

    private func filtered(_ list: [Merchant]) -> [Merchant] {
        var r = list
        if let tagId = filters.tagId {
            r = r.filter { $0.localRewardsTagIds.contains(tagId) }
        }
        if !filters.referenceIds.isEmpty {
            r = r.filter { m in filters.referenceIds.contains { m.orderedReferenceIds.contains($0) } }
        }
        if !filters.referenceTagIds.isEmpty {
            r = r.filter { m in
                var tags = Set(m.referenceTagIds)
                for refId in m.orderedReferenceIds { tags.formUnion(refTagsById[refId] ?? []) }
                return filters.referenceTagIds.contains { tags.contains($0) }
            }
        }
        if filters.acceptGiftCard { r = r.filter { $0.acceptGiftCard } }
        if filters.acceptFidelityCard { r = r.filter { $0.acceptFidelityCard } }
        let q = filters.search.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            r = r.filter { m in
                m.name.lowercased().contains(q)
                || m.orderedReferenceIds.contains { (referenceNameById[$0] ?? "").lowercased().contains(q) }
            }
        }
        return r
    }

    func clearFilters() {
        filters = MerchantFilters()
        applyFilters()
    }

    func selectTag(_ tag: RewardsTag?) {
        filters.tagId = (filters.tagId == tag?.id) ? nil : tag?.id
        applyFilters()
    }

    func toggleReference(_ refId: Int) {
        if filters.referenceIds.contains(refId) {
            filters.referenceIds.removeAll { $0 == refId }
        } else {
            filters.referenceIds.append(refId)
        }
        applyFilters()
    }

    func toggleReferenceTag(_ tagId: Int) {
        if filters.referenceTagIds.contains(tagId) {
            filters.referenceTagIds.removeAll { $0 == tagId }
        } else {
            filters.referenceTagIds.append(tagId)
        }
        applyFilters()
    }

    // MARK: - Comptage par tag (comme PWA)

    func merchantCount(forTag tag: RewardsTag) -> Int {
        allMerchants.filter { $0.localRewardsTagIds.contains(tag.id) }.count
    }

    func merchantCount(forReference id: Int) -> Int {
        allMerchants.filter { $0.orderedReferenceIds.contains(id) }.count
    }

    // MARK: - Sections alphabétiques pour l'index enseignes

    var brandSections: [(letter: String, references: [MerchantReference])] {
        let letters = ["#"] + (65...90).map { String(UnicodeScalar($0)!) }
        return letters.compactMap { letter -> (String, [MerchantReference])? in
            let refs = allReferences.filter { ref in
                guard let first = ref.name.first else { return letter == "#" }
                let normalized = first.unicodeScalars.first
                    .flatMap { Character(UnicodeScalar(UInt32($0.value))!) }
                    .map { String($0).uppercased() } ?? "#"
                if letter == "#" {
                    return !"ABCDEFGHIJKLMNOPQRSTUVWXYZ".contains(normalized)
                }
                return normalized == letter
            }
            return refs.isEmpty ? nil : (letter, refs)
        }
    }
}

// MARK: - ViewModel fiche détail

@MainActor
final class MerchantDetailViewModel: ObservableObject {

    @Published var merchant: Merchant?
    @Published var reviews: [MerchantReview] = []
    @Published var coupons: [MerchantCoupon] = []
    @Published var brandNames: [String] = []
    @Published var categoryNames: [String] = []
    @Published var isFavorite = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    // Statistiques avis
    var averageRating: Double {
        guard !reviews.isEmpty else { return 0 }
        return reviews.map { $0.rating }.reduce(0, +) / Double(reviews.count)
    }

    private let service = MerchantService.shared
    let merchantId: Int

    init(merchantId: Int) {
        self.merchantId = merchantId
    }

    // MARK: - Chargement

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let merchantResult   = service.fetchMerchant(id: merchantId)
            async let reviewsResult    = service.fetchReviews(merchantId: merchantId)
            async let couponsResult    = service.fetchActiveCoupons(merchantId: merchantId)
            async let referencesResult = service.fetchReferences()
            async let tagsResult       = service.fetchTags()

            let (m, r, c, refs, tags) = try await (merchantResult, reviewsResult, couponsResult, referencesResult, tagsResult)
            merchant = m
            reviews  = r
            coupons  = c

            let refNameById = Dictionary(refs.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
            brandNames = m.orderedReferenceIds.compactMap { refNameById[$0] }

            let tagNameById = Dictionary(tags.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
            categoryNames = m.localRewardsTagIds.compactMap { tagNameById[$0] }

        } catch {
            errorMessage = (error as? OdooError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Favori

    func toggleFavorite() async {
        guard let apiId = merchant?.apiUniqueId else { return }
        do {
            try await service.toggleFavorite(merchantApiUniqueId: apiId, isFavorite: isFavorite)
            isFavorite.toggle()
        } catch {
            errorMessage = (error as? OdooError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Soumettre un avis

    func submitReview(rating: Int, comment: String) async {
        guard let apiId = merchant?.apiUniqueId else { return }
        do {
            try await service.submitReview(
                merchantApiUniqueId: apiId,
                rating: rating,
                comment: comment
            )
            successMessage = "Votre avis a été enregistré avec succès !"
            // Recharger les avis
            reviews = try await service.fetchReviews(merchantId: merchantId)
        } catch {
            errorMessage = (error as? OdooError)?.errorDescription ?? error.localizedDescription
        }
    }
}
