// MarquesView.swift
// Vitrines d'Alençon — iOS
// Navigation des enseignes (merchant.reference) par univers + index A-Z.
// Réplique de la vue « Marques » / « Les Univers » de la PWA.

import SwiftUI

struct MarquesView: View {
    @ObservedObject var viewModel: MerchantsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedUniverse: Int?

    private var sections: [(letter: String, references: [MerchantReference])] {
        guard let u = selectedUniverse else { return viewModel.brandSections }
        return viewModel.brandSections.compactMap { sec in
            let refs = sec.references.filter { $0.referenceTagIds.contains(u) }
            return refs.isEmpty ? nil : (sec.letter, refs)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ZStack(alignment: .trailing) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            universesBar
                            ForEach(sections, id: \.letter) { section in
                                sectionView(section)
                                    .id(section.letter)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                    alphabetIndex(proxy: proxy)
                }
                .background(Color(.systemBackground))
                .navigationTitle("Marques")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Fermer") { dismiss() }
                    }
                }
            }
        }
    }

    // MARK: - Les Univers (reference tags)

    private var universesBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Les Univers")
                .font(BrandFont.serif(20, weight: .bold))
                .foregroundStyle(Color.brandNavy)
                .frame(maxWidth: .infinity, alignment: .center)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    universeChip(label: "Tous", id: nil)
                    ForEach(viewModel.allReferenceTags) { tag in
                        universeChip(label: tag.name, id: tag.id)
                    }
                }
                .padding(.bottom, 2)
            }
            Divider()
        }
        .padding(.top, 8)
    }

    private func universeChip(label: String, id: Int?) -> some View {
        let isSel = selectedUniverse == id
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedUniverse = id }
        } label: {
            VStack(spacing: 6) {
                Text(label)
                    .font(BrandFont.serif(16, weight: isSel ? .bold : .regular))
                    .foregroundStyle(isSel ? Color.brandNavy : Color.brandTextMuted)
                Rectangle().fill(isSel ? Color.brandNavy : .clear).frame(height: 2)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section alphabétique

    private func sectionView(_ section: (letter: String, references: [MerchantReference])) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(section.letter)
                .font(BrandFont.serif(22, weight: .bold))
                .foregroundStyle(Color.brandNavy)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .background(Color.brandSurface2.opacity(0.5))

            ForEach(section.references) { ref in
                Button {
                    viewModel.toggleReference(ref.id)
                    dismiss()
                } label: {
                    HStack {
                        Text(ref.name)
                            .font(BrandFont.sans(16))
                            .foregroundStyle(Color.brandNavy)
                        Spacer()
                        Text("\(viewModel.merchantCount(forReference: ref.id))")
                            .font(BrandFont.sans(12, weight: .semibold))
                            .foregroundStyle(Color.brandNavy)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.brandSurface2, in: .capsule)
                    }
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Divider()
            }
        }
    }

    // MARK: - Index A-Z

    private func alphabetIndex(proxy: ScrollViewProxy) -> some View {
        let letters = sections.map { $0.letter }
        return VStack(spacing: 0) {
            ForEach(letters, id: \.self) { letter in
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(letter, anchor: .top)
                    }
                } label: {
                    Text(letter)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.brandNavy)
                        .frame(width: 24, height: 17)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.trailing, 2)
    }
}
