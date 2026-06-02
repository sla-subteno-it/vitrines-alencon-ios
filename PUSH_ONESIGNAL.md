# Notifications push — OneSignal

L'app iOS utilise le **même projet OneSignal que le PWA**.

- **App ID OneSignal** : `e79881b6-f5eb-462c-b971-11a59d7bdd83`
- **Bundle iOS** : `fr.vitrines-alencon.VitrinesiOS` — **Team** : `TTF2YC5Q54`
- Le backend Odoo (`vda_onesignal`) gère l'envoi via l'API REST OneSignal et
  expose :
  - `GET /onesignal/config` → app_id, etc.
  - `POST /onesignal/subscribe` → `{ "player_id": "...", "device_type": "ios" }`
    (lie l'abonnement au partenaire si session connectée)
  - `POST /onesignal/unsubscribe` → `{ "player_id": "..." }`

## Côté app (✅ déjà codé)

- `PushManager` (`Sources/Notifications/PushManager.swift`) : init OneSignal,
  demande de permission, observation de l'ID d'abonnement, enregistrement Odoo.
  → Protégé par `#if canImport(OneSignalFramework)` : le projet compile **avant**
  l'ajout du SDK (stubs no-op).
- Init au lancement (`VitrinesiOSApp`), enregistrement après login / au
  démarrage si déjà connecté, désenregistrement à la déconnexion (`AuthViewModel`).
- Réseau Odoo : `OdooClient.registerPushPlayer` / `unregisterPushPlayer`.
- Entitlements `aps-environment` : `development` (Debug) / `production` (Release).

## Étapes manuelles restantes

### 1. Ajouter le SDK OneSignal (Xcode → SPM)

`File > Add Package Dependencies…` →
`https://github.com/OneSignal/OneSignal-iOS-SDK`
→ ajouter le produit **`OneSignalFramework`** à la cible **VitrinesiOS**.

Dès que le package est résolu, `canImport(OneSignalFramework)` devient vrai et le
code OneSignal s'active automatiquement (rien d'autre à toucher).

> Optionnel (plus tard) : une *Notification Service Extension* + produit
> `OneSignalExtension` + App Group pour les notifications riches, badges et
> « confirmed delivery ».

### 2. Capabilities Xcode (cible VitrinesiOS → Signing & Capabilities)

- **Push Notifications** (correspond à `aps-environment`, déjà dans les
  entitlements — Xcode doit activer la capability sur l'App ID en signature
  automatique).
- *(Optionnel)* **Background Modes → Remote notifications** (pour les pushes
  silencieux / confirmed delivery).

### 3. Clé APNs + dashboard OneSignal

1. **Apple Developer → Certificates, IDs & Profiles → Keys** : créer une **APNs
   Auth Key (.p8)** (activer *Apple Push Notifications service*). Noter le
   **Key ID** et le **Team ID** (`TTF2YC5Q54`).
2. **OneSignal → Settings → Push & In-App → Apple iOS (APNs)** : configurer la
   plateforme iOS, uploader le **.p8**, renseigner Key ID, Team ID et Bundle ID
   `fr.vitrines-alencon.VitrinesiOS`.

### 4. Test sur appareil réel (les pushes ne marchent pas sur simulateur)

1. Build **Debug** sur l'iPhone.
2. Se connecter → accepter la demande de notifications → l'app envoie son
   `player_id` à `/onesignal/subscribe` (lié au partenaire).
3. Vérifier dans **OneSignal → Audience → Subscriptions** que l'appareil iOS
   apparaît, et dans Odoo (`onesignal.subscription`) que l'abonnement est créé.
4. Envoyer un test depuis le dashboard OneSignal, ou publier un bon plan /
   une notification dans Odoo.

## Notes

- Le SDK lit l'App ID en dur (`PushConfig.oneSignalAppID`) — identique à celui
  exposé par `/onesignal/config`.
- L'enregistrement est rejoué à chaque login pour (re)lier l'abonnement au bon
  partenaire ; il est désactivé à la déconnexion.
