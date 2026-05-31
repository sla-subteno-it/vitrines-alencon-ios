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
    private var searchTask: Task<Void, Never>?

    // MARK: - Chargement initial

    func loadAll() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let merchantsResult = service.fetchMerchants(filters: filters)
            async let tagsResult = service.fetchTags()
            async let referencesResult = service.fetchReferences()
            async let referenceTagsResult = service.fetchReferenceTags()

            let (m, t, r, rt) = try await (merchantsResult, tagsResult, referencesResult, referenceTagsResult)
            merchants        = m
            allTags          = t
            allReferences    = r
            allReferenceTags = rt

        } catch {
            errorMessage = (error as? OdooError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Recherche avec debounce

    func onSearchChanged() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000) // 400ms debounce
            guard !Task.isCancelled else { return }
            await applyFilters()
        }
    }

    // MARK: - Appliquer les filtres

    func applyFilters() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            merchants = try await service.fetchMerchants(filters: filters)
        } catch {
            errorMessage = (error as? OdooError)?.errorDescription ?? error.localizedDescription
        }
    }

    func clearFilters() {
        filters = MerchantFilters()
        Task { await applyFilters() }
    }

    func selectTag(_ tag: RewardsTag?) {
        filters.tagId = (filters.tagId == tag?.id) ? nil : tag?.id
        Task { await applyFilters() }
    }

    func toggleReference(_ refId: Int) {
        if filters.referenceIds.contains(refId) {
            filters.referenceIds.removeAll { $0 == refId }
        } else {
            filters.referenceIds.append(refId)
        }
        Task { await applyFilters() }
    }

    func toggleReferenceTag(_ tagId: Int) {
        if filters.referenceTagIds.contains(tagId) {
            filters.referenceTagIds.removeAll { $0 == tagId }
        } else {
            filters.referenceTagIds.append(tagId)
        }
        Task { await applyFilters() }
    }

    // MARK: - Comptage par tag (comme PWA)

    func merchantCount(forTag tag: RewardsTag) -> Int {
        merchants.filter { $0.localRewardsTagIds.contains(tag.id) }.count
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
            async let merchantResult = service.fetchMerchant(id: merchantId)
            async let reviewsResult  = service.fetchReviews(merchantId: merchantId)
            async let couponsResult  = service.fetchActiveCoupons(merchantId: merchantId)

            let (m, r, c) = try await (merchantResult, reviewsResult, couponsResult)
            merchant = m
            reviews  = r
            coupons  = c

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
