# Activation Apple — Push + AutoFill + Wallet

Checklist unique à dérouler **une fois le compte Apple Developer payant validé**
(association *Les Vitrines d'Alençon*). Trois fonctionnalités sont **déjà codées
et prêtes**, désactivées par des réglages/entitlements — il « suffit » de les
brancher.

> 🔑 **Prérequis** : compte Apple Developer Program payant actif → récupérer le
> **Team ID** (10 caractères, `developer.apple.com` → *Membership*).
> **Transmettre ce Team ID** : il se propage partout (signature, AASA, Wallet, APNs).

---

## 0. Étape commune — signature & équipe (Xcode)

1. Xcode → *Settings → Accounts* : ajouter le compte Apple de l'association.
2. Cible **VitrinesiOS** → *Signing & Capabilities* : sélectionner la **nouvelle
   équipe** (remplace le « Personal Team »).
3. Mettre à jour `DEVELOPMENT_TEAM` dans `project.pbxproj`
   (actuellement `TTF2YC5Q54` = équipe perso → nouveau Team ID).
4. **Réactiver les entitlements** (retirés pour le compte perso) :
   - Décommenter le contenu de `VitrinesiOS/VitrinesiOS.entitlements` (Release :
     `aps-environment = production` + `associated-domains`) et
     `VitrinesiOS/VitrinesiOS.Debug.entitlements` (Debug : `development` +
     `…?mode=developer`).
   - Re-ajouter `CODE_SIGN_ENTITLEMENTS` dans `project.pbxproj` (Debug →
     `VitrinesiOS.Debug.entitlements`, Release → `VitrinesiOS.entitlements`).
   - Ajouter les capabilities **Push Notifications** et **Associated Domains**
     via *+ Capability* (Xcode les enregistre sur l'App ID).

---

## 1. 🔔 Notifications push (OneSignal)

**App** : déjà fait (SDK, `PushManager`, enregistrement du player_id, deep-link).
App ID OneSignal en dur : `e79881b6-f5eb-462c-b971-11a59d7bdd83`.

**À faire :**
1. **Apple** : créer une **clé APNs (.p8)** (*Keys* → Apple Push Notifications) →
   noter **Key ID** + **Team ID**.
2. **OneSignal** (dashboard de l'app) → *Settings → Push & In-App → Apple iOS
   (APNs)* : uploader le **.p8**, renseigner Key ID, Team ID, Bundle ID
   `fr.vitrines-alencon.VitrinesiOS`.
3. **Backend** : merger + déployer
   - `feat/push-additional-data` → **master** (prod)
   - `deploy/push-data-staging` → **staging**
   (envoi de `additionalData` pour le deep-link au tap).
4. Test device : login → accepter les notifications → vérifier l'abonnement dans
   OneSignal (*Audience*) et dans Odoo (`onesignal.subscription`).

Détails : `PUSH_ONESIGNAL.md`.

---

## 2. 🔐 AutoFill mot de passe (Associated Domains)

**App** : déjà fait (champs `.newPassword` + entitlement à réactiver, cf. §0).

**À faire :**
1. Entitlement `associated-domains` réactivé (§0) — capability sur l'App ID.
2. **AASA serveur** : le fichier `/.well-known/apple-app-site-association` doit
   contenir le **bon Team ID** :
   ```json
   { "webcredentials": { "apps": ["<NOUVEAU_TEAM_ID>.fr.vitrines-alencon.VitrinesiOS"] } }
   ```
   - ⚠️ Actuellement servi avec `TTF2YC5Q54` (équipe perso) → **mettre à jour le
     préfixe** avec le nouveau Team ID dans la route Odoo
     (`adelya_connector/controllers/webmanifest.py`) et **redéployer** (prod
     **et** staging si test sur staging).
3. Test device : **réinstaller** l'app (iOS met l'AASA en cache) → à l'inscription,
   iOS propose « Mot de passe fort » et propose de l'enregistrer.

Détails : `ASSOCIATED_DOMAINS.md` + `apple-app-site-association`.

---

## 3. 🎟️ Apple Wallet (carte de fidélité)

**App** : déjà fait (bouton « Ajouter à Apple Wallet », `AppleWalletButton.swift`).
**Backend** : module `vda_wallet` prêt (génération + signature + images + endpoint).

**À faire :**
1. **Apple** : créer un **Pass Type ID** (`pass.fr.vitrines-alencon.fidelite`) +
   son **certificat** (CSR → .cer → .p12 → PEM), récupérer le **WWDR**.
   *(Procédure détaillée dans `custom/vda_wallet/README.md` du backend.)*
2. **Odoo** : renseigner les **paramètres système** (`vda_wallet_pass_type_id`,
   `vda_wallet_team_id`, `vda_wallet_cert_pem`, `vda_wallet_key_pem`,
   `vda_wallet_wwdr_pem`…). Images déjà fournies dans le module.
3. **Backend** : merger + déployer + **installer le module** `vda_wallet`
   - `feat/apple-wallet` → **master** (prod)
   - `deploy/apple-wallet-staging` → **staging**
4. **App** : passer **`WalletConfig.enabled = true`** (`AppleWalletButton.swift`),
   rebuild → le bouton apparaît sur Ma Carte.
5. Test device : Ma Carte → « Ajouter à Apple Wallet » → le pass s'ajoute.

⚠️ La **signature** n'a jamais pu être testée sur un vrai certificat : valider à
l'activation (un pass mal signé est refusé par Wallet).

---

## 4. Récap — réglages à modifier dans l'app

| Fichier | Modification |
|---|---|
| `project.pbxproj` | `DEVELOPMENT_TEAM` = nouveau Team ID ; ré-ajouter `CODE_SIGN_ENTITLEMENTS` (Debug/Release) |
| `VitrinesiOS.entitlements` / `.Debug.entitlements` | décommenter `aps-environment` + `associated-domains` |
| `AppleWalletButton.swift` | `WalletConfig.enabled = true` |

(L'App ID OneSignal est déjà correct ; rien à changer dans `PushConfig`.)

## 5. Récap — branches backend à merger/déployer

| Branche | Base | Sujet |
|---|---|---|
| `feat/push-additional-data` | master | Push deep-link |
| `deploy/push-data-staging` | staging | Push deep-link |
| `feat/apple-wallet` | master | Apple Wallet |
| `deploy/apple-wallet-staging` | staging | Apple Wallet |
| *(AASA : déjà en prod ; vérifier sur staging + Team ID)* | — | AutoFill |

## 6. Bonus une fois actif
- **TestFlight** : distribution bêta sans Mac (compte payant requis).
- **Mise à jour du solde dans Wallet** : web service de passes + APNs Wallet
  (évolution, cf. README `vda_wallet`).

---

> 📌 Le jour J : transmettre le **Team ID**, puis dérouler §0 → §3. Je peux
> appliquer automatiquement les modifs app (§4) et préparer les redéploiements.
