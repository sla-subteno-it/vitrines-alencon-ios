// Theme.swift
// Vitrines d'Alençon — iOS
// Palette de marque + polices, extraites de la PWA (www.vitrines-alencon.fr).

import SwiftUI
import CoreText

// MARK: - Couleurs de marque

extension Color {
    /// Navy primaire — titres, tags, liens, bouton recherche. PWA `--primary`.
    static let brandNavy      = Color(hex: 0x34586E)
    /// Navy foncé — fin de dégradé / états pressés. PWA `#2A4758`.
    static let brandNavyDark  = Color(hex: 0x2A4758)
    /// Vert secondaire de marque. PWA `--secondary` `#56675C`.
    static let brandGreen     = Color(hex: 0x56675C)
    /// Rouge accent — le compteur, les CTA, le badge cadeau. PWA `#B02E3C`.
    static let brandRed       = Color(hex: 0xB02E3C)
    /// Rouge foncé — fin de dégradé du badge. PWA `#8A232E`.
    static let brandRedDark   = Color(hex: 0x8A232E)
    /// Gris des textes secondaires. PWA `#6C757D`.
    static let brandTextMuted = Color(hex: 0x6C757D)
    /// Fond clair de page (début de dégradé). PWA `#F5F7FA`.
    static let brandSurface   = Color(hex: 0xF5F7FA)
    /// Fond clair de page (fin de dégradé). PWA `#E8ECF0`.
    static let brandSurface2  = Color(hex: 0xE8ECF0)
    /// Fond du footer de carte. PWA `#FAFBFC`.
    static let brandFooter    = Color(hex: 0xFAFBFC)
    /// Bordure légère. PWA `#F0F0F0`.
    static let brandHairline  = Color(hex: 0xF0F0F0)

    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8)  & 0xFF) / 255,
            blue:  Double( hex        & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Dégradés réutilisables

extension LinearGradient {
    static let brandNavy = LinearGradient(
        colors: [.brandNavy, .brandNavyDark],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let brandRed = LinearGradient(
        colors: [.brandRed, .brandRedDark],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let brandSurface = LinearGradient(
        colors: [.brandSurface, .brandSurface2],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

// MARK: - HTML → texte brut

extension String {
    /// Convertit un HTML simple (issu d'Odoo : <p>, <br>, entités) en texte lisible.
    /// Léger et sans dépendance — suffisant pour les descriptions de coupons.
    var htmlStripped: String {
        var s = self
        // Balises de bloc → saut de ligne
        for pattern in ["(?i)<br\\s*/?>", "(?i)</p>", "(?i)</div>", "(?i)</li>"] {
            s = s.replacingOccurrences(of: pattern, with: "\n", options: .regularExpression)
        }
        // Toutes les autres balises → supprimées
        s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        // Entités courantes
        let entities = ["&amp;": "&", "&lt;": "<", "&gt;": ">",
                        "&quot;": "\"", "&#39;": "'", "&apos;": "'", "&nbsp;": " "]
        for (k, v) in entities { s = s.replacingOccurrences(of: k, with: v) }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Polices (Playfair Display + Montserrat, comme la PWA)

enum BrandFont {
    static let serifName = "Playfair Display"  // titres
    static let sansName  = "Montserrat"        // corps

    /// Titre serif (Playfair Display). Retombe sur le serif système si absent.
    static func serif(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .custom(serifName, size: size).weight(weight)
    }

    /// Texte sans-serif (Montserrat). Retombe sur SF si absent.
    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(sansName, size: size).weight(weight)
    }

    /// Enregistre les polices embarquées (bundle) auprès du système.
    /// Nécessaire car le projet génère l'Info.plist (`GENERATE_INFOPLIST_FILE`)
    /// → pas de clé `UIAppFonts`, donc pas d'enregistrement automatique.
    static func registerEmbeddedFonts() {
        let names = ["PlayfairDisplay-Variable", "Montserrat-Variable"]
        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
                continue
            }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
