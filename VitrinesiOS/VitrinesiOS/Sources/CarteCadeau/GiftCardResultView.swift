// GiftCardResultView.swift
// Vitrines d'Alençon — iOS
// Résultat d'un scan : solde + historique des transactions.

import SwiftUI

struct GiftCardResultView: View {
    let info: GiftCardInfo
    let events: [GiftCardEvent]
    let linked: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if linked {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Cette carte cadeau a été associée à votre compte fidélité.")
                            .font(.subheadline)
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.green.opacity(0.12), in: .rect(cornerRadius: 12))
                }

                balanceCard
                historyCard
            }
            .padding(20)
        }
        .background(Color.brandSurface.ignoresSafeArea())
        .navigationTitle("Carte cadeau")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Fermer") { dismiss() }
            }
        }
    }

    private var balanceCard: some View {
        VStack(spacing: 8) {
            StatusBadge(
                label: info.statusLabel,
                isActive: !info.isExpired && info.status == "ACTIVE"
            )
            Text(GiftCardFormat.euros(info.credit))
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(Color.brandRed)
            Text("Solde disponible")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Label(info.cardnumber, systemImage: "creditcard")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            if let date = GiftCardFormat.frenchDate(info.endDate) {
                Text("Valide jusqu'au \(date)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("Historique des transactions", systemImage: "clock.arrow.circlepath")
                .font(.headline)
                .padding(16)

            Divider()

            if events.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("Aucune transaction")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            } else {
                ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                    GiftCardEventRow(event: event)
                    if index < events.count - 1 { Divider().padding(.leading, 66) }
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }
}

private struct GiftCardEventRow: View {
    let event: GiftCardEvent

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill((event.isCredit ? Color.brandRed : Color.red).opacity(0.14))
                    .frame(width: 40, height: 40)
                Image(systemName: event.isCredit ? "arrow.down.left" : "arrow.up.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(event.isCredit ? Color.brandRed : Color.red)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                if let date = GiftCardFormat.frenchDate(event.date) {
                    Text(date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let amount = event.amount {
                Text(GiftCardFormat.signedEuros(amount))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(event.isCredit ? Color.brandRed : Color.red)
            }
        }
        .padding(16)
    }

    private var title: String {
        if let m = event.merchant?.nilIfFalseEmpty { return m }
        if let c = event.comment?.nilIfFalseEmpty { return c }
        return event.isCredit ? "Rechargement" : "Achat"
    }
}
