// MerchantCardView.swift
// Vitrines d'Alençon — iOS
// Carte commerçant façon grille (réplique de la PWA www.vitrines-alencon.fr/merchants).

import SwiftUI

struct MerchantCardView: View {
    let merchant: Merchant
    /// Noms des marques/enseignes du commerçant (résolus depuis allReferences).
    var brandNames: [String] = []

    private var description: String? {
        let d = merchant.companyBrief ?? merchant.shortSalesDescr ?? merchant.salesDescr
        guard let d, !d.isEmpty else { return nil }
        return d
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            imageHeader
            body(spacing: 8)
            footer
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.brandNavy.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.brandNavy.opacity(0.08), radius: 6, x: 0, y: 2)
    }

    // MARK: - Image + badges d'angle

    private var imageHeader: some View {
        Color.clear
            .aspectRatio(4.0 / 3.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay { MerchantThumbnail(merchant: merchant) }
            .clipped()
            .overlay(alignment: .topTrailing) {
                VStack(alignment: .trailing, spacing: 6) {
                    if merchant.acceptFidelityCard {
                        CornerBadge(icon: "creditcard.fill", gradient: .brandNavy,
                                    shadow: Color.brandNavy.opacity(0.4))
                    }
                    if merchant.acceptGiftCard {
                        CornerBadge(icon: "gift.fill", gradient: .brandRed,
                                    shadow: Color.brandRed.opacity(0.4))
                    }
                }
                .padding(12)
            }
    }

    // MARK: - Corps

    private func body(spacing: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            Text(merchant.name)
                .font(BrandFont.serif(18, weight: .bold))
                .foregroundStyle(Color.brandNavy)
                .lineLimit(2)

            if let description {
                Text(description)
                    .font(BrandFont.sans(13))
                    .foregroundStyle(Color.brandTextMuted)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !brandNames.isEmpty {
                brandPills
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
    }

    private var brandPills: some View {
        let shown = Array(brandNames.prefix(3))
        let extra = brandNames.count - shown.count
        return FlowLayout(spacing: 6) {
            ForEach(shown, id: \.self) { name in
                Text(name.uppercased())
                    .font(BrandFont.sans(10, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(LinearGradient.brandNavy, in: .rect(cornerRadius: 6))
            }
            if extra > 0 {
                Text("+\(extra)")
                    .font(BrandFont.sans(10, weight: .bold))
                    .foregroundStyle(Color.brandNavy)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.brandSurface2, in: .rect(cornerRadius: 6))
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text("Découvrir")
                .font(BrandFont.sans(12, weight: .semibold))
            Spacer()
            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(Color.brandNavy)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.brandFooter)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.brandHairline).frame(height: 1)
        }
    }
}

// MARK: - Badge d'angle

private struct CornerBadge: View {
    let icon: String
    let gradient: LinearGradient
    let shadow: Color

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(7)
            .background(gradient, in: .circle)
            .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
            .shadow(color: shadow, radius: 5, x: 0, y: 3)
    }
}

// MARK: - Vignette

private struct MerchantThumbnail: View {
    let merchant: Merchant

    var body: some View {
        Group {
            if let url = merchant.imageURL {
                RemoteImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        PlaceholderIcon()
                    case .empty:
                        ZStack {
                            LinearGradient.brandSurface
                            ProgressView()
                        }
                    }
                }
            } else {
                PlaceholderIcon()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PlaceholderIcon: View {
    var body: some View {
        ZStack {
            LinearGradient.brandSurface
            Image(systemName: "storefront")
                .font(.largeTitle)
                .foregroundStyle(Color.brandNavy.opacity(0.4))
        }
    }
}

// MARK: - Badge texte (utilisé par la fiche détail)

struct CardBadge: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(BrandFont.sans(11, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - Layout en flux (pills qui passent à la ligne)

/// Petit FlowLayout maison (pas de dépendance tierce).
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows: [CGFloat] = [0]
        var rowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rows.append(0)
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth == .infinity ? rowWidth : maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading,
                          proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
