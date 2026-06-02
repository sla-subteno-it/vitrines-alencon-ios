// DeleteAccountView.swift
// Vitrines d'Alençon — iOS
// Suppression de compte in-app (exigence App Store 5.1.1(v) + RGPD).
// Utilise le portail Odoo /my/deactivate_account.

import SwiftUI
import Combine

@MainActor
final class DeleteAccountViewModel: ObservableObject {
    @Published var password = ""
    @Published var confirmation = ""
    @Published var blacklist = true
    @Published var isDeleting = false
    @Published var errorMessage: String?

    private let client = OdooClient.shared

    var isValid: Bool {
        !password.isEmpty && confirmation.contains("@")
    }

    /// Renvoie true si la suppression a réussi.
    func delete() async -> Bool {
        guard isValid else { return false }
        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false }
        do {
            try await client.deleteAccount(
                password: password,
                confirmation: confirmation.trimmingCharacters(in: .whitespaces),
                blacklist: blacklist
            )
            return true
        } catch {
            errorMessage = (error as? OdooError)?.errorDescription
                ?? "La suppression a échoué. Vérifiez votre mot de passe et l'email saisi."
            return false
        }
    }
}

struct DeleteAccountView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var vm = DeleteAccountViewModel()
    @FocusState private var focused: Field?
    @State private var showConfirm = false

    private enum Field { case password, confirmation }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                warning
                formCard
                if let error = vm.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote).foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                deleteButton
            }
            .padding(20)
            .frame(maxWidth: 600)
        }
        .aboveTabBar()
        .background(Color.brandSurface.ignoresSafeArea())
        .navigationTitle("Supprimer mon compte")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .alert("Supprimer définitivement votre compte ?", isPresented: $showConfirm) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive) {
                Task { if await vm.delete() { await auth.logout() } }
            }
        } message: {
            Text("Cette action est irréversible. Votre accès et vos données associées seront supprimés.")
        }
    }

    private var warning: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.title3)
            VStack(alignment: .leading, spacing: 6) {
                Text("Action irréversible")
                    .font(.headline)
                    .foregroundStyle(.red)
                Text("La suppression de votre compte entraîne la perte de l'accès à votre carte de fidélité, votre historique et vos avantages. Cette action ne peut pas être annulée.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Color.red.opacity(0.08), in: .rect(cornerRadius: 14))
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                label("Mot de passe")
                SecureField("Votre mot de passe", text: $vm.password)
                    .textContentType(.password)
                    .focused($focused, equals: .password)
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 10))
            }
            VStack(alignment: .leading, spacing: 6) {
                label("Confirmez en saisissant votre email")
                TextField("email@exemple.fr", text: $vm.confirmation)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused, equals: .confirmation)
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 10))
            }
            Toggle(isOn: $vm.blacklist) {
                Text("Supprimer aussi mes coordonnées des communications (RGPD)")
                    .font(.footnote)
            }
            .tint(Color.brandNavy)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }

    private var deleteButton: some View {
        Button {
            focused = nil
            showConfirm = true
        } label: {
            ZStack {
                Text("Supprimer définitivement mon compte")
                    .fontWeight(.semibold)
                    .opacity(vm.isDeleting ? 0 : 1)
                if vm.isDeleting { ProgressView().tint(.white) }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(vm.isValid ? Color.red : Color.gray, in: .rect(cornerRadius: 12))
        }
        .disabled(!vm.isValid || vm.isDeleting)
    }

    private func label(_ text: String) -> some View {
        Text(text).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
    }
}
