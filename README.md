# Vitrines d'Alençon — iOS

Application iOS native pour [Les Vitrines d'Alençon](https://www.vitrines-alencon.fr), programme de cashback et annuaire des commerçants du centre-ville d'Alençon.

## Architecture

```
VitrinesiOS/
├── Sources/
│   ├── Network/          # OdooClient (JSON-RPC), couche HTTP unique
│   ├── Models/           # Structures Swift (Merchant, RewardsTag, Coupon...)
│   ├── Auth/             # Connexion / Inscription / Mon Compte
│   ├── Merchants/        # Annuaire commerçants + fiche détail
│   ├── MaCarte/          # Cagnotte, historique, carte fidélité QR
│   ├── BonsPlans/        # Offres et coupons actifs
│   ├── Jeux/             # Jeux interactifs (quiz, chasse au trésor)
│   ├── Notifications/    # Centre de notifications in-app + APNs
│   └── Common/           # Composants UI réutilisables
├── Resources/
│   └── Assets.xcassets
└── Preview Content/
```

## Stack technique

| Composant | Technologie |
|---|---|
| UI | SwiftUI (iOS 16+) |
| Réseau | URLSession + JSON-RPC Odoo |
| Auth | Session cookie Odoo |
| Push | APNs natif |
| QR Scanner | AVFoundation |
| Architecture | MVVM + async/await |

## Backend

L'app iOS communique **uniquement avec Odoo** (`https://www.vitrines-alencon.fr`).  
Odoo gère la connexion à Adelya (programme de fidélité) en coulisses.

## Prérequis

- Xcode 15+
- iOS 16+ (cible de déploiement)
- Compte Apple Developer (pour déploiement device réel)

## Démarrage rapide

```bash
git clone https://github.com/sla-subteno-it/vitrines-alencon-ios.git
cd vitrines-alencon-ios
open VitrinesiOS.xcodeproj
```

## Modules développés

- [x] Couche réseau Odoo (OdooClient)
- [x] Modèles de données (Merchant, RewardsTag...)
- [x] Service commerçants (MerchantService)
- [x] ViewModel commerçants (MerchantsViewModel, MerchantDetailViewModel)
- [ ] Vue liste commerçants (SwiftUI)
- [ ] Vue fiche détail commerçant (SwiftUI)
- [ ] Authentification
- [ ] Ma Carte / Cagnotte
- [ ] Bons Plans
- [ ] Jeux Interactifs
- [ ] Notifications Push

## Développé par

[Subteno IT](https://www.subteno.com) — Partenaire Odoo Silver  
Pour [Les Vitrines d'Alençon](https://www.vitrines-alencon.fr)
