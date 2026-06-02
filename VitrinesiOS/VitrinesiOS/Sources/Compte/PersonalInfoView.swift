// PersonalInfoView.swift
// Vitrines d'Alençon — iOS
// Mes infos personnelles (/my/account) + Mes adresses (/my/addresses).
// Les deux s'appuient sur le formulaire portail Odoo /my/address/submit.

import SwiftUI
import Combine

// MARK: - ViewModel partagé

@MainActor
final class AccountViewModel: ObservableObject {
    @Published var name = ""
    @Published var email = ""
    @Published var phone = ""
    @Published var street = ""
    @Published var street2 = ""
    @Published var zip = ""
    @Published var city = ""
    @Published var birthday = Calendar.current.date(from: DateComponents(year: 1990, month: 1, day: 1)) ?? Date()
    @Published var hasBirthday = false
    @Published var countryName: String?

    @Published var isLoading = false
    @Published var isSaving = false
    @Published var didSave = false
    @Published var errorMessage: String?

    private(set) var partnerId: Int?
    private var countryId: Int?
    private var stateId: Int?

    private let client = OdooClient.shared

    private static let df: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX"); return f
    }()

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && email.contains("@")
    }

    var birthdayLabel: String {
        guard hasBirthday else { return "—" }
        let f = DateFormatter(); f.dateFormat = "dd/MM/yyyy"; f.locale = Locale(identifier: "fr_FR")
        return f.string(from: birthday)
    }

    var addressLine: String {
        [street, street2].compactMap { $0.isEmpty ? nil : $0 }.joined(separator: ", ")
    }
    var zipCity: String { "\(zip) \(city)".trimmingCharacters(in: .whitespaces) }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let uid = await OdooSession.shared.getUID() else { return }
        do {
            let users: [UserPartnerRef] = try await client.call(
                model: "res.users", method: "search_read", args: [],
                kwargs: ["domain": [["id", "=", uid]], "fields": ["partner_id"], "limit": 1]
            )
            guard let pid = users.first?.partnerId else { return }
            partnerId = pid

            let rows: [PartnerDetails] = try await client.call(
                model: "res.partner", method: "search_read", args: [],
                kwargs: ["domain": [["id", "=", pid]],
                         "fields": ["name", "email", "phone", "birthday", "street",
                                    "street2", "zip", "city", "country_id", "state_id"],
                         "limit": 1]
            )
            guard let p = rows.first else { return }
            name = p.name ?? ""
            email = p.email ?? ""
            phone = p.phone ?? ""
            street = p.street ?? ""
            street2 = p.street2 ?? ""
            zip = p.zip ?? ""
            city = p.city ?? ""
            countryId = p.countryId
            countryName = p.countryName
            stateId = p.stateId
            if let b = p.birthday, let d = Self.df.date(from: b) {
                birthday = d; hasBirthday = true
            }
            errorMessage = nil
        } catch {
            errorMessage = (error as? OdooError)?.errorDescription ?? error.localizedDescription
        }
    }

    func save() async -> Bool {
        guard isValid, let pid = partnerId else { return false }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let fields: [String: String] = [
            "name": name.trimmingCharacters(in: .whitespaces),
            "email": email.trimmingCharacters(in: .whitespaces),
            "phone": phone.trimmingCharacters(in: .whitespaces),
            "birthday": Self.df.string(from: birthday),
            "street": street.trimmingCharacters(in: .whitespaces),
            "street2": street2.trimmingCharacters(in: .whitespaces),
            "zip": zip.trimmingCharacters(in: .whitespaces),
            "city": city.trimmingCharacters(in: .whitespaces),
            "country_id": countryId.map(String.init) ?? "",
            "state_id": stateId.map(String.init) ?? ""
        ]
        do {
            try await client.savePersonalInfo(partnerId: pid, fields: fields)
            didSave = true
            return true
        } catch {
            errorMessage = (error as? OdooError)?.errorDescription ?? "L'enregistrement a échoué."
            return false
        }
    }
}

// MARK: - Décodage

private struct UserPartnerRef: Decodable {
    let partnerId: Int?
    enum CodingKeys: String, CodingKey { case partnerId = "partner_id" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if var m2o = try? c.nestedUnkeyedContainer(forKey: .partnerId) {
            partnerId = try? m2o.decode(Int.self)
        } else { partnerId = nil }
    }
}

private struct PartnerDetails: Decodable {
    let name, email, phone, birthday, street, street2, zip, city: String?
    let countryId: Int?
    let countryName: String?
    let stateId: Int?

