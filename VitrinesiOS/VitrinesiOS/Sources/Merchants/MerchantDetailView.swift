// MerchantDetailView.swift
// Vitrines d'Alençon — iOS
// Fiche détail brandée PWA : hero, présentation, références, coordonnées, avis.

import SwiftUI

struct MerchantDetailView: View {
    let merchantId: Int
    let merchantName: String

    @StateObject private var viewModel: MerchantDetailViewModel
    @State private var showReviewForm = false
    @State private var selectedTab: DetailTab = .about
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    init(merchantId: Int, merchantName: String) {
        self.merchantId = merchantId
        self.merchantName = merchantName
        _viewModel = StateObject(wrappedValue: MerchantDetailViewModel(merchantId: merchantId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.merchant == nil {
                ProgressView("Chargement…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let merchant = viewModel.merchant {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        heroImage(merchant: merchant)
                        detailContent(merchant: merchant)
                    }
                }
                .aboveTabBar()
                .background(LinearGradient.brandSurface.ignoresSafeArea())
            } else if let error = viewModel.errorMessage {
                ContentUnavailableView {
                    Label("Erreur", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Réessayer") { Task { await viewModel.load() } }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.brandNavy)
                }
            } else {
                ProgressView("Chargement…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(merchantName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { favoriteButton }
        .task { await viewModel.load() }
        .sheet(isPresented: $showReviewForm) {
            ReviewFormView(viewModel: viewModel)
                .presentationDetents([.medium])
        }
        .overlay(alignment: .bottom) {
            if let success = viewModel.successMessage {
                Text(success)
                    .font(BrandFont.sans(14, weight: .medium))
                    .padding()
                    .background(Color.brandGreen, in: .rect(cornerRadius: 10))
                    .foregroundStyle(.white)
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            viewModel.successMessage = nil
                        }
                    }
            }
        }
        .animation(.easeInOut, value: viewModel.successMessage)
    }

    // MARK: - Hero image

    private func heroImage(merchant: Merchant) -> some View {
        Group {
            if let url = merchant.imageURL {
                RemoteImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        heroPlaceholder
                    }
                }
            } else {
                heroPlaceholder
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 240)
        .clipped()
    }

    private var heroPlaceholder: some View {
        ZStack {
            LinearGradient.brandSurface
            Image(systemName: "storefront")
                .font(.system(size: 60))
                .foregroundStyle(Color.brandNavy.opacity(0.4))
        }
    }

    // MARK: - Contenu principal

    @ViewBuilder
    private func detailContent(merchant: Merchant) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            headerSection(merchant: merchant)
            tabBar

            switch selectedTab {
            case .about:   aboutTab(merchant: merchant)
            case .contact: contactSection(merchant: merchant)
            case .deals:   dealsTab
            case .reviews: reviewsSection
            }
        }
        .padding(16)
    }

    private var availableTabs: [DetailTab] {
        var tabs: [DetailTab] = [.about, .contact]
        if !viewModel.coupons.isEmpty { tabs.append(.deals) }
        tabs.append(.reviews)
        return tabs
    }

    // MARK: - Onglet « À propos »

    @ViewBuilder
    private func aboutTab(merchant: Merchant) -> some View {
        if let presentation = presentationText(merchant) {
            SectionCard {
                BrandSectionHeader(title: "Présentation", icon: "text.alignleft")
                Text(presentation)
                    .font(BrandFont.sans(14))
                    .foregroundStyle(Color.brandTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        programBanners(merchant: merchant)
        if !viewModel.brandNames.isEmpty {
            referencesSection
        }
    }

    // MARK: - Barre d'onglets (3 onglets, façon PWA)

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(availableTabs) { tab in
                let selected = selectedTab == tab
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 15, weight: .semibold))
                        Text(tab.label(reviewCount: viewModel.reviews.count, dealCount: viewModel.coupons.count))
                            .font(BrandFont.serif(15, weight: selected ? .bold : .regular))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(selected ? Color.brandNavy : Color.brandTextMuted)
                    .background(selected ? Color.white : Color.clear)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(selected ? Color.brandNavy : Color.clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.brandSurface2.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandNavy.opacity(0.08), lineWidth: 1))
    }

    /// Format français : +33 / 0033 → 0, puis groupes de 2 chiffres (06 18 02 18 09).
    static func formatFRPhone(_ raw: String) -> String {
        var s = raw.filter { $0.isNumber || $0 == "+" }
        if s.hasPrefix("+33") { s = "0" + s.dropFirst(3) }
        else if s.hasPrefix("0033") { s = "0" + s.dropFirst(4) }
        let digits = Array(s.filter { $0.isNumber })
        guard digits.count == 10 else { return raw.trimmingCharacters(in: .whitespaces) }
        return stride(from: 0, to: 10, by: 2)
            .map { String(digits[$0]) + String(digits[$0 + 1]) }
            .joined(separator: " ")
    }

    private func presentationText(_ merchant: Merchant) -> String? {
        // La PWA affiche company_brief en priorité (cf. templates.xml « Présentation »).
        [merchant.companyBrief, merchant.salesDescr, merchant.shortSalesDescr]
            .compactMap { $0 }
            .first { !$0.isEmpty }
    }

    // MARK: - Bandeaux programme / cartes cadeaux

    @ViewBuilder
    private func programBanners(merchant: Merchant) -> some View {
        if merchant.acceptFidelityCard {
            ProgramBanner(
                icon: "creditcard.fill",
                tint: .brandNavy,
                title: "Ce commerce participe au programme Les Vitrines d'Alençon",
                subtitle: "Profitez de votre carte fidélité pour cumuler des avantages lors de vos achats."
            )
        }
        if merchant.acceptGiftCard {
            ProgramBanner(
                icon: "gift.fill",
                tint: .brandRed,
                title: "Ce commerce accepte les cartes cadeaux",
                subtitle: "Utilisez vos cartes cadeaux Les Vitrines d'Alençon pour régler vos achats."
            )
        }
    }

    // MARK: - En-tête

    private func headerSection(merchant: Merchant) -> some View {
        SectionCard {
            HStack(alignment: .top, spacing: 12) {
                Text(merchant.name)
                    .font(BrandFont.serif(24, weight: .bold))
                    .foregroundStyle(Color.brandNavy)
                Spacer(minLength: 0)
                if let category = viewModel.categoryNames.first {
                    HStack(spacing: 4) {
                        Image(systemName: "tag.fill")
                            .font(.system(size: 10))
                        Text(category)
                            .font(BrandFont.sans(12, weight: .semibold))
                    }
                    .foregroundStyle(Color.brandTextMuted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.brandSurface2, in: .capsule)
                }
            }

            if viewModel.averageRating > 0 {
                HStack(spacing: 6) {
                    StarRatingView(rating: viewModel.averageRating, size: 15)
                    Text(String(format: "%.1f", viewModel.averageRating))
                        .font(BrandFont.sans(14, weight: .semibold))
                        .foregroundStyle(Color.brandNavy)
                    Text("(\(viewModel.reviews.count) avis)")
                        .font(BrandFont.sans(12))
                        .foregroundStyle(Color.brandTextMuted)
                }
            }
        }
    }

    // MARK: - Coupons / Bons Plans

    private var dealsTab: some View {
        SectionCard {
            BrandSectionHeader(title: "Bons Plans", icon: "tag.fill", iconTint: .brandRed)
            ForEach(Array(viewModel.coupons.enumerated()), id: \.element.id) { index, coupon in
                NavigationLink(value: coupon) {
                    CouponRowView(coupon: coupon)
                }
                .buttonStyle(.plain)
                if index < viewModel.coupons.count - 1 {
                    Rectangle().fill(Color.brandHairline).frame(height: 1)
                }
            }
            // "Voir tous les bons plans" → cible l'onglet Bons Plans global (à venir)
            Button {
                // TODO: basculer vers l'onglet Bons Plans une fois implémenté
            } label: {
                Text("Voir tous les bons plans")
                    .font(BrandFont.sans(14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .foregroundStyle(Color.brandRed)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.brandRed, lineWidth: 1))
            .padding(.top, 4)
        }
    }

    // MARK: - Références proposées

    private var referencesSection: some View {
        SectionCard {
            HStack {
                BrandSectionHeader(title: "Références proposées", icon: "bag.fill")
                Spacer()
                Text("\(viewModel.brandNames.count)")
                    .font(BrandFont.sans(12, weight: .bold))
                    .foregroundStyle(Color.brandNavy)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.brandSurface2, in: .capsule)
            }
            FlowLayout(spacing: 6) {
                ForEach(viewModel.brandNames, id: \.self) { name in
                    Text(name.uppercased())
                        .font(BrandFont.sans(11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(LinearGradient.brandNavy, in: .rect(cornerRadius: 6))
                }
            }
        }
    }

    // MARK: - Coordonnées

    private func contactSection(merchant: Merchant) -> some View {
        SectionCard(spacing: 0) {
            BrandSectionHeader(title: "Coordonnées", icon: "mappin.and.ellipse")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)

            let items = contactItems(merchant)
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                ContactRow(item: item)
                if index < items.count - 1 {
                    Rectangle().fill(Color.black.opacity(0.06)).frame(height: 1)
                }
            }
        }
    }

    private func contactItems(_ merchant: Merchant) -> [ContactItem] {
        var items: [ContactItem] = []
        if let street = merchant.street, !street.isEmpty {
            let city = [merchant.zip, merchant.city]
                .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
            items.append(ContactItem(icon: "mappin", primary: street,
                                     secondary: city.isEmpty ? "Voir sur la carte" : city) {
                let q = (merchant.formattedAddress ?? street)
                    .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                if let url = URL(string: "maps://?q=\(q)") { openURL(url) }
            })
        }
        if let phone = merchant.phone, !phone.isEmpty {
            let display = Self.formatFRPhone(phone)
            let dial = display.filter { $0.isNumber }
            items.append(ContactItem(icon: "phone.fill", primary: display, secondary: "Appeler") {
                if let url = URL(string: "tel:\(dial)") { openURL(url) }
            })
        }
        if let website = merchant.website, !website.isEmpty {
            let display = website
                .replacingOccurrences(of: "https://", with: "")
                .replacingOccurrences(of: "http://", with: "")
            items.append(ContactItem(icon: "globe", primary: display, secondary: "Visiter le site") {
                if let url = URL(string: website.hasPrefix("http") ? website : "https://\(website)") { openURL(url) }
            })
        }
        if let email = merchant.email, !email.isEmpty {
            items.append(ContactItem(icon: "envelope.fill", primary: email, secondary: "Envoyer un email") {
                if let url = URL(string: "mailto:\(email)") { openURL(url) }
            })
        }
        if let hours = merchant.openingHours, !hours.isEmpty {
            items.append(ContactItem(icon: "clock", primary: "Horaires", secondary: hours, action: nil))
        }
        return items
    }

    // MARK: - Avis

    private var reviewsSection: some View {
        SectionCard {
            HStack {
                BrandSectionHeader(title: "Avis clients", icon: "star.fill")
                Spacer()
                Button("Laisser un avis") { showReviewForm = true }
                    .font(BrandFont.sans(13, weight: .semibold))
                    .foregroundStyle(Color.brandRed)
            }

            if viewModel.reviews.isEmpty {
                Text("Aucun avis pour le moment.")
                    .font(BrandFont.sans(14))
                    .foregroundStyle(Color.brandTextMuted)
            } else {
                ForEach(Array(viewModel.reviews.prefix(5).enumerated()), id: \.element.id) { index, review in
                    ReviewRowView(review: review)
                    if index < min(5, viewModel.reviews.count) - 1 {
                        Divider().background(Color.brandHairline)
                    }
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var favoriteButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Task { await viewModel.toggleFavorite() }
            } label: {
                Image(systemName: viewModel.isFavorite ? "heart.fill" : "heart")
                    .foregroundStyle(viewModel.isFavorite ? Color.brandRed : Color.brandNavy)
            }
            .accessibilityLabel(viewModel.isFavorite ? "Retirer des favoris" : "Ajouter aux favoris")
        }
    }
}

