// CreateCardView.swift
// Vitrines d'Alençon — iOS
// Réplique de /web/signup (variante Adelya « Créer ma carte ») : inscription au
// programme fidélité avec création du membre Adelya côté serveur.

import SwiftUI
import Combine

@MainActor
final class CreateCardViewModel: ObservableObject {
    @Published var gender = ""            // "Monsieur" / "Madame"
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var birthday = Calendar.current.date(from: DateComponents(year: 1990, month: 1, day: 1)) ?? Date()
    @Published var phone = ""
    @Published var address = ""
    @Published var zip = ""
    @Published var city = ""
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var mailOption = true
    @Published var smsOption = false

    @Published var isSubmitting = false
    @Published var errorMessage: String?

    private let client = OdooClient.shared

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    var passwordsMatch: Bool { !password.isEmpty && password == confirmPassword }

    var isValid: Bool {
        !gender.isEmpty
        && !firstName.trimmingCharacters(in: .whitespaces).isEmpty
        && !lastName.trimmingCharacters(in: .whitespaces).isEmpty
        && !phone.trimmingCharacters(in: .whitespaces).isEmpty
        && !zip.trimmingCharacters(in: .whitespaces).isEmpty
        && !city.trimmingCharacters(in: .whitespaces).isEmpty
        && email.contains("@")
        && password.count >= 8
        && passwordsMatch
    }

    /// Renvoie true si l'inscription a réussi (utilisateur connecté).
    func submit() async -> Bool {
        guard isValid else { return false }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let fields: [String: String] = [
            "login": email.trimmingCharacters(in: .whitespaces),
            "name": "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces),
            "password": password,
            "confirm_password": confirmPassword,
            "adelya_gender": gender,
            "adelya_first_name": firstName.trimmingCharacters(in: .whitespaces),
            "adelya_last_name": lastName.trimmingCharacters(in: .whitespaces),
            "adelya_birthday": Self.dateFormatter.string(from: birthday),
            "adelya_phone_number": phone.trimmingCharacters(in: .whitespaces),
            "adelya_address": address.trimmingCharacters(in: .whitespaces),
            "adelya_zip": zip.trimmingCharacters(in: .whitespaces),
            "adelya_city": city.trimmingCharacters(in: .whitespaces),
            "adelya_mail_option": mailOption ? "1" : "0",
            "adelya_sms_option": smsOption ? "1" : "0"
        ]

        do {
            try await client.signup(fields: fields)
            return true
        } catch {
            errorMessage = (error as? OdooError)?.errorDescription ?? "La création du compte a échoué. Réessayez."
            return false
        }
    }
}

