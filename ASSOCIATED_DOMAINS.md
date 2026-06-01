# AutoFill mot de passe — Associated Domains

Pour qu'iOS **génère, remplisse et enregistre automatiquement** un mot de passe
fort (comme dans les autres apps), il faut deux choses :

## 1. Côté app (✅ fait)

- Entitlement `com.apple.developer.associated-domains` (`VitrinesiOS.entitlements`) :
  - `webcredentials:www.vitrines-alencon.fr`
  - `webcredentials:vitrines-alencon.fr`
- Champs mot de passe en `textContentType = .newPassword` + `passwordRules`
  (`NewPasswordField`), champ email en identifiant de compte.

> ⚠️ Au premier build **sur appareil**, Xcode (signature automatique, équipe
> `TTF2YC5Q54`) doit activer la capability *Associated Domains* sur l'App ID
> `fr.vitrines-alencon.VitrinesiOS`. Si Xcode affiche une erreur de
> provisioning, ouvrir l'onglet *Signing & Capabilities* et laisser Xcode
> corriger, ou activer *Associated Domains* dans le portail développeur.

## 2. Côté serveur (à faire)

Servir le fichier `apple-app-site-association` (sans extension) sur les deux
domaines, en **HTTPS**, **Content-Type `application/json`**, **sans redirection** :

- `https://www.vitrines-alencon.fr/.well-known/apple-app-site-association`
- `https://vitrines-alencon.fr/.well-known/apple-app-site-association`

Contenu (voir le fichier `apple-app-site-association` à la racine du repo) :

```json
{
  "webcredentials": {
    "apps": ["TTF2YC5Q54.fr.vitrines-alencon.VitrinesiOS"]
  }
}
```

Le préfixe `TTF2YC5Q54` est le Team ID Apple ; `fr.vitrines-alencon.VitrinesiOS`
le bundle identifier.

### Exemple de route Odoo (module `adelya_connector`)

```python
import json
from odoo import http
from odoo.http import request

class AppleAASA(http.Controller):
    @http.route('/.well-known/apple-app-site-association',
                type='http', auth='public', methods=['GET'], csrf=False)
    def aasa(self):
        payload = {
            "webcredentials": {
                "apps": ["TTF2YC5Q54.fr.vitrines-alencon.VitrinesiOS"]
            }
        }
        return request.make_response(
            json.dumps(payload),
            headers=[('Content-Type', 'application/json')],
        )
```

## Vérification

Une fois déployé :

```
curl -i https://www.vitrines-alencon.fr/.well-known/apple-app-site-association
```

→ doit renvoyer `200`, `Content-Type: application/json`, et le JSON ci-dessus
(pas de redirection 301/302).
