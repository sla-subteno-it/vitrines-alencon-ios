// NotificationsView.swift
// Vitrines d'Alençon — iOS
// Onglet Notifications : portal.notification.event, réplique de /my/notifications.

import SwiftUI
import Combine

// MARK: - Modèle

enum NotifKind: String {
    case merchant = "new_merchant"
    case coupon   = "new_coupon"
    case blog     = "new_blog"

    var label: String {
        switch self {
        case .merchant: return "COMMERCE"
        case .coupon:   return "BON PLAN"
        case .blog:     return "ACTUALITÉ"
        }
    }
    var color: Color {
        switch self {
        case .merchant: return Color(hex: 0x05944F)   // vert
        case .coupon:   return Color.brandRed         // rouge
        case .blog:     return Color(hex: 0x3B82F6)   // bleu
        }
    }
    var icon: String {
        switch self {
        case .merchant: return "storefront.fill"
        case .coupon:   return "tag.fill"
        case .blog:     return "newspaper.fill"
        }
    }
    var badgeIcon: String {
        switch self {
        case .merchant: return "checkmark"
        case .coupon:   return "star.fill"
        case .blog:     return "plus"
        }
    }
}

struct NotifEvent: Identifiable, Decodable {
    let id: Int
    let notificationType: String
    let title: String
    let body: String?
    let url: String?
    let createDate: String?
    let resModel: String?
    let resId: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, body, url
        case notificationType = "notification_type"
        case createDate = "create_date"
        case resModel = "res_model"
        case resId = "res_id"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        notificationType = (try? c.decode(String.self, forKey: .notificationType)) ?? ""
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        body = try? c.decode(String.self, forKey: .body)
        url = try? c.decode(String.self, forKey: .url)
        createDate = try? c.decode(String.self, forKey: .createDate)
        resModel = try? c.decode(String.self, forKey: .resModel)
        resId = try? c.decode(Int.self, forKey: .resId)
    }

    var kind: NotifKind? { NotifKind(rawValue: notificationType) }
    var date: Date? { createDate.flatMap(CouponDetailView.parseOdooDate) }

    var timestamp: String {
        guard let d = date else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "dd/MM HH:mm"
        return f.string(from: d)
    }
}

private struct UserCreateRow: Decodable { let createDate: String?
    enum CodingKeys: String, CodingKey { case createDate = "create_date" }
}

/// Offre (pour résoudre image + logo commerçant des notifs bons plans).
private struct OfferImageRow: Decodable {
    let id: Int
    let imageUrl: String?
    let merchantId: Int?
    enum CodingKeys: String, CodingKey { case id; case imageUrl = "image_url"; case merchantId = "merchant_id" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        imageUrl = try? c.decode(String.self, forKey: .imageUrl)
        if var m2o = try? c.nestedUnkeyedContainer(forKey: .merchantId) {
            merchantId = try? m2o.decode(Int.self)
        } else { merchantId = nil }
    }
}

