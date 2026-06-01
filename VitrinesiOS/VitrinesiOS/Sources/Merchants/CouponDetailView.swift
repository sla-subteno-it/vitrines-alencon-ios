// CouponDetailView.swift
// Vitrines d'Alençon — iOS
// Fiche détail d'un bon plan (local.rewards.offer), réplique de /bons-plans/<id>.

import SwiftUI

struct CouponDetailView: View {
    let coupon: MerchantCoupon

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                heroImage
                contentCard
                if let until = validUntilDate {
                    CountdownCard(until: until)
                }
            }
            .padding(.bottom, 24)
        }
        .background(LinearGradient.brandSurface.ignoresSafeArea())
        .navigationTitle("Bon plan")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero

    private var heroImage: some View {
        ZStack {
            Color.brandSurface2
            if let url = coupon.imageURL {
                RemoteImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFit()
                    case .empty:              ProgressView()
                    default:                  placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(height: 300)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var placeholder: some View {
        Image(systemName: "gift.fill")
            .font(.system(size: 56))
            .foregroundStyle(Color.brandNavy.opacity(0.4))
    }

    // MARK: - Contenu

    private var contentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let unit = coupon.couponUnit, !unit.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "tag.fill").font(.system(size: 10))
                    Text(unit.capitalized)
                        .font(BrandFont.sans(12, weight: .semibold))
                }
                .foregroundStyle(Color.brandNavy)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.brandNavy.opacity(0.1), in: .capsule)
            }

            Text(coupon.name)
                .font(BrandFont.serif(26, weight: .bold))
                .foregroundStyle(Color.brandNavy)

            if let desc = coupon.shortTextContent?.htmlStripped, !desc.isEmpty {
                Text(desc)
                    .font(BrandFont.sans(15))
                    .foregroundStyle(Color.brandTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let merchantName = coupon.merchantName {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "storefront.fill")
                        Text(merchantName)
                            .font(BrandFont.serif(17, weight: .bold))
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.right")
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(LinearGradient.brandNavy, in: .rect(cornerRadius: 12))
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandNavy.opacity(0.06), lineWidth: 1))
        .shadow(color: Color.brandNavy.opacity(0.06), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 16)
    }

    // MARK: - Date de validité

    private var validUntilDate: Date? {
        guard let raw = coupon.dateValidUntil, !raw.isEmpty else { return nil }
        return CouponDetailView.parseOdooDate(raw)
    }

    static func parseOdooDate(_ raw: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"] {
            f.dateFormat = format
            if let d = f.date(from: raw) { return d }
        }
        return nil
    }
}

// MARK: - Compte à rebours « TEMPS RESTANT »

private struct CountdownCard: View {
    let until: Date

    private var longDate: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateStyle = .long
        f.timeStyle = .none
        return f.string(from: until)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, until.timeIntervalSince(context.date))
            let days = Int(remaining) / 86400
            let hours = (Int(remaining) % 86400) / 3600
            let minutes = (Int(remaining) % 3600) / 60
            let seconds = Int(remaining) % 60

            VStack(spacing: 16) {
                Text("TEMPS RESTANT")
                    .font(BrandFont.serif(20, weight: .bold))
                    .tracking(1)

                HStack(spacing: 8) {
                    cell(days, "Jours")
                    cell(hours, "Heures")
                    cell(minutes, "Minutes")
                    cell(seconds, "Secondes")
                }

                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                    Text("Valable jusqu'au \(longDate)")
                        .font(BrandFont.sans(14))
                }
                .foregroundStyle(.white.opacity(0.9))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(
                LinearGradient(colors: [.brandNavy, Color(hex: 0x4A7A94)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: .rect(cornerRadius: 16)
            )
            .padding(.horizontal, 16)
        }
    }

    private func cell(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(BrandFont.serif(34, weight: .bold))
                .monospacedDigit()
            Text(label)
                .font(BrandFont.sans(12))
                .opacity(0.9)
        }
        .frame(maxWidth: .infinity)
    }
}