// MARK: - Onglets de la fiche détail

private enum DetailTab: Int, Identifiable {
    case about, contact, deals, reviews
    var id: Int { rawValue }

    var icon: String {
        switch self {
        case .about:   return "info.circle.fill"
        case .contact: return "mappin.circle.fill"
        case .deals:   return "tag.fill"
        case .reviews: return "star.fill"
        }
    }

    func label(reviewCount: Int, dealCount: Int) -> String {
        switch self {
        case .about:   return "À propos"
        case .contact: return "Coordonnées"
        case .deals:   return "Bons Plans (\(dealCount))"
        case .reviews: return "Avis (\(reviewCount))"
        }
    }
}

// MARK: - Conteneur "carte" de section (façon PWA)

private struct SectionCard<Content: View>: View {
    var spacing: CGFloat = 10
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandNavy.opacity(0.06), lineWidth: 1))
        .shadow(color: Color.brandNavy.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}

private struct BrandSectionHeader: View {
    let title: String
    let icon: String
    var iconTint: Color = .brandTextMuted

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(iconTint)
            Text(title.uppercased())
                .font(BrandFont.sans(12, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Color.brandTextMuted)
        }
    }
}

// MARK: - Bandeau programme / cartes cadeaux

private struct ProgramBanner: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(BrandFont.serif(16, weight: .bold))
                    .foregroundStyle(tint)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(BrandFont.sans(13))
                    .foregroundStyle(Color.brandTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(tint.opacity(0.1), in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(tint.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Ligne contact (icône navy simple + 2 lignes, comme la PWA)

private struct ContactItem {
    let icon: String
    let primary: String
    let secondary: String
    var action: (() -> Void)? = nil
}

private struct ContactRow: View {
    let item: ContactItem

    var body: some View {
        Button {
            item.action?()
        } label: {
            HStack(alignment: item.action == nil ? .top : .center, spacing: 14) {
                Image(systemName: item.icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.brandNavy)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.primary)
                        .font(BrandFont.sans(15, weight: .medium))
                        .foregroundStyle(Color.brandNavy)
                    Text(item.secondary)
                        .font(BrandFont.sans(12))
                        .foregroundStyle(Color.brandTextMuted)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if item.action != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Color.brandTextMuted)
                }
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .disabled(item.action == nil)
    }
}

// MARK: - Coupon

private struct CouponRowView: View {
    let coupon: MerchantCoupon

    private var formattedExpiry: String? {
        guard let raw = coupon.dateValidUntil, !raw.isEmpty else { return nil }
        let datePart = raw.split(separator: " ").first.map(String.init) ?? raw
        let parts = datePart.split(separator: "-")
        if parts.count == 3 { return "\(parts[2])/\(parts[1])/\(parts[0])" }
        return raw
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(coupon.name)
                    .font(BrandFont.serif(17, weight: .bold))
                    .foregroundStyle(Color.brandNavy)
                if let desc = coupon.shortTextContent?.htmlStripped, !desc.isEmpty {
                    Text(desc)
                        .font(BrandFont.sans(14))
                        .foregroundStyle(Color.brandNavy.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let formattedExpiry {
                    HStack(spacing: 5) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text("Jusqu'au \(formattedExpiry)")
                            .font(BrandFont.sans(12))
                    }
                    .foregroundStyle(Color.brandTextMuted)
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.brandTextMuted)
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Avis

private struct ReviewRowView: View {
    let review: MerchantReview

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(review.displayName)
                    .font(BrandFont.sans(14, weight: .semibold))
                    .foregroundStyle(Color.brandNavy)
                Spacer()
                StarRatingView(rating: review.rating, size: 12)
            }
            if !review.comment.isEmpty {
                Text(review.comment)
                    .font(BrandFont.sans(13))
                    .foregroundStyle(Color.brandTextMuted)
            }
            Text(review.date)
                .font(BrandFont.sans(11))
                .foregroundStyle(Color.brandTextMuted.opacity(0.7))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Étoiles (rouge plein / ambre partiel, comme la PWA)

struct StarRatingView: View {
    let rating: Double
    let size: CGFloat

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: starName(for: index))
                    .font(.system(size: size))
                    .foregroundStyle(color(for: index))
            }
        }
    }

    private func starName(for index: Int) -> String {
        let value = rating - Double(index - 1)
        if value >= 1 { return "star.fill" }
        if value >= 0.5 { return "star.leadinghalf.filled" }
        return "star"
    }

    private func color(for index: Int) -> Color {
        let value = rating - Double(index - 1)
        if value >= 1 { return .brandRed }
        if value >= 0.5 { return Color(hex: 0xFFC107) }   // ambre (étoile partielle PWA)
        return Color(hex: 0xDEE2E6)                        // vide
    }
}

// MARK: - Formulaire d'avis

private struct ReviewFormView: View {
    @ObservedObject var viewModel: MerchantDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var rating = 4
    @State private var comment = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Note") {
                    HStack(spacing: 12) {
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                rating = star
                            } label: {
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .font(.title)
                                    .foregroundStyle(Color.brandRed)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Commentaire") {
                    TextField("Partagez votre expérience…", text: $comment, axis: .vertical)
                        .lineLimit(4...8)
                }
            }
            .navigationTitle("Laisser un avis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Envoyer") {
                        Task {
                            await viewModel.submitReview(rating: rating, comment: comment)
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(comment.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
