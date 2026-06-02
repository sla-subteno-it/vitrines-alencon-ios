// MonCompteView.swift
// Vitrines d'Alençon — iOS
// Onglet Mon Compte : solde de points, raccourcis, profil, déconnexion.
// Réplique de /mon-compte.

import SwiftUI
import Combine

// MARK: - ViewModel

@MainActor
final class MonCompteViewModel: ObservableObject {
    @Published var firstName: String?
    @Published var balance: Double?
    @Published var cardNumber: String?
    @Published var isLoading = false

    private let client = OdooClient.shared

    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let uid = await OdooSession.shared.getUID() else { return }
        do {
            // 1) user → partner_id
            let users: [UserRow] = try await client.call(
                model: "res.users", method: "search_read", args: [],
                kwargs: ["domain": [["id", "=", uid]], "fields": ["partner_id"], "limit": 1]
            )
            guard let partnerId = users.first?.partnerId else { return }

            // 2) partner → first_name, name, carte
            let partners: [PartnerRow] = try await client.call(
                model: "res.partner", method: "search_read", args: [],
                kwargs: ["domain": [["id", "=", partnerId]],
                         "fields": ["first_name", "name", "cardnumber", "local_rewards_card_id"], "limit": 1]
            )
            if let p = partners.first {
                let sessionFirst = (await OdooSession.shared.getUserName())?
                    .split(separator: " ").first.map(String.init)
                firstName = p.firstName?.nilIfEmpty
                    ?? p.name?.split(separator: " ").first.map(String.init)
                    ?? sessionFirst
                cardNumber = p.cardnumber?.nilIfEmpty

                // 3) carte → solde cumulé
                if let cardId = p.cardId {
                    let cards: [CardRow] = try await client.call(
                        model: "local.rewards.card", method: "search_read", args: [],
                        kwargs: ["domain": [["id", "=", cardId]],
                                 "fields": ["total_add_credit_amount"], "limit": 1]
                    )
                    balance = cards.first?.total
                }
            }
        } catch {
            // Solde indisponible : on garde la page (rows statiques) sans bloquer.
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

// MARK: - Lignes de décodage (many2one Odoo = [id, "nom"] ou false)

private struct UserRow: Decodable {
    let partnerId: Int?
    enum CodingKeys: String, CodingKey { case partnerId = "partner_id" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if var m2o = try? c.nestedUnkeyedContainer(forKey: .partnerId) {
            partnerId = try? m2o.decode(Int.self)
        } else { partnerId = nil }
    }
}

private struct PartnerRow: Decodable {
    let firstName: String?
    let name: String?
    let cardnumber: String?
    let cardId: Int?
    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case name, cardnumber
        case cardId = "local_rewards_card_id"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        firstName = try? c.decode(String.self, forKey: .firstName)
        name = try? c.decode(String.self, forKey: .name)
        cardnumber = try? c.decode(String.self, forKey: .cardnumber)
        if var m2o = try? c.nestedUnkeyedContainer(forKey: .cardId) {
            cardId = try? m2o.decode(Int.self)
        } else { cardId = nil }
    }
}

private struct CardRow: Decodable {
    let total: Double?
    enum CodingKeys: String, CodingKey { case total = "total_add_credit_amount" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        total = try? c.decode(Double.self, forKey: .total)
    }
}

// MARK: - Vue

struct MonCompteView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var viewModel = MonCompteViewModel()
    @State private var showCard = false

    /// Permet de basculer vers un autre onglet (ex. Notifications).
    var selectTab: (MainTabView.Tab) -> Void = { _ in }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    NavigationLink { MaCarteView() } label: { balanceCard }
                        .buttonStyle(.plain)
                    Button { showCard = true } label: {
                        AccountRowLabel(icon: "creditcard", title: "Ma carte fidélité")
                    }
                    .buttonStyle(.plain)

                    sectionTitle("Actions rapides")
                    AccountRow(icon: "bell", title: "Notifications") { selectTab(.notifs) }
                    NavigationLink { CarteCadeauView() } label: {
                        AccountRowLabel(icon: "gift", title: "Carte cadeau")
                    }
                    .buttonStyle(.plain)

                    sectionTitle("Mon profil")
                    NavigationLink { PersonalInfoView() } label: {
                        AccountRowLabel(icon: "person", title: "Mes infos personnelles")
                    }
                    .buttonStyle(.plain)
                    NavigationLink { AddressesView() } label: {
                        AccountRowLabel(icon: "mappin.and.ellipse", title: "Mes adresses")
                    }
                    .buttonStyle(.plain)
                    NavigationLink { SecurityView() } label: {
                        AccountRowLabel(icon: "lock", title: "Connexion et sécurité")
                    }
                    .buttonStyle(.plain)

                    sectionTitle("Mes préférences")
                    NavigationLink { CommunicationPreferencesView() } label: {
                        AccountRowLabel(icon: "megaphone", title: "Préférences de communication")
                    }
                    .buttonStyle(.plain)

                    sectionTitle("Besoin d'aide ?")
                    NavigationLink { AideFaqView() } label: {
                        AccountRowLabel(icon: "questionmark.circle", title: "Aide / FAQ")
                    }
                    .buttonStyle(.plain)
                    NavigationLink { ContactView() } label: {
                        AccountRowLabel(icon: "bubble.left.and.bubble.right", title: "Contactez-nous")
                    }
                    .buttonStyle(.plain)

                    logoutButton
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .aboveTabBar()
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .task { await viewModel.load() }
        }
        .fullScreenCover(isPresented: $showCard) {
            CardBackView(cardNumber: viewModel.cardNumber)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Bonjour \(viewModel.firstName ?? "")\(viewModel.firstName == nil ? "" : ",")")
                .font(BrandFont.sans(28, weight: .bold))
                .foregroundStyle(.primary)
            Text("Bienvenue dans votre espace")
                .font(BrandFont.sans(15))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 12)
        .padding(.bottom, 20)
    }

    // MARK: - Carte solde

    private var balanceCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "eurosign.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(Color.brandNavy)
            Text("Mon solde de points")
                .font(BrandFont.sans(16, weight: .semibold))
                .foregroundStyle(.primary)
            Spacer()
            Text(balanceText)
                .font(BrandFont.sans(15, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.brandNavy, in: .rect(cornerRadius: 8))
            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 14))
        .padding(.bottom, 12)
    }

    private var balanceText: String {
        if let b = viewModel.balance {
            return String(format: "%.2f €", b)
        }
        return "—"
    }

    // MARK: - Titre de section

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(BrandFont.sans(20, weight: .bold))
            .foregroundStyle(.primary)
            .padding(.top, 24)
            .padding(.bottom, 4)
    }

    // MARK: - Déconnexion

    private var logoutButton: some View {
        Button {
            Task { await auth.logout() }
        } label: {
            Label("Déconnexion", systemImage: "rectangle.portrait.and.arrow.right")
                .font(BrandFont.sans(16, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .padding(.top, 32)
    }
}

// MARK: - Ligne de menu

struct AccountRowLabel: View {
    let icon: String
    let title: String

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(.primary)
                    .frame(width: 24)
                Text(title)
                    .font(BrandFont.sans(16))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 16)
            Divider()
        }
        .contentShape(Rectangle())
    }
}

private struct AccountRow: View {
    let icon: String
    let title: String
    var action: (() -> Void)? = nil

    var body: some View {
        Button { action?() } label: {
            AccountRowLabel(icon: icon, title: title)
        }
        .buttonStyle(.plain)
    }
}
