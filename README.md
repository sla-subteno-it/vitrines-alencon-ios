# Vitrines d'Alençon — iOS

Application iOS native pour [Les Vitrines d'Alençon](https://www.vitrines-alencon.fr) :
programme de cashback/fidélité et annuaire des commerçants du centre-ville d'Alençon.
Réplique native de la PWA, connectée **uniquement à Odoo**.

## Architecture

```
VitrinesiOS/VitrinesiOS/
├── VitrinesiOSApp.swift        # @main (init polices + OneSignal)
├── ContentView.swift           # Splash / Accueil public / MainTabView selon l'auth
└── Sources/
    ├── Network/                # OdooClient (JSON-RPC, auth, routes custom), config
    ├── Models/                 # Merchant, MerchantCoupon, RewardsTag…
    ├── Auth/                   # LoginView, inscription (CreateCard), activation, AuthViewModel
    ├── Accueil/                # Dashboard connecté + accueil public (non connecté)
    ├── Merchants/              # Annuaire (liste, filtres, marques, fiche détail, coupon)
    ├── BonsPlans/              # Offres/coupons actifs + expirés
    ├── Actualites/             # Blog (liste + article)
    ├── Notifications/          # Centre de notifications + PushManager + deep-link
    ├── MaCarte/                # Carte fidélité (code-barres), solde, historique, commerces
    ├── CarteCadeau/            # Scan carte cadeau (VisionKit) + solde/historique
    ├── Compte/                 # Infos perso, adresses, sécurité, préférences, suppression
    ├── Aide/                   # Aide / FAQ
    ├── Contact/                # Formulaire de contact
    └── Common/                 # MainTabView, Theme, cache carte, composants partagés
```

Patterns : SwiftUI + MVVM, `async/await`, `NavigationStack` (path par onglet),
`@StateObject` / `ObservableObject`.

## Stack technique

| Composant | Technologie |
|---|---|
| UI | SwiftUI |
| Cible de déploiement | iOS 26 (fonctionnalités iOS 17+) |
| Réseau | URLSession + JSON-RPC Odoo |
| Auth | Session cookie Odoo (persistée) |
| Push | OneSignal (SDK SPM) → APNs |
| Scan code-barres | VisionKit `DataScannerViewController` |
| Code-barres carte | CoreImage (Code128, généré localement) |
| Polices | Playfair Display + Montserrat (embarquées) |

## Dépendances

- **OneSignal iOS SDK** via Swift Package Manager
  (`https://github.com/OneSignal/OneSignal-iOS-SDK`, produit `OneSignalFramework`).
  Le code push est protégé par `#if canImport(OneSignalFramework)` : le projet
  compile même sans le package.

Aucune autre dépendance tierce.

## Backend

L'app communique **uniquement avec Odoo** ; Odoo orchestre Adelya (fidélité) en coulisses.

- **Base de données auto-détectée** via `/web/database/list` (une seule base par
  instance) — rien à coder en dur.
- Endpoints Odoo utilisés :
  - `/web/session/authenticate`, `/web/dataset/call_kw` (générique)
  - `/my/loyalty/history` *(custom)* — historique d'achats + commerces + solde
    (agrégé sur tous les partenaires liés au `cardnumber`, multi-sociétés)
  - `/onesignal/config`, `/onesignal/subscribe`, `/onesignal/unsubscribe`
  - `/scanner-carte-cadeau/scan` — scan/solde carte cadeau
  - `/website/form/mail.mail` — formulaire de contact
  - `/web/signup`, `/activer-mon-compte`, `/my/account`, `/my/security`,
    `/ma-carte` (préférences), `/my/deactivate_account` (suppression de compte)
  - `/.well-known/apple-app-site-association` (AutoFill mot de passe)

## Environnements

- **Release** → production `https://www.vitrines-alencon.fr`.
- **Debug** → staging `https://staging.vitrines-alencon.fr`, avec un **sélecteur
  Staging/Production** sur l'écran de connexion (persisté).

## Prérequis

- Xcode 16+
- **Compte Apple Developer payant** requis pour : Push Notifications, Associated
  Domains (AutoFill), build device au-delà de 7 jours, TestFlight.
  (Un compte personnel gratuit permet de tester en local, sans push ni AutoFill.)

## Démarrage rapide

```bash
git clone https://github.com/sla-subteno-it/vitrines-alencon-ios.git
cd vitrines-alencon-ios
open VitrinesiOS/VitrinesiOS.xcodeproj
```

Xcode résout automatiquement le package OneSignal. Build : ⌘R.

## Fonctionnalités

- [x] Accueil public (non connecté) + connexion / inscription / activation
- [x] Dashboard d'accueil connecté
- [x] Annuaire commerçants (recherche, filtres, marques, fiche détail, avis)
- [x] Bons plans (actifs / durée limitée / terminés) + détail + compte à rebours
- [x] Actualités (blog)
- [x] Notifications (liste, filtres, ouverture du contenu)
- [x] Ma Carte : carte fidélité + **code-barres hors-ligne**, solde, historique
- [x] Carte cadeau : scan code-barres, solde, historique
- [x] Mon Compte : infos perso, adresses, sécurité, préférences de communication
- [x] Suppression de compte in-app + liens légaux (confidentialité, mentions)
- [x] Mode hors-ligne (session persistée + carte en cache)
- [x] Accessibilité : Dynamic Type + VoiceOver
- [~] Notifications push (OneSignal) + deep-link — *prêt, en attente du compte Apple*
- [~] AutoFill mot de passe (Associated Domains) — *prêt, en attente du compte Apple*

## Documentation complémentaire

- `PUSH_ONESIGNAL.md` — mise en place des notifications push (APNs, dashboard).
- `ASSOCIATED_DOMAINS.md` — AutoFill mot de passe (entitlements + AASA serveur).
- `apple-app-site-association` — fichier de référence à servir côté Odoo.

## Développé par

[Subteno IT](https://www.subteno.com) — Partenaire Odoo
pour [Les Vitrines d'Alençon](https://www.vitrines-alencon.fr).
