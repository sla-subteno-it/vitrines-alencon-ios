// AideFaqView.swift
// Vitrines d'Alençon — iOS
// Réplique de la page /aide (Comment ça marche ? — FAQ fidélité, activation,
// cartes cadeaux, installation). Ouverte depuis Mon Compte → « Aide / FAQ ».

import SwiftUI

struct AideFaqView: View {
    /// Section à afficher d'emblée (lien profond depuis l'accueil public).
    enum Target {
        case fidelity, activation, giftcard

        var anchor: String {
            switch self {
            case .fidelity:   return "section_fidelity"
            case .activation: return "section_activation"
            case .giftcard:   return "section_giftcard"
            }
        }
        /// Question à ouvrir automatiquement.
        var openId: String {
            switch self {
            case .fidelity:   return "f1"
            case .activation: return "a1"
            case .giftcard:   return "g4"
            }
        }
    }

    var initialTarget: Target? = nil

    /// Identifiant de la question actuellement ouverte (accordéon global, comme la PWA).
    @State private var openId: String?
    @Environment(\.openURL) private var openURL

    private let publicBase = "https://www.vitrines-alencon.fr"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    hero
                    quickActions
                    content
                }
            }
            .onAppear { scrollToTarget(proxy) }
        }
        .aboveTabBar()
        .background(Color(.systemBackground))
        .navigationTitle("Aide / FAQ")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func scrollToTarget(_ proxy: ScrollViewProxy) {
        guard let target = initialTarget else { return }
        openId = target.openId
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation { proxy.scrollTo(target.anchor, anchor: .top) }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 12) {
            Text("Faites-vous plaisir, on vous récompense 💕")
                .font(.callout.italic())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text("Comment ça marche ?")
                .font(BrandFont.serif(28, weight: .bold))
                .foregroundStyle(.white)
            HStack(spacing: 24) {
                Label("Carte de fidélité", systemImage: "creditcard.fill")
                    .foregroundStyle(.white)
                Label("Cartes cadeaux", systemImage: "gift.fill")
                    .foregroundStyle(.white)
            }
            .font(.footnote)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
        .background(
            LinearGradient(colors: [Color(hex: 0x3D5A6C), Color(hex: 0x4A6B7C)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    }

    // MARK: - Actions rapides

    private var quickActions: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                QuickAction(icon: "person.badge.plus", tint: Color(hex: 0x1976D2),
                            bg: Color(hex: 0xE3F2FD), title: "S'inscrire") {
                    open("/web/signup")
                }
                QuickAction(icon: "lock.open", tint: Color(hex: 0x388E3C),
                            bg: Color(hex: 0xE8F5E9), title: "Activer mon compte") {
                    open("/activer-mon-compte")
                }
                NavigationLink {
                    CarteCadeauView()
                } label: {
                    QuickActionLabel(icon: "qrcode", tint: Color(hex: 0xD32F2F),
                                     bg: Color(hex: 0xFFEBEE), title: "Scanner carte cadeau")
                }
                .buttonStyle(.plain)
                QuickAction(icon: "tag.fill", tint: Color(hex: 0xF57C00),
                            bg: Color(hex: 0xFFF3E0), title: "Bons plans") {
                    open("/bons-plans")
                }
            }

            Button {
                open("/merchants")
            } label: {
                Label("Découvrir nos commerçants", systemImage: "building.2.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [Color(hex: 0x546E7A), Color(hex: 0x37474F)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: .rect(cornerRadius: 12)
                    )
            }
        }
        .padding(16)
        .background(Color(hex: 0xF8F9FA))
    }

    // MARK: - Contenu FAQ

    private var content: some View {
        VStack(spacing: 28) {
            fidelitySection.id(Target.fidelity.anchor)
            activationSection.id(Target.activation.anchor)
            giftCardSection.id(Target.giftcard.anchor)
            installSection
            contactSection
        }
        .padding(16)
        .frame(maxWidth: 600)
    }

    // MARK: Section 1 — Carte de fidélité

    private var fidelitySection: some View {
        FaqSection(icon: "creditcard.fill", tint: Color(hex: 0x1976D2),
                   bg: Color(hex: 0xE3F2FD), title: "La carte de fidélité") {
            faqRow("f1", "Qu'est-ce que la carte de fidélité ?") {
                VStack(alignment: .leading, spacing: 10) {
                    answerText("La carte de fidélité Les Vitrines d'Alençon est un programme **100% gratuit** qui vous permet de cumuler des points lors de vos achats chez les commerçants partenaires du centre-ville.")
                    answerText("Ces points se transforment ensuite en **bons d'achat** à utiliser dans les commerces participants !")
                }
            }
            faqRow("f2", "Comment obtenir ma carte ?") {
                VStack(alignment: .leading, spacing: 10) {
                    AnswerOption(icon: "iphone", title: "En ligne",
                                 text: "Créez votre compte en 2 minutes sur notre site. Votre carte sera automatiquement créée.") {
                        ActionButton(title: "S'inscrire maintenant") { open("/web/signup") }
                    }
                    AnswerOption(icon: "bag", title: "En boutique",
                                 text: "Demandez votre carte directement chez un commerçant partenaire lors de votre achat.")
                }
            }
            faqRow("f3", "Quels sont les avantages ?") {
                VStack(alignment: .leading, spacing: 12) {
                    BenefitsGrid(items: [
                        ("star.fill", "Cumulez des points"),
                        ("eurosign", "Bons d'achat"),
                        ("percent", "Offres exclusives"),
                        ("trophy.fill", "Jeux concours"),
                    ])
                    TipBox(style: .warning, icon: "lightbulb",
                           text: "**Astuce :** Ayez le réflexe de sortir votre carte de fidélité à chaque achat pour ne manquer aucun point !")
                    TipBox(style: .info, icon: "newspaper",
                           text: "**Restez informé :** Consultez les bons plans et les actualités pour ne rien manquer de ce qui se passe à Alençon !")
                }
            }
            faqRow("f4", "Pourquoi activer les notifications ?") {
                VStack(alignment: .leading, spacing: 12) {
                    answerText("Soyez informé en temps réel de tout ce qui fait vivre notre centre-ville :")
                    NotifList(items: [
                        ("tag.fill", Color(hex: 0xD32F2F), "Bons plans", "Offres exclusives et promotions"),
                        ("gamecontroller.fill", Color(hex: 0x1976D2), "Jeux et animations", "Concours et cadeaux à gagner"),
                        ("calendar", Color(hex: 0x388E3C), "Événements", "Marchés, fêtes, animations"),
                        ("megaphone.fill", Color(hex: 0xF57C00), "Actualités", "Nouveaux commerces, infos pratiques"),
                    ])
                    TipBox(style: .success, icon: "bell.fill",
                           text: "**Ne manquez rien !** Activez vos notifications pour rester connecté à la vie d'Alençon.")
                }
            }
        }
    }

    // MARK: Section 2 — Activation

    private var activationSection: some View {
        FaqSection(icon: "lock.open.fill", tint: Color(hex: 0x388E3C),
                   bg: Color(hex: 0xE8F5E9), title: "J'ai déjà une carte") {
            faqRow("a1", "Pourquoi « activer mon compte » ?") {
                VStack(alignment: .leading, spacing: 12) {
                    HighlightBox(icon: "info.circle.fill",
                                 text: "Si vous avez obtenu votre carte **en boutique**, votre compte existe déjà mais vous n'avez pas encore de mot de passe pour vous connecter.")
                    answerText("L'activation vous permet de :")
                    CheckList(items: [
                        "Créer votre mot de passe",
                        "Accéder à votre espace personnel",
                        "Consulter vos points et historique",
                        "Profiter des bons plans",
                    ])
                    TipBox(style: .info, icon: "person.fill",
                           text: "**Compte créé en ligne ?** Connectez-vous directement avec votre email et mot de passe.")
                }
            }
            faqRow("a2", "Comment activer mon compte ?") {
                StepsList(steps: [
                    .init(number: 1, title: "Cliquez sur « J'active mon compte »", detail: nil,
                          action: ("J'active mon compte", "/activer-mon-compte")),
                    .init(number: 2, title: "Entrez votre email", detail: "Celui donné en boutique lors de la création de votre carte", action: nil),
                    .init(number: 3, title: "Consultez votre boîte mail", detail: "Vous recevrez un lien pour créer votre mot de passe", action: nil),
                    .init(number: 4, title: "C'est prêt !", detail: "Connectez-vous et profitez de tous les avantages", action: nil),
                ], openHandler: open)
            }
            faqRow("a3", "Je ne reçois pas l'email ?") {
                VStack(alignment: .leading, spacing: 10) {
                    CheckList(tint: Color.brandNavy, items: [
                        "Spam : Vérifiez votre dossier indésirables",
                        "Email correct : Celui donné en boutique",
                        "Patientez : Quelques minutes peuvent être nécessaires",
                    ])
                    answerText("Toujours pas reçu ? Contactez l'équipe des Vitrines d'Alençon ou rendez-vous en boutique.")
                }
            }
        }
    }

    // MARK: Section 3 — Cartes cadeaux

    private var giftCardSection: some View {
        FaqSection(icon: "gift.fill", tint: Color(hex: 0xD32F2F),
                   bg: Color(hex: 0xFFEBEE), title: "Les cartes cadeaux") {
            faqRow("g1", "Qu'est-ce qu'une carte cadeau ?") {
                VStack(alignment: .leading, spacing: 12) {
                    answerText("Une carte prépayée pour régler vos achats chez les commerçants partenaires du centre-ville.")
                    HighlightBox(style: .gift, icon: "heart.fill",
                                 text: "**Le cadeau idéal** avec lequel on ne peut pas se tromper ! Mode, resto, beauté, loisirs... il y en a pour tous les goûts.")
                }
            }
            faqRow("g2", "Où acheter une carte cadeau ?") {
                LocationBox(title: "Boutique Les Vitrines d'Alençon",
                            text: "Rendez-vous directement à notre boutique pour acheter votre carte cadeau au montant de votre choix.") {
                    open("/contact")
                }
            }
            faqRow("g3", "Comment voir le solde ?") {
                VStack(alignment: .leading, spacing: 12) {
                    HighlightBox(icon: "person.crop.circle.fill",
                                 text: "**Pré-requis :** Vous devez être connecté à votre compte fidélité pour utiliser le scanner.")
                    StepsList(steps: [
                        .init(number: 1, title: "Connectez-vous à votre compte", detail: nil, action: nil),
                        .init(number: 2, title: "Allez dans le menu « Ma carte cadeau »", detail: nil, action: nil),
                        .init(number: 3, title: "Scannez ou entrez le numéro", detail: nil, action: nil),
                        .init(number: 4, title: "Consultez solde et historique", detail: nil, action: nil),
                    ], compact: true, openHandler: open)
                    NavigationLink {
                        CarteCadeauView()
                    } label: {
                        Label("Scanner ma carte cadeau", systemImage: "qrcode")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.brandNavy, in: .rect(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            faqRow("g4", "Comment utiliser ma carte ?") {
                VStack(alignment: .leading, spacing: 12) {
                    answerText("Présentez votre carte en caisse chez un commerçant partenaire. Le montant sera déduit de votre solde.")
                    TipBox(style: .success, icon: "creditcard.fill",
                           text: "**Bon à savoir :** Présentez aussi votre carte de fidélité ! Vous cumulez des points même en payant avec une carte cadeau.")
                    TipBox(style: .info, icon: "info.circle.fill",
                           text: "Si votre achat dépasse le solde, réglez la différence par un autre moyen de paiement.")
                    Button { open("/merchants?gift_card=1") } label: {
                        Label("Voir les commerçants acceptant la carte cadeau", systemImage: "list.bullet")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.brandNavy)
                    }
                }
            }
            faqRow("g5", "Durée de validité ?") {
                VStack(alignment: .leading, spacing: 12) {
                    answerText("La validité est indiquée sur votre carte. Vérifiez-la via notre scanner.")
                    TipBox(style: .warning, icon: "exclamationmark.triangle.fill",
                           text: "Pensez à utiliser votre carte avant expiration, le solde ne sera pas remboursé.")
                }
            }
        }
    }

    // MARK: Section 4 — Installation

    private var installSection: some View {
        FaqSection(icon: "iphone", tint: Color(hex: 0xF57C00),
                   bg: Color(hex: 0xFFF3E0), title: "Installer le site en application") {
            faqRow("i1", "Comment installer le site sur mon téléphone comme une application ?") {
                VStack(alignment: .leading, spacing: 12) {
                    answerText("Vous pouvez ajouter Les Vitrines d'Alençon sur l'écran d'accueil de votre téléphone pour y accéder en un clic, comme une application.")
                    AnswerOption(icon: "applelogo", title: "Sur iPhone ou iPad (Safari)",
                                 text: "Ouvrez le site dans Safari, appuyez sur Partager, puis « Sur l'écran d'accueil » et « Ajouter ».")
                    AnswerOption(icon: "smartphone", title: "Sur Android (Chrome)",
                                 text: "Ouvrez le menu ⋮, puis « Ajouter à l'écran d'accueil » ou « Installer l'application ».")
                    TipBox(style: .success, icon: "star.fill",
                           text: "**Avantage :** Un raccourci apparaîtra sur votre écran d'accueil pour accéder en un tap à votre carte, aux bons plans et au scanner.")
                }
            }
        }
    }

    // MARK: - Contact

    private var contactSection: some View {
        VStack(spacing: 12) {
            Text("Besoin d'aide ?")
                .font(.title3.bold())
                .foregroundStyle(Color(hex: 0x243B4A))
            Text("Rendez-vous à la boutique Les Vitrines d'Alençon, notre équipe vous accueille et répond à toutes vos questions.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("Vous pouvez aussi nous contacter en ligne pour poser une question ou obtenir nos coordonnées.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            NavigationLink { ContactView() } label: {
                Label("Nous contacter", systemImage: "envelope.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(hex: 0x243B4A), in: .rect(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(hex: 0xF8F9FA), in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: 0xE9ECEF), lineWidth: 2))
    }

    // MARK: - Helpers

    @ViewBuilder
    private func faqRow<Content: View>(_ id: String, _ question: String,
                                       @ViewBuilder answer: () -> Content) -> some View {
        FaqRow(question: question,
               isOpen: openId == id,
               toggle: { withAnimation(.easeInOut(duration: 0.2)) { openId = (openId == id) ? nil : id } },
               answer: answer)
    }

    private func open(_ path: String) {
        if let url = URL(string: publicBase + path) { openURL(url) }
    }
}

private func answerText(_ markdown: String) -> some View {
    Text(.init(markdown)) // **gras** interprété
        .font(.subheadline)
        .foregroundStyle(Color(hex: 0x555555))
        .fixedSize(horizontal: false, vertical: true)
}