struct CreateCardView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var vm = CreateCardViewModel()
    @FocusState private var focused: Field?

    private enum Field { case firstName, lastName, phone, address, zip, city, email, password, confirm }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                emailSection
                personalSection
                contactSection
                addressSection
                preferencesSection
                passwordSection

                if let error = vm.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                submitButton
                alreadyMemberLink
            }
            .padding(20)
            .frame(maxWidth: 600)
        }
        .aboveTabBar()
        .background(Color.brandSurface.ignoresSafeArea())
        .navigationTitle("Créer ma carte")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - En-tête

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 28))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Color.brandNavy, in: Circle())
            Text("Rejoignez le programme fidélité")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Faites-vous plaisir, on vous récompense 💕")
                .font(.footnote.italic())
                .foregroundStyle(Color.brandRed)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sections

    private var personalSection: some View {
        FormSection("Informations personnelles") {
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Civilité", required: true)
                Picker("Civilité", selection: $vm.gender) {
                    Text("-- Sélectionner --").tag("")
                    Text("Monsieur").tag("Monsieur")
                    Text("Madame").tag("Madame")
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Date de naissance", required: true)
                DatePicker("", selection: $vm.birthday, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "fr_FR"))
            }

            textField("Prénom", text: $vm.firstName, required: true, field: .firstName, content: .givenName)
            textField("Nom", text: $vm.lastName, required: true, field: .lastName, content: .familyName)
        }
    }

    private var contactSection: some View {
        FormSection("Coordonnées") {
            textField("Téléphone", text: $vm.phone, required: true, field: .phone,
                      content: .telephoneNumber, keyboard: .phonePad)
        }
    }

    private var addressSection: some View {
        FormSection("Adresse") {
            textField("Adresse", text: $vm.address, required: false, field: .address, content: .fullStreetAddress)
            textField("Code postal", text: $vm.zip, required: true, field: .zip,
                      content: .postalCode, keyboard: .numbersAndPunctuation)
            textField("Ville", text: $vm.city, required: true, field: .city, content: .addressCity)
        }
    }

    private var preferencesSection: some View {
        FormSection("Préférences de communication") {
            Text("Recevez l'actualité des commerces du centre-ville d'Alençon : bons plans, animations et événements. Aucune publicité hors d'Alençon.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Toggle(isOn: $vm.mailOption) {
                Label("Recevoir l'actualité par email", systemImage: "envelope")
                    .font(.subheadline)
            }
            .tint(Color.brandNavy)
            Toggle(isOn: $vm.smsOption) {
                Label("Recevoir l'actualité par SMS", systemImage: "iphone")
                    .font(.subheadline)
            }
            .tint(Color.brandNavy)
        }
    }

    private var passwordSection: some View {
        FormSection("Mot de passe") {
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Mot de passe", required: true)
                NewPasswordField(placeholder: "8 caractères minimum", text: $vm.password)
                    .frame(height: 24)
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 10))
            }
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Confirmer le mot de passe", required: true)
                NewPasswordField(placeholder: "Confirmez", text: $vm.confirmPassword)
                    .frame(height: 24)
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 10))
            }
            if !vm.confirmPassword.isEmpty && !vm.passwordsMatch {
                Text("Les mots de passe ne correspondent pas.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var submitButton: some View {
        Button {
            focused = nil
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            Task {
                if await vm.submit() { await auth.refreshSession() }
            }
        } label: {
            ZStack {
                Text("Créer ma carte")
                    .fontWeight(.semibold)
                    .opacity(vm.isSubmitting ? 0 : 1)
                if vm.isSubmitting { ProgressView().tint(.white) }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(vm.isValid ? Color.brandNavy : Color.gray, in: .rect(cornerRadius: 12))
        }
        .disabled(!vm.isValid || vm.isSubmitting)
    }

    private var alreadyMemberLink: some View {
        NavigationLink {
            ActivateAccountView(prefillEmail: vm.email)
        } label: {
            Text("Vous êtes déjà membre ? Activer mon compte")
                .font(.footnote)
                .foregroundStyle(Color.brandNavy)
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private func textField(_ label: String, text: Binding<String>, required: Bool,
                           field: Field, content: UITextContentType? = nil,
                           keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel(label, required: required)
            TextField(label, text: text)
                .textContentType(content)
                .keyboardType(keyboard)
                .textInputAutocapitalization(field == .email ? .never : .words)
                .autocorrectionDisabled(field == .email)
                .focused($focused, equals: field)
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 10))
        }
    }

    private func fieldLabel(_ text: String, required: Bool) -> some View {
        HStack(spacing: 2) {
            Text(text).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            if required { Text("*").font(.caption).foregroundStyle(.red) }
        }
    }
}

// Champ email à part car le helper générique exclut la capitalisation seulement pour .email
private extension CreateCardView {
    var emailSection: some View {
        FormSection("Email") {
            textField("Email", text: $vm.email, required: true, field: .email,
                      content: .emailAddress, keyboard: .emailAddress)
        }
    }
}

// MARK: - Champ « nouveau mot de passe » (AutoFill iOS)

/// Champ mot de passe basé sur UITextField pour activer de façon fiable la
/// proposition de mot de passe fort par le trousseau iOS : `textContentType`
/// = `.newPassword` + `passwordRules`. (SwiftUI `SecureField` n'expose pas
/// `passwordRules`, ce qui rend la suggestion aléatoire.)
struct NewPasswordField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.placeholder = placeholder
        field.isSecureTextEntry = true
        field.textContentType = .newPassword
        field.passwordRules = UITextInputPasswordRules(descriptor: "minlength: 8; allowed: ascii-printable;")
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.clearButtonMode = .whileEditing
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.delegate = context.coordinator
        field.addTarget(context.coordinator,
                        action: #selector(Coordinator.editingChanged(_:)),
                        for: .editingChanged)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text { uiView.text = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        init(text: Binding<String>) { _text = text }

        @objc func editingChanged(_ field: UITextField) {
            text = field.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}

// MARK: - Section de formulaire

struct FormSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.brandNavy)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground).opacity(0.6), in: .rect(cornerRadius: 14))
    }
}
