// BonsPlansListView.swift
// Vitrines d'Alençon — iOS
// Onglet Bons Plans : offres actives (local.rewards.offer), réplique de /bons-plans.

import SwiftUI
import Combine

// MARK: - ViewModel

@MainActor
final class BonsPlansViewModel: ObservableObject {
    @Published var permanent: [MerchantCoupon] = []
    @Published var dated: [MerchantCoupon] = []
    @Published var expired: [MerchantCoupon] = []
    @Published var categories: [String] = []
    @Published var selectedCategory: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = MerchantService.shared
    private var allPermanent: [MerchantCoupon] = []
    private var allDated: [MerchantCoupon] = []
    private var offerCategories: [Int: Set<String>] = [:]

    var total: Int { allPermanent.count + allDated.count }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let activeR  = service.fetchAllActiveOffers()
            async let expiredR = service.fetchExpiredOffers()
            async let tagsR    = service.fetchTags()
            let (active, exp, tags) = try await (activeR, expiredR, tagsR)
            expired = exp

            // Catégories des commerçants → catégories des offres (pour les filtres)
            let merchantIds = Array(Set(active.compactMap { $0.merchantId }))
            let partnerCats = (try? await service.fetchPartnerCategories(ids: merchantIds)) ?? [:]
            let tagName = Dictionary(tags.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })

            offerCategories = [:]
            for offer in active {
                if let mid = offer.merchantId, let tids = partnerCats[mid] {
                    offerCategories[offer.id] = Set(tids.compactMap { tagName[$0] })
                }
            }
            categories = Set(offerCategories.values.flatMap { $0 }).sorted()
            allPermanent = active.filter { !$0.hasEndDate }
            allDated     = active.filter { $0.hasEndDate }
            applyFilter()
        } catch {
            errorMessage = (error as? OdooError)?.errorDescription ?? error.localizedDescription
        }
    }

    func select(_ category: String?) {
        selectedCategory = category
        applyFilter()
    }

    private func applyFilter() {
        guard let cat = selectedCategory else {
            permanent = allPermanent
            dated = allDated
            return
        }
        permanent = allPermanent.filter { offerCategories[$0.id]?.contains(cat) ?? false }
        dated     = allDated.filter { offerCategories[$0.id]?.contains(cat) ?? false }
    }
}

// MARK: - Vue principale

struct BonsPlansListView: View {
    @StateObject private var viewModel = BonsPlansViewModel()
    @State private var showExpired = false

    private let cardWidth: CGFloat = 220

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header.padding(.horizontal, 16)

                    if viewModel.isLoading && viewModel.total == 0 {
                        loadingView
                    } else if let error = viewModel.errorMessage, viewModel.total == 0 {
                        errorView(error)
                    } else if viewModel.total == 0 {
                        emptyView
                    } else {
                        categoryBar
                        if !viewModel.permanent.isEmpty {
                            carouselSection(title: "Offres permanentes", items: viewModel.permanent)
                        }
                        if !viewModel.dated.isEmpty {
                            carouselSection(title: "Durée limitée", items: viewModel.dated)
                        }
                        if !viewModel.expired.isEmpty {
                            expiredSection.padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.bottom, 24)
            }
            .background(LinearGradient.brandSurface.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: MerchantCoupon.self) { CouponDetailView(coupon: $0) }
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Les Bons Plans")
                .font(BrandFont.serif(28, weight: .bold))
                .foregroundStyle(Color.brandNavy)
            if viewModel.total > 0 {
                Text("\(viewModel.total) offre\(viewModel.total > 1 ? "s" : "") disponible\(viewModel.total > 1 ? "s" : "")")
                    .font(BrandFont.sans(14))
                    .foregroundStyle(Color.brandTextMuted)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Barre de filtres par catégorie

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 22) {
                categoryTab(label: "Tout", count: viewModel.total, isSelected: viewModel.selectedCategory == nil) {
                    viewModel.select(nil)
                }
                ForEach(viewModel.categories, id: \.self) { cat in
                    categoryTab(label: cat, count: nil, isSelected: viewModel.selectedCategory == cat) {
                        viewModel.select(cat)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.brandNavy.opacity(0.08)).frame(height: 1)
        }
    }

