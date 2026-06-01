# Vitrines d'Alençon — iOS

Application iOS native du programme de cashback et annuaire commerçants de la ville d'Alençon (61).

## Contexte métier

- **Programme Adelya** : programme fidélité/cashback géré par Adelya (SaaS tiers)
- **Backend unique : Odoo** (`https://www.vitrines-alencon.fr`) — l'app iOS ne parle qu'à Odoo
- Odoo orchestre Adelya en coulisses via son module custom (`adelya.api`)
- Les commerçants sont des `res.partner` avec `api_unique_id` (identifiant Adelya)
- Aucun appel direct vers l'API Adelya depuis l'app

## Architecture

```
VitrinesiOS/VitrinesiOS/
├── VitrinesiOSApp.swift          # @main — point d'entrée
├── ContentView.swift             # Remplacé par MainTabView
└── Sources/
    ├── Network/
    │   └── OdooClient.swift      # Client JSON-RPC Odoo (auth, call<T>, imageURL)
    ├── Models/
    │   └── MerchantModels.swift  # Merchant, RewardsTag, MerchantCoupon, MerchantFilters…
    ├── Merchants/
    │   ├── MerchantService.swift      # Requêtes Odoo (fetchMerchants, fetchTags, fetchReviews…)
    │   ├── MerchantViewModel.swift    # MerchantsViewModel + MerchantDetailViewModel
    │   ├── MerchantsListView.swift    # Liste + recherche + filtres tags
    │   ├── MerchantCardView.swift     # Carte commerçant (thumbnail, badges, accroche)
    │   ├── MerchantFilterView.swift   # Sheet filtres (tags, carte cadeau/fidélité)
    │   └── MerchantDetailView.swift   # Fiche détail (hero, infos, coupons, avis, favori)
    ├── Common/
    │   └── MainTabView.swift          # TabBar 5 onglets
    ├── Auth/                          # À implémenter (login Odoo → session cookie)
    ├── MaCarte/                       # À implémenter (carte fidélité, solde points)
    ├── BonsPlans/                     # À implémenter (local.rewards.offer actives)
    ├── Jeux/                          # À implémenter (quizz/jeux Adelya)
    └── Notifications/                 # À implémenter (APNs → Odoo)
```

## Modèles Odoo clés

| Modèle Odoo | Usage iOS |
|---|---|
| `res.partner` | Commerçants (`is_company=True`, `api_unique_id != False`) |
| `local.rewards.tag` | Catégories commerçants (Mode, Restauration…) |
| `merchant.reference` | Enseignes/marques (Zara, Sephora…) |
| `merchant.reference.tag` | Catégories produits |
| `local.rewards.offer` | Coupons/offres actives |
| `local.rewards.event` | Avis clients (type=`Quizz_Session`) |
| `adelya.api` | Pont vers Adelya (toggleFavorite, submitReview…) |

## Conventions réseau

- `OdooClient.call<T>(model:method:args:kwargs:)` — appel JSON-RPC générique typé
- `OdooClient.imageURL(model:recordId:field:)` — URL image Odoo (ex: `/web/image/res.partner/42/image_1920`)
- `Merchant.imageURL` — propriété calculée : image Odoo si `hasImage`, sinon `defaultImageUrl` Adelya
- Session Odoo gérée via cookie `session_id` dans `HTTPCookieStorage.shared`
- `OdooSession` est un `actor` (thread-safe)
- Odoo renvoie `false` (JSON) pour les champs Many2many vides — décodage custom dans `init(from:)`

## Patterns SwiftUI utilisés

- `@StateObject` / `@ObservedObject` + `ObservableObject` (pas encore Observation framework)
- `async/await` avec `.task {}` et `.refreshable {}`
- `NavigationStack` + `NavigationLink(value:)` + `navigationDestination(for:)`
- `ContentUnavailableView` pour les états vides/erreur
- `AsyncImage` pour les photos commerçants

## Onglets TabBar (dans l'ordre)

1. **Ma Carte** — Carte fidélité, solde de points, historique transactions
2. **Commerçants** — Annuaire avec recherche, filtres, fiches détail
3. **Bons Plans** — Offres et coupons actifs (`local.rewards.offer`)
4. **Jeux** — Quizz et jeux Adelya pour gagner des points
5. **Mon Compte** — Profil, paramètres, déconnexion

## Règles de développement

- Pas de mocking réseau — toujours cibler `https://www.vitrines-alencon.fr`
- iOS 17+ minimum (pour `ContentUnavailableView`, `.onChange(of:_:_:)` nouveau style)
- Swift 5.9+ / Xcode 15+
- Accentuer en rouge/ambre la marque Vitrines d'Alençon (couleurs à définir dans Assets)
- Pas de dépendances tierces (SPM) sauf si absolument nécessaire