// MARK: - ViewModel

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published var all: [NotifEvent] = []
    @Published var selectedFilter: NotifKind?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var offerImage: [Int: String] = [:]      // res_id (offre) → image_url
    private var offerMerchant: [Int: Int] = [:]      // res_id (offre) → merchant partner id
    private let client = OdooClient.shared

    /// Avatar : logo du commerce (partner direct, ou via merchant de l'offre).
    func avatarURL(for n: NotifEvent) -> URL? {
        if n.resModel == "res.partner", let id = n.resId {
            return URL(string: "\(OdooConfig.baseURL)/web/image/res.partner/\(id)/image_1920/128x128")
        }
        if n.resModel == "local.rewards.offer", let rid = n.resId, let mid = offerMerchant[rid] {
            return URL(string: "\(OdooConfig.baseURL)/web/image/res.partner/\(mid)/image_1920/128x128")
        }
        return nil
    }

    /// Bannière : image de l'offre (image_url externe Adelya).
    func bannerURL(for n: NotifEvent) -> URL? {
        guard n.resModel == "local.rewards.offer", let rid = n.resId,
              let u = offerImage[rid], !u.isEmpty else { return nil }
        return URL(string: u.hasPrefix("http") ? u : OdooConfig.baseURL + u)
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        guard let uid = await OdooSession.shared.getUID() else { return }
        do {
            // create_date de l'utilisateur (le PWA n'affiche que les notifs depuis l'inscription)
            let users: [UserCreateRow] = try await client.call(
                model: "res.users", method: "search_read", args: [],
                kwargs: ["domain": [["id", "=", uid]], "fields": ["create_date"], "limit": 1]
            )
            var domain: [[Any]] = [["active", "=", true]]
            if let since = users.first?.createDate {
                domain.append(["create_date", ">=", since])
            }
            all = try await client.call(
                model: "portal.notification.event", method: "search_read", args: [],
                kwargs: ["domain": domain,
                         "fields": ["notification_type", "title", "body", "url",
                                    "create_date", "res_model", "res_id"],
                         "order": "create_date desc", "limit": 300]
            )

            // Images des offres (bons plans) : image_url + logo commerçant, en un seul appel.
            let offerIds = Array(Set(all.filter { $0.resModel == "local.rewards.offer" }
                .compactMap { $0.resId }))
            if !offerIds.isEmpty {
                let offers: [OfferImageRow] = try await client.call(
                    model: "local.rewards.offer", method: "search_read", args: [],
                    kwargs: ["domain": [["id", "in", offerIds]],
                             "fields": ["image_url", "merchant_id"]]
                )
                offerImage = Dictionary(offers.compactMap { o in o.imageUrl.map { (o.id, $0) } },
                                        uniquingKeysWith: { a, _ in a })
                offerMerchant = Dictionary(offers.compactMap { o in o.merchantId.map { (o.id, $0) } },
                                           uniquingKeysWith: { a, _ in a })
            }
        } catch {
            errorMessage = (error as? OdooError)?.errorDescription ?? error.localizedDescription
        }
    }

    func count(_ kind: NotifKind?) -> Int {
        guard let kind else { return all.count }
        return all.filter { $0.kind == kind }.count
    }

    var filtered: [NotifEvent] {
        guard let f = selectedFilter else { return all }
        return all.filter { $0.kind == f }
    }

    /// Sections temporelles : Aujourd'hui / Cette semaine / Plus ancien.
    var sections: [(title: String, items: [NotifEvent])] {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let weekStart = cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? todayStart
        var today: [NotifEvent] = [], week: [NotifEvent] = [], older: [NotifEvent] = []
        for n in filtered {
            let d = n.date ?? .distantPast
            if d >= todayStart { today.append(n) }
            else if d >= weekStart { week.append(n) }
            else { older.append(n) }
        }
        return [("Aujourd'hui", today), ("Cette semaine", week), ("Plus ancien", older)]
            .filter { !$0.items.isEmpty }
    }
}

// MARK: - Vue

struct NotificationsView: View {
    @StateObject private var viewModel = NotificationsViewModel()
    @State private var path = NavigationPath()

    /// Incrémenté par le tab bar → revenir à la racine (sans recharger).
    var popTrigger: Int = 0

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Notifications")
                        .font(BrandFont.serif(30, weight: .bold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    filterBar
                        .padding(.top, 12)

                    if viewModel.isLoading && viewModel.all.isEmpty {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
                    } else if let error = viewModel.errorMessage, viewModel.all.isEmpty {
                        ContentUnavailableView {
                            Label("Erreur", systemImage: "wifi.exclamationmark")
                        } description: { Text(error) } actions: {
                            Button("Réessayer") { Task { await viewModel.load() } }
                                .buttonStyle(.borderedProminent).tint(Color.brandNavy)
                        }
                    } else if viewModel.filtered.isEmpty {
                        ContentUnavailableView("Aucune notification", systemImage: "bell")
                            .padding(.top, 60)
                    } else {
                        ForEach(viewModel.sections, id: \.title) { section in
                            sectionHeader(section.title)
                            ForEach(section.items) { notif in
                                let row = NotificationRow(notif: notif,
                                                          avatarURL: viewModel.avatarURL(for: notif),
                                                          bannerURL: viewModel.bannerURL(for: notif))
                                if let dest = destination(for: notif) {
                                    NavigationLink(value: dest) { row }.buttonStyle(.plain)
                                } else {
                                    row
                                }
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                }
            }
            .aboveTabBar()
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: NotifDestination.self) { dest in
                switch dest {
                case .merchant(let id): MerchantDetailView(merchantId: id, merchantName: "")
                case .coupon(let id):   CouponLoaderView(offerId: id)
                case .blog(let id):     BlogLoaderView(postId: id)
                }
            }
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
        }
        .onChange(of: popTrigger) { _, _ in path = NavigationPath() }
    }

