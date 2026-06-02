// DeepLinkRouter.swift
// Vitrines d'Alençon — iOS
// Routage au tap d'une notification push : ouvre directement le bon plan,
// l'article ou le commerce concerné.

import Foundation
import Combine

enum DeepLink: Identifiable, Hashable {
    case coupon(Int)
    case merchant(Int)
    case blog(Int)

    var id: String {
        switch self {
        case .coupon(let i):   return "c\(i)"
        case .merchant(let i): return "m\(i)"
        case .blog(let i):     return "b\(i)"
        }
    }
}

@MainActor
final class DeepLinkRouter: ObservableObject {
    static let shared = DeepLinkRouter()
    private init() {}

    /// Lien en attente d'affichage (observé par MainTabView).
    @Published var pending: DeepLink?

    /// Appelé au tap d'une notification OneSignal.
    func handle(additionalData: [AnyHashable: Any]?, launchURL: String?) {
        if let data = additionalData, let link = Self.parse(data: data) {
            pending = link
        } else if let url = launchURL, let link = Self.parse(url: url) {
            pending = link
        }
    }

    /// Données structurées envoyées par Odoo (res_model + res_id).
    static func parse(data: [AnyHashable: Any]) -> DeepLink? {
        let resId = intValue(data["res_id"]) ?? intValue(data["id"])

        if let model = data["res_model"] as? String, let id = resId {
            switch model {
            case "local.rewards.offer": return .coupon(id)
            case "blog.post":           return .blog(id)
            case "res.partner":         return .merchant(id)
            default: break
            }
        }
        if let type = (data["type"] as? String)?.lowercased(), let id = resId {
            switch type {
            case "coupon", "offer", "bon_plan":     return .coupon(id)
            case "blog", "actualite", "actualité":  return .blog(id)
            case "merchant", "commerce", "partner": return .merchant(id)
            default: break
            }
        }
        // Repli : une éventuelle URL dans les données.
        if let url = data["url"] as? String { return parse(url: url) }
        return nil
    }

    /// Repli : parse l'URL (ex. /bons-plans/31).
    static func parse(url: String) -> DeepLink? {
        guard let comps = URLComponents(string: url) else { return nil }
        let parts = comps.path.split(separator: "/").map(String.init)
        guard parts.count >= 2 else { return nil }
        if parts[0] == "bons-plans", let id = Int(parts[1]) { return .coupon(id) }
        // blog / merchants utilisent des slugs → pas d'id fiable dans l'URL.
        return nil
    }

    private static func intValue(_ any: Any?) -> Int? {
        if let i = any as? Int { return i }
        if let s = any as? String { return Int(s) }
        if let d = any as? Double { return Int(d) }
        return nil
    }
}
