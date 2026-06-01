// MaCarteView.swift
// Vitrines d'Alençon — iOS
// Onglet/page Ma Carte : carte fidélité visuelle (+ code-barre), solde, préférences.
// Réplique de /ma-carte (v1 : carte + préférences ; Historique/Mes Commerces à venir).

import SwiftUI
import Combine
import CoreImage.CIFilterBuiltins

// MARK: - ViewModel

@MainActor
final class MaCarteViewModel: ObservableObject {
    @Published var fullName: String = ""
    @Published var balance: Double?
    @Published var cardNumber: String?
    @Published var emailOptIn = false
    @Published var smsOptIn = false
    @Published var isLoading = false
    @Published var saveMessage: String?

    @Published var events: [LoyaltyEvent] = []
    @Published var selectedPeriod: String?
    @Published var eventsError: String?

    private let client = OdooClient.shared
    private var partnerId: Int?
    private var cardId: Int?

    // MARK: - Historique / Mes Commerces (dérivés des events)

    var periods: [(key: String, label: String)] {
        Set(events.compactMap { $0.yearMonth }).sorted(by: >).map { ($0, Self.periodLabel($0)) }
    }

    func historyGroups() -> [HistoryGroup] {
        let evs = events.filter { selectedPeriod == nil || $0.yearMonth == selectedPeriod }
        var byMerchant: [Int: HistoryGroup] = [:]
        for e in evs {
            guard let mid = e.merchantId else { continue }
            var g = byMerchant[mid] ?? HistoryGroup(merchantId: mid, merchantName: e.merchantName ?? "",
                                                    achatsCount: 0, achatsTotal: 0, latest: "")
            if e.type == "addCA" { g.achatsCount += 1; g.achatsTotal += e.fvalue }
            if (e.date ?? "") > g.latest { g.latest = e.date ?? "" }
            byMerchant[mid] = g
        }
        return byMerchant.values.sorted { $0.latest > $1.latest }
    }

    var visitedMerchants: [VisitedMerchant] {
        var byMerchant: [Int: VisitedMerchant] = [:]
        for e in events {
            guard let mid = e.merchantId else { continue }
            var v = byMerchant[mid] ?? VisitedMerchant(merchantId: mid, merchantName: e.merchantName ?? "", lastDate: "")
            if (e.date ?? "") > v.lastDate { v.lastDate = e.date ?? "" }
            byMerchant[mid] = v
        }
        return byMerchant.values.sorted { $0.lastDate > $1.lastDate }
    }

    static func periodLabel(_ ym: String) -> String {
        let parts = ym.split(separator: "-")
        guard parts.count == 2, let m = Int(parts[1]) else { return ym }
        let months = ["", "Janvier", "Février", "Mars", "Avril", "Mai", "Juin",
                      "Juillet", "Août", "Septembre", "Octobre", "Novembre", "Décembre"]
        return "\((1...12).contains(m) ? months[m] : "Mois") \(parts[0])"
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let uid = await OdooSession.shared.getUID() else { return }
        do {
            let users: [PartnerRefRow] = try await client.call(
                model: "res.users", method: "search_read", args: [],
                kwargs: ["domain": [["id", "=", uid]], "fields": ["partner_id"], "limit": 1]
            )
            guard let pid = users.first?.refId else { return }
            partnerId = pid

            let partners: [CardPartnerRow] = try await client.call(
                model: "res.partner", method: "search_read", args: [],
                kwargs: ["domain": [["id", "=", pid]],
                         "fields": ["name", "first_name", "cardnumber",
                                    "email_optin_status", "sms_optin_status",
                                    "local_rewards_card_id"], "limit": 1]
            )
            guard let p = partners.first else { return }
            let sessionName = await OdooSession.shared.getUserName()
            fullName = p.name?.nilIfEmpty ?? sessionName ?? ""
            cardNumber = p.cardnumber?.nilIfEmpty
            emailOptIn = (p.emailOptIn == "1")
            smsOptIn = (p.smsOptIn == "1")

            cardId = p.cardId
            if let cardId = p.cardId {
                let cards: [CardTotalRow] = try await client.call(
                    model: "local.rewards.card", method: "search_read", args: [],
                    kwargs: ["domain": [["id", "=", cardId]],
                             "fields": ["total_add_credit_amount"], "limit": 1]
                )
                balance = cards.first?.total
            }

        } catch {
            // page reste affichable
        }

        await loadEvents()
    }

