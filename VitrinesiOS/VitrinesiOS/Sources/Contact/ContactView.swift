// ContactView.swift
// Vitrines d'Alençon — iOS
// Réplique de la page /contact (Contactez-nous) : formulaire + coordonnées.

import SwiftUI
import Combine

@MainActor
final class ContactViewModel: ObservableObject {
    @Published var name = ""
    @Published var phone = ""
    @Published var email = ""
    @Published var company = ""
    @Published var subject = ""
    @Published var message = ""

    @Published var isSending = false
    @Published var didSend = false
    @Published var errorMessage: String?

    private let client = OdooClient.shared

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
        && email.contains("@")
        && !subject.trimmingCharacters(in: .whitespaces).isEmpty
        && !message.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func send() async {
        guard isValid else { return }
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            let ok = try await client.submitContactForm(fields: [
                "name": name,
                "phone": phone,
                "email_from": email,
                "company": company,
                "subject": subject,
                "description": message
            ])
            if ok {
                didSend = true
            } else {
                errorMessage = "L'envoi a échoué. Réessayez ou contactez-nous directement."
            }
        } catch {
            errorMessage = (error as? OdooError)?.errorDescription
                ?? "L'envoi a échoué. Réessayez ou contactez-nous directement."
        }
    }
}

struct ContactView: View {
    @StateObject private var vm = ContactViewModel()
    @Environment(\.openURL) private var openURL
    @FocusState private var focused: Field?

    private enum Field { case name, phone, email, company, subject, message }

    private let email = "contact@vitrines-alencon.fr"
    private let phone = "06 76 69 76 66"
    private let address = "4 place du Palais, 61000 Alençon"

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                VStack(spacing: 20) {
                    if vm.didSend { successBanner } else { formCard }
                    infoCard
                    hoursCard
                }
                .padding(16)
                .frame(maxWidth: 600)
            }
        }
        .aboveTabBar()
        .background(Color(.systemBackground))
        .navigationTitle("Contactez-nous")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 10) {
            Text("Contactez-nous")
                .font(BrandFont.serif(28, weight: .bold))
                .foregroundStyle(.white)
            Text("Pour tout ce qui concerne notre programme ou nos services. Nous ferons de notre mieux pour vous répondre dans les plus brefs délais.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
        .background(Color.brandNavy)
    }

    // MARK: - Formulaire

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            field("Nom", text: $vm.name, required: true, field: .name, content: .name, keyboard: .default)
            field("Numéro de téléphone", text: $vm.phone, required: false, field: .phone, content: .telephoneNumber, keyboard: .phonePad)
            field("Email", text: $vm.email, required: true, field: .email, content: .emailAddress, keyboard: .emailAddress)
            field("Société", text: $vm.company, required: false, field: .company, content: .organizationName, keyboard: .default)
            field("Sujet", text: $vm.subject, required: true, field: .subject, content: nil, keyboard: .default)

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Question", required: true)
                TextField("Votre message…", text: $vm.message, axis: .vertical)
                    .lineLimit(4...8)
                    .focused($focused, equals: .message)
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 10))
            }

            if let error = vm.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button {
                focused = nil
                Task { await vm.send() }
            } label: {
                ZStack {
                    Text("Soumettre")
                        .fontWeight(.semibold)
                        .opacity(vm.isSending ? 0 : 1)
                    if vm.isSending { ProgressView().tint(.white) }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(vm.isValid ? Color.brandNavy : Color.gray, in: .rect(cornerRadius: 10))
            }
            .disabled(!vm.isValid || vm.isSending)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    private func field(_ label: String, text: Binding<String>, required: Bool,
                       field: Field, content: UITextContentType?, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel(label, required: required)
            TextField(label, text: text)
                .textContentType(content)
                .keyboardType(keyboard)
                .textInputAutocapitalization(field == .email ? .never : .sentences)
                .autocorrectionDisabled(field == .email)
                .focused($focused, equals: field)
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 10))
        }
    }

    private func fieldLabel(_ text: String, required: Bool) -> some View {
        HStack(spacing: 2) {
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if required { Text("*").foregroundStyle(.red).font(.caption) }
        }
    }

    private var successBanner: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.green)
            Text("Message envoyé !")
                .font(.headline)
            Text("Merci de nous avoir contactés. Nous vous répondrons dans les plus brefs délais.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.green.opacity(0.1), in: .rect(cornerRadius: 16))
    }

    // MARK: - Coordonnées

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Les Vitrines d'Alençon")
                .font(.headline)
                .foregroundStyle(Color.brandRed)

            ContactInfoRow(icon: "mappin.circle.fill", text: address, detail: nil) {
                let q = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                if let url = URL(string: "http://maps.apple.com/?q=\(q)") { openURL(url) }
            }
            ContactInfoRow(icon: "phone.circle.fill", text: phone,
                           detail: "du mardi au samedi de 9h à 18h") {
                if let url = URL(string: "tel://\(phone.replacingOccurrences(of: " ", with: ""))") { openURL(url) }
            }
            ContactInfoRow(icon: "envelope.circle.fill", text: email, detail: nil) {
                if let url = URL(string: "mailto:\(email)") { openURL(url) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }

    // MARK: - Ouvertures

    private var hoursCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Nos ouvertures", systemImage: "clock.fill")
                .font(.headline)
                .foregroundStyle(Color.brandNavy)
            hourRow("Lundi", "15h – 18h")
            hourRow("Mercredi", "9h – 12h30")
            hourRow("Vendredi", "11h – 14h")
            hourRow("Samedi", "9h – 13h")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }

    private func hourRow(_ day: String, _ hours: String) -> some View {
        HStack {
            Text(day).font(.subheadline.weight(.medium))
            Spacer()
            Text(hours).font(.subheadline).foregroundStyle(.secondary)
        }
    }
}

private struct ContactInfoRow: View {
    let icon: String
    let text: String
    let detail: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(Color.brandNavy)
                VStack(alignment: .leading, spacing: 2) {
                    Text(text)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    if let detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
