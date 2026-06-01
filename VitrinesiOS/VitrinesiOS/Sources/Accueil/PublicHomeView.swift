// PublicHomeView.swift
// Vitrines d'Alençon — iOS
// Page d'accueil publique (utilisateur non connecté) — réplique de /mobile-menu
// dans sa variante `is_public`.

import SwiftUI
import Combine

@MainActor
final class PublicHomeViewModel: ObservableObject {
    @Published var merchantCount: Int?
    @Published var fidelityCount: Int?
    @Published var giftCount: Int?

    private let client = OdooClient.shared

    /// Récupère les compteurs depuis la page publique /mobile-menu (HTML).
    func loadCounts() async {
        guard let data = try? await client.get(path: "/mobile-menu"),
              let html = String(data: data, encoding: .utf8) else { return }

        // Bloc KPI : <a ... o_mobile_home_kpi ...><strong>NN</strong><span>label</span></a>
        let pattern = #"o_mobile_home_kpi[\s\S]*?<strong[^>]*>\s*(\d+)\s*</strong>[\s\S]*?<span>\s*([^<]+?)\s*</span>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let range = NSRange(html.startIndex..., in: html)
        for match in regex.matches(in: html, range: range) {
            guard match.numberOfRanges > 2,
                  let nRange = Range(match.range(at: 1), in: html),
                  let lRange = Range(match.range(at: 2), in: html),
                  let value = Int(html[nRange]) else { continue }
            let label = html[lRange].lowercased()
            if label.contains("commerce") { merchantCount = value }
            else if label.contains("fidélit") || label.contains("fidelit") { fidelityCount = value }
            else if label.contains("cadeau") { giftCount = value }
        }
    }
}

struct PublicHomeView: View {
    @StateObject private var vm = PublicHomeViewModel()
    @State private var showLogin = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    loginPill
                    hero
                    if hasCounts { kpis; Divider() }
                    faqLinks
                    actionGrid
                }
                .padding(20)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemBackground))
            .task { await vm.loadCounts() }
        }
        .fullScreenCover(isPresented: $showLogin) {
            NavigationStack {
                LoginView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Fermer") { showLogin = false }
                        }
                    }
            }
        }
    }

    // MARK: - Se connecter

    private var loginPill: some View {
        HStack {
            Spacer()
            Button { showLogin = true } label: {
                Text("Se connecter")
                    .font(BrandFont.sans(15, weight: .semibold))
                    .foregroundStyle(Color.brandNavy)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .overlay(Capsule().stroke(Color.brandNavy.opacity(0.4), lineWidth: 1))
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                (Text("Les ").foregroundColor(Color.brandNavy)
                 + Text("Vitrines d'Alençon").foregroundColor(Color.brandRed)
                 + Text("…").foregroundColor(Color.brandNavy))
                    .font(BrandFont.serif(28, weight: .bold))
                Text("…ne font pas que de la dentelle.")
                    .font(BrandFont.serif(24, weight: .semibold))
                    .italic()
                    .foregroundColor(Color.brandNavy)
                Text("Elles récompensent vos achats.")
                    .font(BrandFont.serif(24, weight: .bold))
                    .italic()
                    .underline()
                    .foregroundColor(Color.brandNavy)
            }
            .fixedSize(horizontal: false, vertical: true)

            Text("Retrouvez les animations du centre-ville, les actualités des commerces, les bons plans, votre carte fidélité et la carte cadeau locale pour acheter, cumuler et profiter chez les commerces adhérents à la carte.")
                .font(BrandFont.sans(16))
                .foregroundStyle(Color.brandTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - KPIs

    private var hasCounts: Bool {
        vm.merchantCount != nil || vm.fidelityCount != nil || vm.giftCount != nil
    }

    private var kpis: some View {
        HStack(spacing: 0) {
            kpi(vm.merchantCount, "Commerces")
            kpiSep
            kpi(vm.fidelityCount, "Fidélités")
            kpiSep
            kpi(vm.giftCount, "Cartes cadeaux")
        }
    }

    private func kpi(_ value: Int?, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value.map(String.init) ?? "—")
                .font(BrandFont.serif(26, weight: .bold))
                .foregroundStyle(Color.brandNavy)
            Text(label.uppercased())
                .font(BrandFont.sans(11, weight: .semibold))
                .foregroundStyle(Color.brandTextMuted)
                .tracking(0.5)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var kpiSep: some View {
        Rectangle()
            .fill(Color.brandHairline)
            .frame(width: 1, height: 36)
    }

    // MARK: - Liens FAQ

    private var faqLinks: some View {
        VStack(spacing: 10) {
            faqLink("Comment fonctionne la carte fidélité ?", target: .fidelity)
            faqLink("Où utiliser la carte cadeau ?", target: .giftcard)
            faqLink("Comment activer mon compte ?", target: .activation)
        }
    }

    private func faqLink(_ title: String, target: AideFaqView.Target) -> some View {
        NavigationLink { AideFaqView(initialTarget: target) } label: {
            HStack {
                Text(title)
                    .font(BrandFont.serif(17))
                    .foregroundStyle(Color.brandNavy)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Color.brandSurface, in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Cartes d'action

    private var actionGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            NavigationLink { CreateCardView() } label: {
                ActionCard(icon: "person.badge.plus", title: "Créer ma carte", subtitle: "Nouveau profil")
            }.buttonStyle(.plain)

            NavigationLink { ActivateAccountView() } label: {
                ActionCard(icon: "key", title: "Activer mon compte", subtitle: "Carte existante")
            }.buttonStyle(.plain)

            NavigationLink { AideFaqView() } label: {
                ActionCard(icon: "lightbulb", title: "Comment ça marche ?", subtitle: "Guide rapide")
            }.buttonStyle(.plain)

            NavigationLink { ContactView() } label: {
                ActionCard(icon: "envelope", title: "Contactez-nous", subtitle: "Nous écrire")
            }.buttonStyle(.plain)
        }
    }
}

private struct ActionCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Color.brandNavy)
                .frame(height: 80)
            VStack(spacing: 4) {
                Text(title)
                    .font(BrandFont.serif(19, weight: .bold))
                    .foregroundStyle(Color.brandNavy)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(BrandFont.sans(14))
                    .foregroundStyle(Color.brandTextMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 12)
        .background(Color.brandSurface, in: .rect(cornerRadius: 16))
    }
}
