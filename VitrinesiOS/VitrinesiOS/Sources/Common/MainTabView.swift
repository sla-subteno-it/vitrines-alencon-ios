// MainTabView.swift
// Vitrines d'Alençon — iOS
// TabBar personnalisée 6 onglets (réplique de la PWA) :
// Accueil · Commerces · Bons Plans · Actualités · Notifications · Mon Compte.
// TabBar custom car le TabView natif plafonne à 5 onglets (le 6e devient « More »).

import SwiftUI

// MARK: - Métriques + réservation d'espace pour le tab bar custom

enum TabBarMetrics {
    /// Hauteur de la barre d'onglets (hors home indicator, déjà géré par le safe area système).
    static let height: CGFloat = 52
}

extension View {
    /// Réserve la hauteur du tab bar custom en bas d'un `ScrollView` pour que son
    /// contenu ne soit pas masqué par la barre. À appliquer sur le `ScrollView`
    /// racine de chaque page hébergée dans un onglet (root ou poussée).
    /// `safeAreaInset` appliqué directement au ScrollView insère son contenu de
    /// façon fiable, contrairement à un `safeAreaInset` posé hors du NavigationStack.
    func aboveTabBar() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: TabBarMetrics.height)
        }
    }
}

struct MainTabView: View {
    @State private var selected: Tab = .accueil
    @State private var visited: Set<Tab> = [.accueil]
    /// Incrémenté à chaque tap sur un bouton d'onglet pour réinitialiser sa pile
    /// de navigation (retour à la page racine, pas l'écran de détail précédent).
    @State private var resetCounters: [Tab: Int] = [:]

    enum Tab: Int, CaseIterable, Identifiable {
        case accueil, merchants, deals, news, notifs, account
        var id: Int { rawValue }

        var icon: String {
            switch self {
            case .accueil:   return "house"
            case .merchants: return "storefront"
            case .deals:     return "tag"
            case .news:      return "newspaper"
            case .notifs:    return "bell"
            case .account:   return "person"
            }
        }
        var label: String {
            switch self {
            case .accueil:   return "Accueil"
            case .merchants: return "Commerces"
            case .deals:     return "Bons Plans"
            case .news:      return "Actualités"
            case .notifs:    return "Notifications"
            case .account:   return "Mon Compte"
            }
        }
    }

    var body: some View {
        ZStack {
            // Onglets montés à la première visite puis gardés vivants (état préservé).
            ForEach(Tab.allCases) { tab in
                if visited.contains(tab) {
                    content(for: tab)
                        .id(resetCounters[tab, default: 0])
                        .opacity(tab == selected ? 1 : 0)
                        .allowsHitTesting(tab == selected)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { tabBar }
        .onChange(of: selected) { _, new in visited.insert(new) }
    }

    @ViewBuilder
    private func content(for tab: Tab) -> some View {
        switch tab {
        case .accueil:   AccueilView(selectTab: { selected = $0 })
        case .merchants: MerchantsListView()
        case .deals:     BonsPlansListView()
        case .news:      ActualitesView()
        case .notifs:    NotificationsView()
        case .account:   MonCompteView(selectTab: { selected = $0 })
        }
    }

    private var tabBar: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Tab.allCases) { tab in
                let isSelected = selected == tab
                Button {
                    // Tap sur un bouton d'onglet → revenir à la page racine de
                    // cet onglet (réinitialise sa pile de navigation).
                    resetCounters[tab, default: 0] += 1
                    selected = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                            .symbolVariant(isSelected ? .fill : .none)
                            .frame(height: 22)
                        Text(tab.label)
                            .font(BrandFont.sans(10, weight: isSelected ? .semibold : .regular))
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                            .allowsTightening(true)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .frame(height: 13)
                    }
                    .foregroundStyle(isSelected ? Color.brandNavy : Color.brandTextMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 1)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
        .padding(.horizontal, 4)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