    private func destination(for n: NotifEvent) -> NotifDestination? {
        guard let id = n.resId else { return nil }
        switch n.resModel {
        case "local.rewards.offer": return .coupon(id)
        case "blog.post":           return .blog(id)
        case "res.partner":         return .merchant(id)
        default:                    return nil
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 22) {
                filterTab("Tout", kind: nil)
                filterTab("Commerces", kind: .merchant)
                filterTab("Bons Plans", kind: .coupon)
                filterTab("Actualités", kind: .blog)
            }
            .padding(.horizontal, 16)
        }
        .overlay(alignment: .bottom) { Divider() }
    }

    private func filterTab(_ label: String, kind: NotifKind?) -> some View {
        let isSel = viewModel.selectedFilter == kind
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { viewModel.selectedFilter = kind }
        } label: {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Text(label).font(BrandFont.sans(15, weight: isSel ? .bold : .regular))
                    Text("\(viewModel.count(kind))")
                        .font(BrandFont.sans(11, weight: .semibold))
                        .foregroundStyle(Color.brandTextMuted)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Color.brandNavy.opacity(0.08), in: .capsule)
                }
                .foregroundStyle(isSel ? Color.brandNavy : Color.brandTextMuted)
                Rectangle().fill(isSel ? Color.brandNavy : .clear).frame(height: 2)
            }
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(BrandFont.sans(12, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(Color.brandTextMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 8)
    }
}

// MARK: - Navigation (ouvre bon plan / article / commerce)

enum NotifDestination: Hashable {
    case coupon(Int)
    case blog(Int)
    case merchant(Int)
}

/// Charge l'offre par id puis affiche la fiche bon plan.
private struct CouponLoaderView: View {
    let offerId: Int
    @State private var coupon: MerchantCoupon?
    @State private var failed = false

    var body: some View {
        Group {
            if let coupon {
                CouponDetailView(coupon: coupon)
            } else if failed {
                ContentUnavailableView("Bon plan introuvable", systemImage: "tag.slash")
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            coupon = try? await MerchantService.shared.fetchOffer(id: offerId)
            failed = (coupon == nil)
        }
    }
}

/// Charge l'article par id puis affiche la fiche.
private struct BlogLoaderView: View {
    let postId: Int
    @StateObject private var vm = ActualitesViewModel()
    @State private var post: BlogPost?
    @State private var failed = false

    var body: some View {
        Group {
            if let post {
                BlogPostDetailView(post: post, viewModel: vm)
            } else if failed {
                ContentUnavailableView("Article introuvable", systemImage: "newspaper")
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            post = await vm.fetchPost(id: postId)
            failed = (post == nil)
        }
    }
}

// MARK: - Ligne notification

private struct NotificationRow: View {
    let notif: NotifEvent
    let avatarURL: URL?
    let bannerURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                avatar
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(notif.kind?.label ?? "")
                            .font(BrandFont.sans(12, weight: .bold))
                            .tracking(0.4)
                            .foregroundStyle(notif.kind?.color ?? Color.brandNavy)
                        Spacer()
                        Text(notif.timestamp)
                            .font(BrandFont.sans(12))
                            .foregroundStyle(Color.brandTextMuted)
                    }
                    Text(notif.title)
                        .font(BrandFont.serif(17, weight: .bold))
                        .foregroundStyle(Color.brandNavy)
                        .fixedSize(horizontal: false, vertical: true)
                    if let body = notif.body, !body.isEmpty {
                        Text(body)
                            .font(BrandFont.sans(14))
                            .foregroundStyle(Color.brandTextMuted)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if let banner = bannerURL {
                RemoteImage(url: banner) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.leading, 56)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var avatar: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let url = avatarURL {
                    RemoteImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFill()
                        } else { fallback }
                    }
                } else {
                    fallback
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

            Image(systemName: notif.kind?.badgeIcon ?? "bell.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(notif.kind?.color ?? Color.brandNavy, in: .circle)
                .overlay(Circle().stroke(.white, lineWidth: 1.5))
        }
    }

    private var fallback: some View {
        ZStack {
            (notif.kind?.color ?? Color.brandNavy).opacity(0.12)
            Image(systemName: notif.kind?.icon ?? "bell.fill")
                .font(.system(size: 18))
                .foregroundStyle(notif.kind?.color ?? Color.brandNavy)
        }
    }
}