    enum CodingKeys: String, CodingKey {
        case name, email, phone, birthday, street, street2, zip, city
        case countryId = "country_id"
        case stateId = "state_id"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func str(_ k: CodingKeys) -> String? { (try? c.decode(String.self, forKey: k))?.nilIfFalseEmpty }
        name = str(.name); email = str(.email); phone = str(.phone); birthday = str(.birthday)
        street = str(.street); street2 = str(.street2); zip = str(.zip); city = str(.city)
        if var m2o = try? c.nestedUnkeyedContainer(forKey: .countryId) {
            countryId = try? m2o.decode(Int.self)
            countryName = try? m2o.decode(String.self)
        } else { countryId = nil; countryName = nil }
        if var m2o = try? c.nestedUnkeyedContainer(forKey: .stateId) {
            stateId = try? m2o.decode(Int.self)
        } else { stateId = nil }
    }
}

// MARK: - Mes infos personnelles (édition)

struct PersonalInfoView: View {
    @StateObject private var vm = AccountViewModel()
    @FocusState private var focused: Field?
    @Environment(\.dismiss) private var dismiss

    private enum Field { case name, email, phone, street, street2, zip, city }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                FormSection("Identité") {
                    field("Nom", text: $vm.name, required: true, field: .name, content: .name)
                    field("Email", text: $vm.email, required: true, field: .email, content: .emailAddress, keyboard: .emailAddress)
                    field("Téléphone", text: $vm.phone, required: false, field: .phone, content: .telephoneNumber, keyboard: .phonePad)
                    VStack(alignment: .leading, spacing: 6) {
                        fieldLabel("Date de naissance", required: false)
                        DatePicker("", selection: $vm.birthday, in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(.compact).labelsHidden()
                            .environment(\.locale, Locale(identifier: "fr_FR"))
                            .onChange(of: vm.birthday) { _, _ in vm.hasBirthday = true }
                    }
                }

                FormSection("Adresse") {
                    field("Adresse", text: $vm.street, required: false, field: .street, content: .fullStreetAddress)
                    field("Complément d'adresse", text: $vm.street2, required: false, field: .street2)
                    field("Code postal", text: $vm.zip, required: false, field: .zip, content: .postalCode, keyboard: .numbersAndPunctuation)
                    field("Ville", text: $vm.city, required: false, field: .city, content: .addressCity)
                    if let country = vm.countryName {
                        HStack { Text("Pays").font(.caption.weight(.semibold)).foregroundStyle(.secondary); Spacer(); Text(country).font(.subheadline) }
                    }
                }

                if let error = vm.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
                }
                if vm.didSave {
                    Label("Modifications enregistrées.", systemImage: "checkmark.circle.fill")
                        .font(.footnote).foregroundStyle(.green)
                }

                Button {
                    focused = nil
                    Task { _ = await vm.save() }
                } label: {
                    ZStack {
                        Text("Enregistrer").fontWeight(.semibold).opacity(vm.isSaving ? 0 : 1)
                        if vm.isSaving { ProgressView().tint(.white) }
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 14).foregroundStyle(.white)
                    .background(vm.isValid ? Color.brandNavy : Color.gray, in: .rect(cornerRadius: 12))
                }
                .disabled(!vm.isValid || vm.isSaving)
            }
            .padding(20)
            .frame(maxWidth: 600)
        }
        .aboveTabBar()
        .background(Color.brandSurface.ignoresSafeArea())
        .navigationTitle("Mes infos personnelles")
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if vm.isLoading { ProgressView() } }
        .task { await vm.load() }
    }

    private func field(_ label: String, text: Binding<String>, required: Bool, field: Field,
                       content: UITextContentType? = nil, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel(label, required: required)
            TextField(label, text: text)
                .textContentType(content).keyboardType(keyboard)
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

// MARK: - Mes adresses (lecture + lien d'édition)

struct AddressesView: View {
    @StateObject private var vm = AccountViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Adresse principale")
                    .font(.headline).foregroundStyle(Color.brandNavy)

                VStack(alignment: .leading, spacing: 12) {
                    row("Date de naissance", vm.birthdayLabel)
                    row("Adresse", vm.addressLine.isEmpty ? "—" : vm.addressLine)
                    row("Code postal / Ville", vm.zipCity.isEmpty ? "—" : vm.zipCity)
                    row("Pays", vm.countryName ?? "—")
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))

                NavigationLink {
                    PersonalInfoView()
                } label: {
                    Label("Modifier l'adresse", systemImage: "pencil")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.brandNavy, in: .rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .frame(maxWidth: 600)
        }
        .aboveTabBar()
        .background(Color.brandSurface.ignoresSafeArea())
        .navigationTitle("Mes adresses")
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if vm.isLoading && vm.partnerId == nil { ProgressView() } }
        .task { await vm.load() }
        .onAppear { Task { await vm.load() } }
    }

    private func row(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.subheadline).foregroundStyle(.primary)
        }
    }
}
