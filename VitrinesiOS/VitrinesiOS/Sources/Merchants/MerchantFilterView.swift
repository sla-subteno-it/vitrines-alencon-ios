// MerchantFilterView.swift
// Vitrines d'Alençon — iOS
// Sheet de filtres : tags catégorie, carte cadeau, carte fidélité

import SwiftUI

struct MerchantFilterView: View {
    @ObservedObject var viewModel: MerchantsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                cardsSection
                if !viewModel.allTags.isEmpty {
                    tagsSection
                }
            }
            .navigationTitle("Filtres")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Réinitialiser") {
                        viewModel.clearFilters()
                        dismiss()
                    }
                    .disabled(viewModel.filters.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Appliquer") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Sections

    private var cardsSection: some View {
        Section("Type de carte acceptée") {
            Toggle(isOn: $viewModel.filters.acceptFidelityCard) {
                Label {
                    Text("Carte Fidélité")
                } icon: {
                    Image(systemName: "creditcard")
                        .foregroundStyle(.blue)
                }
            }
            .onChange(of: viewModel.filters.acceptFidelityCard) { _, _ in
                Task { await viewModel.applyFilters() }
            }

            Toggle(isOn: $viewModel.filters.acceptGiftCard) {
                Label {
                    Text("Carte Cadeau")
                } icon: {
                    Image(systemName: "gift")
                        .foregroundStyle(.orange)
                }
            }
            .onChange(of: viewModel.filters.acceptGiftCard) { _, _ in
                Task { await viewModel.applyFilters() }
            }
        }
    }

    private var tagsSection: some View {
        Section("Catégorie") {
            ForEach(viewModel.allTags) { tag in
                Button {
                    viewModel.selectTag(viewModel.filters.tagId == tag.id ? nil : tag)
                } label: {
                    HStack {
                        Text(tag.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        if viewModel.filters.tagId == tag.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
    }
}
