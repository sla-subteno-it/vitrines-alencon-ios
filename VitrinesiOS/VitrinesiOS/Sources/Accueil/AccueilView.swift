// AccueilView.swift
// Vitrines d'Alençon — iOS
// Onglet Accueil : tableau de bord, réplique de /mobile-menu (connecté).

import SwiftUI
import Combine

// MARK: - Lignes de décodage

private struct URow: Decodable {
    let pid: Int?
    enum CodingKeys: String, CodingKey { case pid = "partner_id" }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        if var m = try? c.nestedUnkeyedContainer(forKey: .pid) { pid = try? m.decode(Int.self) } else { pid = nil }
    }
}
private struct PRow: Decodable {
    let firstName: String?, name: String?, cardId: Int?
    enum CodingKeys: String, CodingKey { case firstName = "first_name"; case name; case cardId = "local_rewards_card_id" }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        firstName = try? c.decode(String.self, forKey: .firstName)
        name = try? c.decode(String.self, forKey: .name)
        if var m = try? c.nestedUnkeyedContainer(forKey: .cardId) { cardId = try? m.decode(Int.self) } else { cardId = nil }
    }
}
private struct CRow: Decodable { let total: Double?
    enum CodingKeys: String, CodingKey { case total = "total_add_credit_amount" }
}

// MARK: - ViewModel

@MainActor
final class AccueilViewModel: ObservableObject {
    @Published var firstName: String?
    @Published var balance: Double?
    @Published var commerceCount = 0
    @Published var fidelityCount = 0
    @Published var giftCount = 0
    @Published var offers: [MerchantCoupon] = []
    @Published var news: [BlogPost] = []
    @Published var merchants: [Merchant] = []

    private let service = MerchantService.shared
    private let client = OdooClient.shared

    func load() async {
        async let merchantsR = try? service.fetchMerchants(order: "create_date desc, id desc")
        async let offersR = try? service.fetchAllActiveOffers()
        async let newsR = fetchNews()
        let (m, o, n) = await (merchantsR, offersR, newsR)

        let visible = m ?? []
        merchants = visible
        commerceCount = visible.count
        fidelityCount = visible.filter { $0.acceptFidelityCard }.count
        giftCount = visible.filter { $0.acceptGiftCard }.count
        offers = (o ?? []).filter { $0.hasEndDate }   // EN CE MOMENT = offres datées
        news = n

        await loadAccount()
    }

    private func fetchNews() async -> [BlogPost] {
        (try? await client.call(
            model: "blog.post", method: "search_read", args: [],
            kwargs: ["domain": [["website_published", "=", true]],
                     "fields": ["name", "subtitle", "teaser", "post_date",
                                "author_id", "blog_id", "cover_properties"],
                     "order": "post_date desc", "limit": 6]
        )) ?? []
    }

    private func loadAccount() async {
        // Affichage immédiat depuis le cache (instantané / hors-ligne).
        if balance == nil { balance = LoyaltyCardStore.balance }

        guard let uid = await OdooSession.shared.getUID() else { return }
        guard let users: [URow] = try? await client.call(
            model: "res.users", method: "search_read", args: [],
            kwargs: ["domain": [["id", "=", uid]], "fields": ["partner_id"], "limit": 1]),
              let pid = users.first?.pid else { return }
        if let partners: [PRow] = try? await client.call(
            model: "res.partner", method: "search_read", args: [],
            kwargs: ["domain": [["id", "=", pid]], "fields": ["first_name", "name", "local_rewards_card_id"], "limit": 1]),
           let p = partners.first {
            let sessionName = await OdooSession.shared.getUserName()
            firstName = p.firstName?.nilIfEmptyA
                ?? p.name?.split(separator: " ").first.map(String.init)
                ?? sessionName?.split(separator: " ").first.map(String.init)
        }

        // Cumul à jour + synchro Adelya déclenchée à l'ouverture (endpoint serveur,
        // même source que Ma Carte). C'est Odoo qui parle à Adelya, pas l'app.
        if let resp: LoyaltyHistoryResponse = try? await client.callRoute("/my/loyalty/history", params: [:]),
           let credit = resp.cumulCredit {
            balance = credit
            LoyaltyCardStore.balance = credit
        }
    }
}

private extension String { var nilIfEmptyA: String? { isEmpty ? nil : self } }

// MARK: - Vue

/// Destinations de l'Accueil poussées par valeur (pour que le reset d'onglet
/// — vidage du NavigationPath — les dépile bien).
enum AccueilDestination: Hashable { case maCarte }

