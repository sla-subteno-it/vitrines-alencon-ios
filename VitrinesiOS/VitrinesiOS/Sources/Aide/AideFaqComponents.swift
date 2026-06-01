// AideFaqComponents.swift
// Vitrines d'Alençon — iOS
// Composants réutilisables de la page Aide / FAQ.

import SwiftUI

// MARK: - Action rapide (carte)

struct QuickActionLabel: View {
    let icon: String
    let tint: Color
    let bg: Color
    let title: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(bg, in: .rect(cornerRadius: 10))
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background(Color(.systemBackground), in: .rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }
}

struct QuickAction: View {
    let icon: String
    let tint: Color
    let bg: Color
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            QuickActionLabel(icon: icon, tint: tint, bg: bg, title: title)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section FAQ (en-tête + items)

struct FaqSection<Content: View>: View {
    let icon: String
    let tint: Color
    let bg: Color
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
                    .background(bg, in: .rect(cornerRadius: 12))
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(Color(hex: 0x243B4A))
            }
            .padding(.bottom, 4)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color(hex: 0xF0F0F0)).frame(height: 2)
            }

            VStack(spacing: 8) { content }
        }
    }
}

// MARK: - Item FAQ (accordéon)

struct FaqRow<Answer: View>: View {
    let question: String
    let isOpen: Bool
    let toggle: () -> Void
    @ViewBuilder let answer: Answer

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: toggle) {
                HStack {
                    Text(question)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(hex: 0x243B4A))
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpen {
                answer
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color(.systemBackground), in: .rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isOpen ? Color.brandNavy : Color(hex: 0xE8E8E8),
                        lineWidth: isOpen ? 1.5 : 1)
        )
    }
}

// MARK: - Bouton d'action (dans une réponse)

struct ActionButton: View {
    let title: String
    var small: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, small ? 12 : 16)
                .padding(.vertical, small ? 8 : 10)
                .background(Color.brandNavy, in: .rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Option de réponse (icône + titre + texte)

struct AnswerOption<Trailing: View>: View {
    let icon: String
    let title: String
    let text: String
    @ViewBuilder var trailing: Trailing

    init(icon: String, title: String, text: String,
         @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.icon = icon
        self.title = title
        self.text = text
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color.brandNavy)
                .frame(width: 40, height: 40)
                .background(Color(.systemBackground), in: .rect(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(hex: 0x243B4A))
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                trailing
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(hex: 0xF8F9FA), in: .rect(cornerRadius: 10))
    }
}

// MARK: - Tip box

enum TipStyle {
    case warning, info, success
    var bg: Color {
        switch self {
        case .warning: return Color(hex: 0xFFF8E1)
        case .info:    return Color(hex: 0xE3F2FD)
        case .success: return Color(hex: 0xE8F5E9)
        }
    }
    var fg: Color {
        switch self {
        case .warning: return Color(hex: 0x856404)
        case .info:    return Color(hex: 0x0D47A1)
        case .success: return Color(hex: 0x2E7D32)
        }
    }
}

struct TipBox: View {
    let style: TipStyle
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(style.fg)
            Text(.init(text))
                .font(.footnote)
                .foregroundStyle(style.fg)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(style.bg, in: .rect(cornerRadius: 10))
    }
}

// MARK: - Highlight box

struct HighlightBox: View {
    enum Kind { case normal, gift }
    var style: Kind = .normal
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(style == .gift ? Color(hex: 0xE91E63) : Color.brandNavy)
            Text(.init(text))
                .font(.footnote)
                .foregroundStyle(Color(hex: 0x444444))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(style == .gift ? Color(hex: 0xFCE4EC) : Color(hex: 0xF0F4F8))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(style == .gift ? Color(hex: 0xE91E63) : Color.brandNavy)
                .frame(width: 4)
        }
        .clipShape(.rect(cornerRadius: 8))
    }
}

// MARK: - Benefits grid

struct BenefitsGrid: View {
    let items: [(String, String)]
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(items, id: \.1) { item in
                HStack(spacing: 8) {
                    Image(systemName: item.0)
                        .foregroundStyle(Color.brandNavy)
                    Text(item.1)
                        .font(.footnote.weight(.medium))
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(Color(hex: 0xF8F9FA), in: .rect(cornerRadius: 8))
            }
        }
    }
}

// MARK: - Check list

struct CheckList: View {
    var tint: Color = Color(hex: 0x388E3C)
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                        .padding(.top, 2)
                    Text(.init(item))
                        .font(.footnote)
                        .foregroundStyle(Color(hex: 0x555555))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

// MARK: - Notifications list

struct NotifList: View {
    let items: [(String, Color, String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(items, id: \.2) { item in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: item.0)
                        .font(.subheadline)
                        .foregroundStyle(item.1)
                        .frame(width: 36, height: 36)
                        .background(item.1.opacity(0.14), in: .rect(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.2)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(hex: 0x243B4A))
                        Text(item.3)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

// MARK: - Steps list

struct StepInfo {
    let number: Int
    let title: String
    let detail: String?
    let action: (String, String)?   // (titre bouton, path)
}

struct StepsList: View {
    let steps: [StepInfo]
    var compact: Bool = false
    let openHandler: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 12 : 16) {
            ForEach(steps, id: \.number) { step in
                HStack(alignment: compact ? .center : .top, spacing: 12) {
                    Text("\(step.number)")
                        .font(compact ? .caption.weight(.bold) : .subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: compact ? 24 : 28, height: compact ? 24 : 28)
                        .background(Color.brandNavy, in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(step.title)
                            .font(.subheadline.weight(compact ? .regular : .semibold))
                            .foregroundStyle(Color(hex: 0x243B4A))
                            .fixedSize(horizontal: false, vertical: true)
                        if let detail = step.detail {
                            Text(detail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let action = step.action {
                            ActionButton(title: action.0) { openHandler(action.1) }
                                .padding(.top, 2)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

// MARK: - Location box

struct LocationBox: View {
    let title: String
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "mappin.circle.fill")
                    .font(.title)
                    .foregroundStyle(Color(hex: 0x388E3C))
                    .frame(width: 48, height: 48)
                    .background(Color(.systemBackground), in: .rect(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color(hex: 0x1B5E20))
                    Text(text)
                        .font(.footnote)
                        .foregroundStyle(Color(hex: 0x2E7D32))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(
                LinearGradient(colors: [Color(hex: 0xE8F5E9), Color(hex: 0xC8E6C9)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: .rect(cornerRadius: 12)
            )
        }
        .buttonStyle(.plain)
    }
}