    /// Charge les events (historique + commerces visités) — erreur isolée et affichée.
    func loadEvents() async {
        guard let pid = partnerId else { return }
        do {
            // Membres partageant la même carte (related_member_partner_ids)
            var memberIds = [pid]
            if let cardId {
                let members: [IdRow] = try await client.call(
                    model: "res.partner", method: "search_read", args: [],
                    kwargs: ["domain": [["local_rewards_card_id", "=", cardId],
                                        ["is_company", "=", false]],
                             "fields": ["id"],
                             "context": ["active_test": false]]
                )
                if !members.isEmpty { memberIds = members.map { $0.id } }
            }

            let evs: [LoyaltyEvent] = try await client.call(
                model: "local.rewards.event", method: "search_read", args: [],
                kwargs: ["domain": [["member_id", "in", memberIds],
                                    ["type", "in", ["addCA", "addCredit"]]],
                         "fields": ["merchant_id", "date", "fvalue", "year_month", "type"],
                         "order": "date desc", "limit": 1000]
            )
            events = evs
            eventsError = nil
            if selectedPeriod == nil { selectedPeriod = periods.first?.key }
        } catch {
            eventsError = (error as? OdooError)?.errorDescription ?? error.localizedDescription
        }
    }

    func savePreferences() async {
        guard let pid = partnerId else { return }
        do {
            let _: Bool = try await client.call(
                model: "res.partner", method: "write",
                args: [[pid], ["email_optin_status": emailOptIn ? "1" : "0",
                               "sms_optin_status": smsOptIn ? "1" : "0"]],
                kwargs: [:]
            )
            saveMessage = "Préférences enregistrées."
        } catch {
            saveMessage = (error as? OdooError)?.errorDescription ?? "Échec de l'enregistrement."
        }
    }
}

private extension String { var nilIfEmpty: String? { isEmpty ? nil : self } }

// MARK: - Lignes de décodage

private struct PartnerRefRow: Decodable {
    let refId: Int?
    enum CodingKeys: String, CodingKey { case partnerId = "partner_id" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if var m2o = try? c.nestedUnkeyedContainer(forKey: .partnerId) {
            refId = try? m2o.decode(Int.self)
        } else { refId = nil }
    }
}

private struct CardPartnerRow: Decodable {
    let name: String?
    let firstName: String?
    let cardnumber: String?
    let emailOptIn: String?
    let smsOptIn: String?
    let cardId: Int?
    enum CodingKeys: String, CodingKey {
        case name, cardnumber
        case firstName = "first_name"
        case emailOptIn = "email_optin_status"
        case smsOptIn = "sms_optin_status"
        case cardId = "local_rewards_card_id"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try? c.decode(String.self, forKey: .name)
        firstName = try? c.decode(String.self, forKey: .firstName)
        cardnumber = try? c.decode(String.self, forKey: .cardnumber)
        emailOptIn = try? c.decode(String.self, forKey: .emailOptIn)
        smsOptIn = try? c.decode(String.self, forKey: .smsOptIn)
        if var m2o = try? c.nestedUnkeyedContainer(forKey: .cardId) {
            cardId = try? m2o.decode(Int.self)
        } else { cardId = nil }
    }
}

private struct IdRow: Decodable { let id: Int }

private struct CardTotalRow: Decodable {
    let total: Double?
    enum CodingKeys: String, CodingKey { case total = "total_add_credit_amount" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        total = try? c.decode(Double.self, forKey: .total)
    }
}

struct LoyaltyEvent: Decodable {
    let merchantId: Int?
    let merchantName: String?
    let date: String?
    let fvalue: Double
    let yearMonth: String?
    let type: String