struct AccueilView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var viewModel = AccueilViewModel()
    var selectTab: (MainTabView.Tab) -> Void = { _ in }
    var popTrigger: Int = 0
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    NavigationLink(value: AccueilDestination.maCarte) { balanceCard }.buttonStyle(.plain)
                    quickActions
                    if !viewModel.offers.isEmpty { offersSection }
                    if !viewModel.news.isEmpty { newsSection }
                    if !viewModel.merchants.isEmpty { merchantsSection }
                    logoutButton
                }
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            .aboveTabBar()
            .background(Color.brandSurface)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: AccueilDestination.self) { _ in MaCarteView() }
            .navigationDestination(for: MerchantCoupon.self) { CouponDetailView(coupon: $0) }
            .navigationDestination(for: Merchant.self) { MerchantDetailView(merchantId: $0.id, merchantName: $0.name) }
            .navigationDestination(for: BlogPost.self) { AccueilBlogDestination(post: $0) }
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
        }
        .onChange(of: popTrigger) { _, _ in path = NavigationPath() }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color.brandNavy).frame(width: 40, height: 40)
                    Text(initial)
                        .font(BrandFont.serif(18, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text("Bonjour \(viewModel.firstName ?? "") 👋".trimmingCharacters(in: .whitespaces))
                    .font(BrandFont.sans(15))
                    .foregroundStyle(Color.brandTextMuted)
            }
            Text(welcomeAttributed)
                .font(BrandFont.serif(24, weight: .bold))
        }
        .padding(.horizontal, 16)
    }

    private var initial: String {
        viewModel.firstName?.trimmingCharacters(in: .whitespaces).first
            .map { String($0).uppercased() } ?? "👤"
    }

    private var welcomeAttributed: AttributedString {
        var a = AttributedString("Bienvenue aux ")
        a.foregroundColor = .brandNavy
        var b = AttributedString("Vitrines d'Alençon")
        b.foregroundColor = .brandRed
        return a + b
    }

    // MARK: Carte fidélité

    private var balanceCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(.white).frame(width: 46, height: 46)
                Image(systemName: "wallet.pass.fill")
                    .font(.system(size: 22)).foregroundStyle(Color.brandRed)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("MA CAGNOTTE FIDÉLITÉ")
                    .font(BrandFont.sans(11, weight: .bold)).tracking(0.6)
                    .foregroundStyle(.white.opacity(0.9))
                Text(viewModel.balance.map { String(format: "%.2f €", $0) } ?? "—")
                    .font(BrandFont.serif(26, weight: .bold)).foregroundStyle(.white)
                Text("Voir ma carte et mon historique")
                    .font(BrandFont.sans(13)).foregroundStyle(.white.opacity(0.9))
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.9))
        }
        .padding(16)
        .background(LinearGradient.brandRed, in: .rect(cornerRadius: 20))
        .padding(.horizontal, 16)
    }

    // MARK: Raccourcis

    private var quickActions: some View {
        HStack(spacing: 12) {
            quickAction("Commerces", icon: "storefront.fill", color: .brandNavy) { selectTab(.merchants) }
            quickAction("Notifications", icon: "bell.fill", color: .brandRed) { selectTab(.notifs) }
            quickAction("Carte cadeau", icon: "gift.fill", color: .brandGreen) { selectTab(.account) }
        }
        .padding(.horizontal, 16)
    }

    private func quickAction(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle().fill(color.opacity(0.12)).frame(width: 44, height: 44)
                    Image(systemName: icon).font(.system(size: 19)).foregroundStyle(color)
                }
                Text(title).font(BrandFont.sans(13, weight: .semibold)).foregroundStyle(Color.brandNavy)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(.white, in: .rect(cornerRadius: 16))
            .cardShadow()
        }
        .buttonStyle(.plain)
    }

    // MARK: EN CE MOMENT (offres)

    private var offersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("En ce moment", voirTout: { selectTab(.deals) })
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(viewModel.offers) { offer in
                        NavigationLink(value: offer) {
                            featuredCard(image: offer.imageURL, title: offer.name, subtitle: offer.merchantName)
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal, 16)
            }
        }
    }

    // MARK: Actualités

    private var newsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Agenda et actualités", voirTout: { selectTab(.news) })
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(viewModel.news) { post in
                        NavigationLink(value: post) {
                            featuredCard(image: post.coverImageURL, title: post.name, subtitle: post.excerpt)
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal, 16)
            }
        }
    }

    // MARK: Commerces à découvrir

    private var merchantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Commerces à découvrir", voirTout: { selectTab(.merchants) })
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(viewModel.merchants.prefix(8)) { m in
                        NavigationLink(value: m) {
                            featuredCard(image: m.imageURL, title: m.name, subtitle: nil)
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal, 16)
            }
        }
    }

    // MARK: Helpers

    private func sectionTitle(_ title: String, voirTout: (() -> Void)? = nil) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2).fill(Color.brandRed).frame(width: 4, height: 20)
            Text(title)
                .font(BrandFont.serif(18, weight: .bold))
                .foregroundStyle(Color.brandNavy)
            Spacer()
            if let voirTout {
                Button(action: voirTout) {
                    HStack(spacing: 2) { Text("Voir tout"); Image(systemName: "chevron.right") }
                        .font(BrandFont.sans(13, weight: .semibold)).foregroundStyle(Color.brandNavy)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func featuredCard(image: URL?, title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: 132)
                .overlay {
                    RemoteImage(url: image) { phase in
                        if case .success(let img) = phase { img.resizable().scaledToFill() }
                        else { ZStack { LinearGradient.brandSurface; Image(systemName: "photo").foregroundStyle(Color.brandNavy.opacity(0.3)) } }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .clipped()
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(BrandFont.serif(16, weight: .bold)).foregroundStyle(Color.brandNavy).lineLimit(2)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle).font(BrandFont.sans(13)).foregroundStyle(Color.brandTextMuted).lineLimit(2)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 220)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .cardShadow()
    }

    private var logoutButton: some View {
        Button { Task { await auth.logout() } } label: {
            Label("Déconnexion", systemImage: "rectangle.portrait.and.arrow.right")
                .font(BrandFont.sans(16, weight: .medium)).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity).padding(.vertical, 16)
        }
        .padding(.top, 12)
    }
}

private extension View {
    /// Ombre douce des cartes blanches sur fond gris clair.
    func cardShadow() -> some View {
        shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

/// Charge le VM de contenu pour afficher un article depuis l'accueil.
private struct AccueilBlogDestination: View {
    let post: BlogPost
    @StateObject private var vm = ActualitesViewModel()
    var body: some View { BlogPostDetailView(post: post, viewModel: vm) }
}
