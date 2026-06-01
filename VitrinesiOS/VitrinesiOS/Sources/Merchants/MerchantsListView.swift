// MerchantsListView.swift
// Vitrines d'Alençon — iOS
// Annuaire commerçants : header éditorial, recherche + filtres, grille 2 colonnes.
// Réplique de la page PWA www.vitrines-alencon.fr/merchants.

import SwiftUI

struct MerchantsListView: View {
    @StateObject private var viewModel = MerchantsViewModel()
    @State private var showFilters = false
    @State private var showMarques = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    searchAndFilters

                    Group {
                        if viewModel.isLoading && viewModel.merchants.isEmpty {
                            loadingView
                        } else if let error = viewModel.errorMessage, viewModel.merchants.isEmpty {
                            errorView(error)
                        } else if viewModel.merchants.isEmpty {
                            emptyView
                        } else {
                            grid
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(LinearGradient.brandSurface.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Merchant.self) { merchant in
                MerchantDetailView(merchantId: merchant.id, merchantName: merchant.name)
            }
            .navigationDestination(for: MerchantCoupon.self) { coupon in
                CouponDetailView(coupon: coupon)
            }
            .sheet(isPresented: $showFilters) {
                MerchantFilterView(viewModel: viewModel)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showMarques) {
                MarquesView(viewModel: viewModel)
            }
            .onChange(of: viewModel.filters.search) { _, _ in
                viewModel.onSearchChanged()
            }
            .task { await viewModel.loadAll() }
            .refreshable { await viewModel.loadAll() }
        }
    }

    // MARK: - Header éditorial

    private var header: some View {
        Text(titleAttributed)
            .font(BrandFont.serif(26, weight: .bold))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 8)
    }

    private var titleAttributed: AttributedString {
        guard !viewModel.merchants.isEmpty else {
            var s = AttributedString("Nos commerces du centre-ville d'Alençon")
            s.foregroundColor = .brandNavy
            return s
        }
        var prefix = AttributedString("Nos ")
        prefix.foregroundColor = .brandNavy
        var count = AttributedString("\(viewModel.merchants.count)")
        count.foregroundColor = .brandRed
        var suffix = AttributedString(" commerces du centre-ville d'Alençon")
        suffix.foregroundColor = .brandNavy
        return prefix + count + suffix
    }

    // MARK: - Recherche + filtres

    private var searchAndFilters: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.brandTextMuted)
                    TextField("Rechercher un commerçant", text: $viewModel.filters.search)
                        .font(BrandFont.sans(15))
                        .autocorrectionDisabled()
                    if !viewModel.filters.search.isEmpty {
                        Button {
                            viewModel.filters.search = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.brandTextMuted)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(.white, in: .rect(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.brandNavy.opacity(0.08), lineWidth: 1))

                iconToggle(icon: "creditcard.fill",
                           isOn: viewModel.filters.acceptFidelityCard,
                           gradient: .brandNavy) {
                    viewModel.filters.acceptFidelityCard.toggle()
                    Task { await viewModel.applyFilters() }
                }

                iconToggle(icon: "gift.fill",
                           isOn: viewModel.filters.acceptGiftCard,
                           gradient: .brandRed) {
                    viewModel.filters.acceptGiftCard.toggle()
                    Task { await viewModel.applyFilters() }
                }
            }

            HStack(spacing: 8) {
                bigFilterButton(title: "Catégories") { showFilters = true }
                bigFilterButton(title: "Marques") { showMarques = true }
            }

            if !activeChips.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(activeChips, id: \.id) { chip in
                            Button(action: chip.remove) {
                                HStack(spacing: 6) {
                                    Text(chip.label)
                                        .font(BrandFont.sans(13, weight: .medium))
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                .foregroundStyle(Color.brandNavy)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color.brandNavy.opacity(0.08), in: .capsule)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    // Filtres actifs affichés en chips retirables (comme la PWA).
    private var activeChips: [(id: String, label: String, remove: () -> Void)] {
        var chips: [(id: String, label: String, remove: () -> Void)] = []
        if let tagId = viewModel.filters.tagId,
           let tag = viewModel.allTags.first(where: { $0.id == tagId }) {
            chips.append(("tag", tag.name, { viewModel.selectTag(nil) }))
        }
        for refId in viewModel.filters.referenceIds {
            let name = viewModel.allReferences.first { $0.id == refId }?.name ?? "Marque"
            chips.append(("ref\(refId)", name, { viewModel.toggleReference(refId) }))
        }
        for tagId in viewModel.filters.referenceTagIds {
            let name = viewModel.allReferenceTags.first { $0.id == tagId }?.name ?? "Univers"
            chips.append(("rt\(tagId)", name, { viewModel.toggleReferenceTag(tagId) }))
        }
        if viewModel.filters.acceptFidelityCard {
            chips.append(("fid", "Carte fidélité", {
                viewModel.filters.acceptFidelityCard = false; viewModel.applyFilters()
            }))
        }
        if viewModel.filters.acceptGiftCard {
            chips.append(("gift", "Carte cadeau", {
                viewModel.filters.acceptGiftCard = false; viewModel.applyFilters()
            }))
        }
        return chips
    }

    private func iconToggle(icon: String, isOn: Bool, gradient: LinearGradient,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isOn ? .white : Color.brandNavy)
                .frame(width: 46, height: 46)
                .background {
                    if isOn {
                        gradient
                    } else {
                        Color.white
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.brandNavy.opacity(0.08), lineWidth: 1))
        }
    }

    private func bigFilterButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(BrandFont.serif(18, weight: .bold))
                .foregroundStyle(Color.brandNavy)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.white, in: .rect(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.brandNavy.opacity(0.08), lineWidth: 1))
        }
    }

    // MARK: - Grille

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(viewModel.merchants) { merchant in
                NavigationLink(value: merchant) {
                    MerchantCardView(merchant: merchant,
                                     brandNames: viewModel.brandNames(for: merchant))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - États

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Chargement des commerçants…")
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
            Button("Réessayer") {
                Task { await viewModel.loadAll() }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.brandNavy)
        }
        .padding(.top, 60)
    }

    private var emptyView: some View {
        ContentUnavailableView.search(text: viewModel.filters.search)
            .padding(.top, 60)
    }
}