    enum CodingKeys: String, CodingKey {
        case merchantId = "merchant_id"
        case date, fvalue, type
        case yearMonth = "year_month"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try? c.decode(String.self, forKey: .date)
        fvalue = (try? c.decode(Double.self, forKey: .fvalue)) ?? 0
        yearMonth = try? c.decode(String.self, forKey: .yearMonth)
        type = (try? c.decode(String.self, forKey: .type)) ?? ""
        if var m2o = try? c.nestedUnkeyedContainer(forKey: .merchantId) {
            merchantId = try? m2o.decode(Int.self)
            merchantName = try? m2o.decode(String.self)
        } else { merchantId = nil; merchantName = nil }
    }
}

struct HistoryGroup: Identifiable {
    let merchantId: Int
    let merchantName: String
    var achatsCount: Int
    var achatsTotal: Double
    var latest: String
    var id: Int { merchantId }
}

struct VisitedMerchant: Identifiable {
    let merchantId: Int
    let merchantName: String
    var lastDate: String
    var id: Int { merchantId }
}

// MARK: - Vue

struct MaCarteView: View {
    @StateObject private var viewModel = MaCarteViewModel()
    @State private var showBarcode = false
    @State private var historyTab: HistoryTab = .historique

    private enum HistoryTab { case historique, commerces }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                LoyaltyCard(viewModel: viewModel) { showBarcode = true }
                barcodeHint
                Divider()
                preferencesSection
                Divider()
                historySection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .fullScreenCover(isPresented: $showBarcode) {
            CardBackView(cardNumber: viewModel.cardNumber)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Ma Carte")
                .font(BrandFont.serif(28, weight: .bold))
                .foregroundStyle(Color.brandNavy)
            Text("Gérez vos crédits et vos préférences")
                .font(BrandFont.sans(15))
                .foregroundStyle(Color.brandTextMuted)
        }
        .padding(.top, 12)
    }

    private var barcodeHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "barcode")
            Text("Appuyez sur la carte pour afficher votre code-barre en caisse")
                .font(BrandFont.sans(14))
        }
        .foregroundStyle(Color.brandTextMuted)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Préférences

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Préférences de communication")
                .font(BrandFont.serif(20, weight: .bold))
                .foregroundStyle(Color.brandNavy)

            prefToggle(icon: "envelope.fill", title: "Notifications par email",
                       subtitle: "Recevoir les notifications par email", isOn: $viewModel.emailOptIn)
            prefToggle(icon: "iphone", title: "Notifications par SMS",
                       subtitle: "Recevoir les notifications par SMS", isOn: $viewModel.smsOptIn)

            Button {
                Task { await viewModel.savePreferences() }
            } label: {
                Label("Enregistrer les préférences", systemImage: "square.and.arrow.down")
                    .font(BrandFont.sans(15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Color.brandNavy, in: .rect(cornerRadius: 10))
            }

            if let msg = viewModel.saveMessage {
                Text(msg)
                    .font(BrandFont.sans(13))
                    .foregroundStyle(Color.brandGreen)
            }
        }
    }

    private func prefToggle(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(BrandFont.sans(16, weight: .medium))
                .foregroundStyle(Color.brandNavy)
            Toggle(isOn: isOn) {
                Text(subtitle)
                    .font(BrandFont.sans(14))
                    .foregroundStyle(Color.brandTextMuted)
            }
            .tint(Color.brandNavy)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandNavy.opacity(0.12), lineWidth: 1))
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.brandNavy).frame(width: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Historique (à venir)

    // MARK: - Historique / Mes Commerces

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 24) {
                historyTabButton("Historique", icon: "clock.arrow.circlepath", tab: .historique, count: nil)
                historyTabButton("Mes Commerces", icon: "bag.fill", tab: .commerces,
                                 count: viewModel.visitedMerchants.count)
                Spacer()
            }
            .overlay(alignment: .bottom) { Divider() }

            if let err = viewModel.eventsError {
                Label(err, systemImage: "exclamationmark.triangle")
                    .font(BrandFont.sans(13))
                    .foregroundStyle(.red)
            }

            if historyTab == .historique {
                historiqueContent
            } else {
                commercesContent
            }
        }
    }

    private func historyTabButton(_ title: String, icon: String, tab: HistoryTab, count: Int?) -> some View {
        let isSel = historyTab == tab
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { historyTab = tab }
        } label: {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: icon).font(.system(size: 13))
                    Text(title).font(BrandFont.serif(16, weight: isSel ? .bold : .regular))
                    if let count {
                        Text("\(count)")
                            .font(BrandFont.sans(11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Color.brandNavy, in: .capsule)
                    }
                }
                .foregroundStyle(isSel ? Color.brandNavy : Color.brandTextMuted)
                Rectangle().fill(isSel ? Color.brandNavy : .clear).frame(height: 2)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Historique

    @ViewBuilder
    private var historiqueContent: some View {
        if viewModel.periods.isEmpty {
            emptyHistory("Aucun historique pour le moment.")
        } else {
            Menu {
                ForEach(viewModel.periods, id: \.key) { p in
                    Button(p.label) { viewModel.selectedPeriod = p.key }
                }
            } label: {
                HStack {
                    Text(viewModel.periods.first(where: { $0.key == viewModel.selectedPeriod })?.label
                         ?? viewModel.periods.first?.label ?? "")
                        .font(BrandFont.serif(17, weight: .bold))
                        .foregroundStyle(Color.brandNavy)
                    Spacer()
                    Image(systemName: "chevron.down").foregroundStyle(Color.brandTextMuted)
                }
                .padding(16)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandNavy.opacity(0.12), lineWidth: 1))
            }

            let groups = viewModel.historyGroups()
            if groups.isEmpty {
                emptyHistory("Aucun achat sur cette période.")
            } else {
                ForEach(groups) { g in
                    HStack(spacing: 12) {
                        MerchantThumb(merchantId: g.merchantId, size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(g.merchantName)
                                .font(BrandFont.serif(17, weight: .bold))
                                .foregroundStyle(Color.brandNavy)
                                .lineLimit(1)
                            if g.achatsCount > 0 {
                                Text("\(g.achatsCount) achat\(g.achatsCount > 1 ? "s" : "")")
                                    .font(BrandFont.sans(13))
                                    .foregroundStyle(Color.brandTextMuted)
                            }
                        }
                        Spacer(minLength: 8)
                        if g.achatsTotal > 0 {
                            VStack(alignment: .trailing, spacing: 0) {
                                Text(String(format: "%.2f €", g.achatsTotal))
                                    .font(BrandFont.serif(16, weight: .bold))
                                    .foregroundStyle(Color.brandNavy)
                                Text("achats").font(BrandFont.sans(11)).foregroundStyle(Color.brandTextMuted)
                            }
                        }
                    }
                    .padding(14)
                    .background(.white, in: .rect(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.brandNavy.opacity(0.06), lineWidth: 1))
                }
            }
        }
    }

    // MARK: Mes Commerces

    @ViewBuilder
    private var commercesContent: some View {
        let merchants = viewModel.visitedMerchants
        if merchants.isEmpty {
            emptyHistory("Aucun commerce visité pour le moment.")
        } else {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 16) {
                ForEach(merchants) { m in
                    VStack(alignment: .leading, spacing: 8) {
                        Color.clear
                            .aspectRatio(4.0 / 3.0, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .overlay { MerchantThumb(merchantId: m.merchantId, size: nil) }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        Text(m.merchantName)
                            .font(BrandFont.serif(16, weight: .bold))
                            .foregroundStyle(Color.brandNavy)
                            .lineLimit(1)
                        Label("Dernière visite : \(Self.shortDate(m.lastDate))", systemImage: "clock")
                            .font(BrandFont.sans(12))
                            .foregroundStyle(Color.brandTextMuted)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private func emptyHistory(_ text: String) -> some View {
        Text(text)
            .font(BrandFont.sans(14))
            .foregroundStyle(Color.brandTextMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
    }

    static func shortDate(_ raw: String) -> String {
        guard let d = CouponDetailView.parseOdooDate(raw) else { return raw }
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "dd/MM/yy"
        return f.string(from: d)
    }
}

// MARK: - Vignette commerçant (image Odoo)

private struct MerchantThumb: View {
    let merchantId: Int
    var size: CGFloat?

    private var url: URL? {
        URL(string: "\(OdooConfig.baseURL)/web/image/res.partner/\(merchantId)/image_1920?width=200")
    }

    var body: some View {
        RemoteImage(url: url) { phase in
            switch phase {
            case .success(let image): image.resizable().scaledToFill()
            default:
                ZStack {
                    Color.brandSurface2
                    Image(systemName: "storefront").foregroundStyle(Color.brandNavy.opacity(0.4))
                }
            }
        }
        .applyThumbFrame(size)
    }
}

private extension View {
    @ViewBuilder
    func applyThumbFrame(_ size: CGFloat?) -> some View {
        if let size {
            self.frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            self.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Carte fidélité (recto / code-barre)

private struct LoyaltyCard: View {
    @ObservedObject var viewModel: MaCarteViewModel
    var onTap: () -> Void

    var body: some View {
        cardFace
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
    }

    private var cardFace: some View {
        cardImage
            .overlay {
                GeometryReader { geo in
                    cardOverlays(geo.size.width)
                }
            }
    }

    @ViewBuilder
    private var cardImage: some View {
        Image("CarteFideliteRecto")
            .resizable()
            .aspectRatio(contentMode: .fit)
    }

    private func cardOverlays(_ w: CGFloat) -> some View {
        ZStack {
            // (Le logo central est déjà dans le SVG carte_fidelite_recto.)

            // Titre haut-gauche
            Text("Les Vitrines d'Alençon")
                .font(BrandFont.serif(w * 0.034, weight: .bold))
                .italic()
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(w * 0.05)

            // Nom + cagnotte (bas)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(firstName).font(BrandFont.sans(w * 0.032))
                    Text(lastName).font(BrandFont.sans(w * 0.045, weight: .bold))
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 0) {
                    Text("CAGNOTTE").font(BrandFont.sans(w * 0.028))
                    Text(balanceText).font(BrandFont.sans(w * 0.045, weight: .bold))
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(w * 0.05)
        }
    }

    private var firstName: String {
        viewModel.fullName.split(separator: " ").first.map(String.init)?.uppercased() ?? ""
    }
    private var lastName: String {
        let parts = viewModel.fullName.split(separator: " ")
        return parts.count > 1 ? parts.dropFirst().joined(separator: " ").uppercased() : ""
    }
    private var balanceText: String {
        viewModel.balance.map { String(format: "%.2f", $0) } ?? "—"
    }

    static func barcode(from string: String) -> UIImage? {
        let filter = CIFilter.code128BarcodeGenerator()
        filter.message = Data(string.utf8)
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 4, y: 4))
        let context = CIContext()
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

// MARK: - Verso plein écran (carte_fidelite_verso.svg + code-barre)

struct CardBackView: View {
    let cardNumber: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geo in
            let cardH = geo.size.width            // pré-rotation : hauteur = largeur écran (100vw)
            let cardW = cardH * 8.0 / 5.0         // aspect 8:5 (comme la PWA)

            ZStack {
                Color.white.ignoresSafeArea()

                cardContent(cardW: cardW, cardH: cardH)
                    .frame(width: cardW, height: cardH)
                    .rotationEffect(.degrees(90))
                    .frame(width: geo.size.width, height: geo.size.height)
            }
            .overlay(alignment: .topTrailing) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.brandRed, in: .circle)
                }
                .padding(16)
            }
        }
    }

    private func cardContent(cardW: CGFloat, cardH: CGFloat) -> some View {
        Image("CarteFideliteVerso")
            .resizable()
            .frame(width: cardW, height: cardH)   // background-size: 100% 100%
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                // Le SVG contient déjà la boîte blanche ; on n'overlaye que le code-barre.
                barcodeBox
                    .frame(width: cardW * 0.42, height: cardH * 0.22)
                    .position(x: cardW * 0.5, y: cardH * 0.56)
            }
    }

    private var barcodeBox: some View {
        VStack(spacing: 6) {
            if let number = cardNumber, let img = LoyaltyCard.barcode(from: number) {
                Image(uiImage: img)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Text(number)
                    .font(BrandFont.sans(11, weight: .medium).monospaced())
                    .foregroundStyle(Color.brandNavy)
            } else {
                Text("Aucune carte associée")
                    .font(BrandFont.sans(13))
                    .foregroundStyle(Color.brandTextMuted)
            }
        }
    }
}