    private func categoryTab(label: String, count: Int?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Text(label)
                        .font(BrandFont.serif(17, weight: isSelected ? .bold : .regular))
                    if let count {
                        Text("\(count)")
                            .font(BrandFont.sans(11, weight: .semibold))
                            .foregroundStyle(Color.brandNavy)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.brandNavy.opacity(0.1), in: .capsule)
                    }
                }
                .foregroundStyle(isSelected ? Color.brandNavy : Color.brandTextMuted)
                Rectangle()
                    .fill(isSelected ? Color.brandNavy : .clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section carrousel horizontal

    private func carouselSection(title: String, items: [MerchantCoupon]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(title.uppercased())
                    .font(BrandFont.sans(12, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Color.brandTextMuted)
                Text("\(items.count)")
                    .font(BrandFont.sans(11, weight: .semibold))
                    .foregroundStyle(Color.brandNavy)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.brandNavy.opacity(0.08), in: .capsule)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.brandTextMuted)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(items) { coupon in
                        NavigationLink(value: coupon) {
                            BonPlanCard(coupon: coupon)
                                .frame(width: cardWidth)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Offres expirées (repliable)

    private var expiredSection: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showExpired.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("\(viewModel.expired.count) terminée\(viewModel.expired.count > 1 ? "s" : "")")
                        .font(BrandFont.sans(15, weight: .medium))
                    Spacer()
                    Image(systemName: showExpired ? "chevron.up" : "chevron.down")
                }
                .foregroundStyle(Color.brandTextMuted)
                .padding(16)
                .background(.white, in: .rect(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandNavy.opacity(0.06), lineWidth: 1))
            }
            .buttonStyle(.plain)

            if showExpired {
                VStack(spacing: 8) {
                    ForEach(viewModel.expired) { coupon in
                        NavigationLink(value: coupon) {
                            ExpiredOfferRow(coupon: coupon)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - États

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Chargement des bons plans…")
                .font(BrandFont.sans(14))
                .foregroundStyle(Color.brandTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Erreur de chargement", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Réessayer") { Task { await viewModel.load() } }
                .buttonStyle(.borderedProminent)
                .tint(Color.brandNavy)
        }
        .padding(.top, 60)
    }

    private var emptyView: some View {
        ContentUnavailableView("Aucun bon plan",
                               systemImage: "tag",
                               description: Text("Revenez bientôt pour découvrir de nouvelles offres."))
            .padding(.top, 60)
    }
}

// MARK: - Ligne offre terminée (liste compacte)

private struct ExpiredOfferRow: View {
    let coupon: MerchantCoupon

    var body: some View {
        HStack(spacing: 14) {
            thumbnail
            VStack(alignment: .leading, spacing: 3) {
                Text(coupon.name)
                    .font(BrandFont.serif(17, weight: .bold))
                    .foregroundStyle(Color(hex: 0x191919).opacity(0.7))
                    .lineLimit(1)
                Text(endedText)
                    .font(BrandFont.sans(13))
                    .foregroundStyle(Color(hex: 0x9AA0A6))
            }
            Spacer(minLength: 8)
            Text("TERMINÉ")
                .font(BrandFont.sans(11, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(Color(hex: 0xD4111E))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(hex: 0xD4111E).opacity(0.08), in: .capsule)
        }
        .padding(12)
        .background(.white, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.brandNavy.opacity(0.05), lineWidth: 1))
    }

    private var thumbnail: some View {
        Group {
            if let url = coupon.imageURL {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: 60, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var placeholder: some View {
        ZStack {
            Color(hex: 0xF1F3F5)
            Image(systemName: "questionmark")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(hex: 0xBFBFBF))
        }
    }

    private var endedText: String {
        guard let d = coupon.dateValidUntil.flatMap(CouponDetailView.parseOdooDate) else {
            return "Terminé"
        }
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "dd/MM/yyyy"
        return "Terminé le \(f.string(from: d))"
    }
}

// MARK: - Carte bon plan

private struct BonPlanCard: View {
    let coupon: MerchantCoupon
    var expired: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            imageView
            Text(coupon.name)
                .font(BrandFont.serif(16, weight: .bold))
                .foregroundStyle(Color(hex: 0x191919))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            metaRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(expired ? 0.65 : 1)
    }

    private var imageView: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                if let url = coupon.imageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFill()
                        case .empty:              ZStack { LinearGradient.brandSurface; ProgressView() }
                        default:                  noImage
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    noImage
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if !expired, coupon.hasEndDate, let days = daysRemaining {
                    Text(days <= 0 ? "Dernier jour" : "Encore \(days)j")
                        .font(BrandFont.sans(12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(urgencyColor(days), in: .rect(cornerRadius: 4))
                        .padding(12)
                }
            }
    }

    private var noImage: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0xF0F0F0), Color(hex: 0xE0E0E0)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "photo")
                .font(.largeTitle)
                .foregroundStyle(Color(hex: 0xCCCCCC))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var metaRow: some View {
        HStack(spacing: 4) {
            if let merchant = coupon.merchantName {
                Text(merchant)
                    .font(BrandFont.sans(13))
                    .foregroundStyle(Color(hex: 0x757575))
                    .lineLimit(1)
                Text("·").foregroundStyle(Color(hex: 0xBFBFBF))
            }
            if coupon.hasEndDate {
                Text(longDate.map { "Jusqu'au \($0)" } ?? "Offre limitée")
                    .font(BrandFont.sans(13, weight: .medium))
                    .foregroundStyle(Color(hex: 0x757575))
                    .lineLimit(1)
            } else {
                Label("Permanent", systemImage: "infinity")
                    .font(BrandFont.sans(13, weight: .medium))
                    .foregroundStyle(Color(hex: 0x05944F))
            }
        }
        .lineLimit(1)
    }

    private var validDate: Date? {
        coupon.dateValidUntil.flatMap(CouponDetailView.parseOdooDate)
    }

    private var daysRemaining: Int? {
        guard let d = validDate else { return nil }
        let secs = d.timeIntervalSinceNow
        return secs <= 0 ? 0 : Int(ceil(secs / 86400))
    }

    private var longDate: String? {
        guard let d = validDate else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "d MMMM"
        return f.string(from: d)
    }

    private func urgencyColor(_ days: Int) -> Color {
        switch days {
        case ..<3:  return Color(hex: 0xD4111E)   // rouge — critique
        case 3..<7: return Color(hex: 0xE86826)   // orange
        case 7..<14: return Color(hex: 0xC48000)  // ambre
        default:    return Color(hex: 0x757575)   // neutre
        }
    }
}
