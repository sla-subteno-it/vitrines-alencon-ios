// CommunicationPreferencesView.swift
// Vitrines d'Alençon — iOS
// Préférences de communication (opt-in email / SMS) — section /ma-carte#communication.

import SwiftUI
import Combine

@MainActor
final class CommunicationPreferencesViewModel: ObservableObject {
    @Published var emailOptin = false
    @Published var smsOptin = false
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var saveMessage: String?
    @Published var errorMessage: String?

    private let client = OdooClient.shared

    private struct UserRef: Decodable {
        let partnerId: Int?
        enum CodingKeys: String, CodingKey { case partnerId = "partner_id" }
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: CodingKeys.self)
            if var m2o = try? c.nestedUnkeyedContainer(forKey: .partnerId) { partnerId = try? m2o.decode(Int.self) }
            else { partnerId = nil }
        }
    }
    private struct OptinRow: Decodable {
        let email: String?
        let sms: String?
        enum CodingKeys: String, CodingKey { case email = "email_optin_status", sms = "sms_optin_status" }
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: CodingKeys.self)
            email = (try? c.decode(String.self, forKey: .email))?.nilIfFalseEmpty
            sms = (try? c.decode(String.self, forKey: .sms))?.nilIfFalseEmpty
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let uid = await OdooSession.shared.getUID() else { return }
        do {
            let users: [UserRef] = try await client.call(
                model: "res.users", method: "search_read", args: [],
                kwargs: ["domain": [["id", "=", uid]], "fields": ["partner_id"], "limit": 1])
            guard let pid = users.first?.partnerId else { return }
            let rows: [OptinRow] = try await client.call(
                model: "res.partner", method: "search_read", args: [],
                kwargs: ["domain": [["id", "=", pid]],
                         "fields": ["email_optin_status", "sms_optin_status"], "limit": 1])
            if let r = rows.first {
                emailOptin = (r.email == "1")
                smsOptin = (r.sms == "1")
            }
        } catch {
            errorMessage = (error as? OdooError)?.errorDescription ?? error.localizedDescription
        }
    }

    func save() async {
        isSaving = true
        saveMessage = nil
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await client.saveCommunicationPreferences(emailOptin: emailOptin, smsOptin: smsOptin)
            saveMessage = "Préférences enregistrées."
        } catch {
            errorMessage = (error as? OdooError)?.errorDescription ?? "L'enregistrement a échoué."
        }
    }
}

struct CommunicationPreferencesView: View {
    @StateObject private var vm = CommunicationPreferencesViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Préférences de communication")
                    .font(.title3.bold())
                    .foregroundStyle(Color.brandNavy)

                Text("Recevez l'actualité des commerces du centre-ville d'Alençon : bons plans, animations et événements.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                prefCard(icon: "envelope.fill", title: "Notifications par email",
                         subtitle: "Recevoir les notifications par email", isOn: $vm.emailOptin)
                prefCard(icon: "iphone", title: "Notifications par SMS",
                         subtitle: "Recevoir les notifications par SMS", isOn: $vm.smsOptin)

                if let msg = vm.saveMessage {
                    Label(msg, systemImage: "checkmark.circle.fill").font(.footnote).foregroundStyle(.green)
                }
                if let error = vm.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    Task { await vm.save() }
                } label: {
                    ZStack {
                        Label("Enregistrer les préférences", systemImage: "square.and.arrow.down")
                            .fontWeight(.semibold).opacity(vm.isSaving ? 0 : 1)
                        if vm.isSaving { ProgressView().tint(.white) }
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 14).foregroundStyle(.white)
                    .background(Color.brandNavy, in: .rect(cornerRadius: 12))
                }
                .disabled(vm.isSaving)
            }
            .padding(20)
            .frame(maxWidth: 600)
        }
        .aboveTabBar()
        .background(Color.brandSurface.ignoresSafeArea())
        .navigationTitle("Préférences")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load() }
    }

    private func prefCard(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.brandNavy)
            Toggle(subtitle, isOn: isOn)
                .font(.subheadline)
                .tint(Color.brandNavy)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.brandNavy).frame(width: 4).clipShape(.rect(cornerRadius: 2))
        }
    }
}
