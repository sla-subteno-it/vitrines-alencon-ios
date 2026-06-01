// MainTabView.swift
// Vitrines d'Alençon — iOS
// TabBar personnalisée 6 onglets (réplique de la PWA) :
// Accueil · Commerces · Bons Plans · Actualités · Notifications · Mon Compte.
// TabBar custom car le TabView natif plafonne à 5 onglets (le 6e devient « More »).

import SwiftUI

struct MainTabView: View {
    @State private var selected: Tab = .accueil
    @State private var visited: Set<Tab> = [.accueil]

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
        case .accueil:   ComingSoonTab(title: "Accueil", icon: "house",
                                       message: "Votre tableau de bord personnalisé.")
        case .merchants: MerchantsListView()
        case .deals:     BonsPlansListView()
        case .news:      ActualitesView()
        case .notifs:    ComingSoonTab(title: "Notifications", icon: "bell",
                                       message: "Vos notifications apparaîtront ici.")
        case .account:   MonCompteView()
        }
    }

    private var tabBar: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Tab.allCases) { tab in
                let isSelected = selected == tab
                Button {
                    selected = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                            .symbolVariant(isSelected ? .fill : .none)
                        Text(tab.label)
                            .font(BrandFont.sans(10, weight: isSelected ? .semibold : .regular))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(isSelected ? Color.brandNavy : Color.brandTextMuted)
                    .frame(maxWidth: .infinity)
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

// MARK: - Onglet placeholder « Bientôt disponible »

private struct ComingSoonTab: View {
    let title: String
    let icon: String
    let message: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label(title, systemImage: icon)
            } description: {
                Text(message + "\n\nBientôt disponible.")
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
