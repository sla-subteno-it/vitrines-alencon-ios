// SecurityView.swift
// Vitrines d'Alençon — iOS
// Connexion et sécurité (/my/security) : changement de mot de passe.

import SwiftUI
import Combine

@MainActor
final class SecurityViewModel: ObservableObject {
    @Published var current = ""
    @Published var newPassword = ""
    @Published var confirm = ""
    @Published var isSaving = false
    @Published var didChange = false
    @Published var errorMessage: String?

    private let client = OdooClient.shared

    var passwordsMatch: Bool { !newPassword.isEmpty && newPassword == confirm }
    var isValid: Bool { !current.isEmpty && newPassword.count >= 8 && passwordsMatch }

    func submit() async {
        guard isValid else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await client.changePassword(old: current, new: newPassword)
            didChange = true
            current = ""; newPassword = ""; confirm = ""
        } catch {
            errorMessage = (error as? OdooError)?.errorDescription
                ?? "Le changement de mot de passe a échoué."
        }
    }
}

struct SecurityView: View {
    @StateObject private var vm = SecurityViewModel()
    @FocusState private var currentFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if vm.didChange {
                    successBanner
                } else {
                    formCard
                }
            }
            .padding(20)
            .frame(maxWidth: 600)
        }
        .aboveTabBar()
        .background(Color.brandSurface.ignoresSafeArea())
        .navigationTitle("Connexion et sécurité")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 26)).foregroundStyle(.white)
                .frame(width: 58, height: 58).background(Color.brandNavy, in: Circle())
            Text("Modifier mon mot de passe")
                .font(.headline).foregroundStyle(Color.brandNavy)
        }
        .frame(maxWidth: .infinity)
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                label("Mot de passe actuel")
                SecureField("Mot de passe actuel", text: $vm.current)
                    .textContentType(.password)
                    .focused($currentFocused)
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 10))
            }
            VStack(alignment: .leading, spacing: 6) {
                label("Nouveau mot de passe")
                NewPasswordField(placeholder: "8 caractères minimum", text: $vm.newPassword)
                    .frame(height: 24).padding(12)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 10))
            }
            VStack(alignment: .leading, spacing: 6) {
                label("Confirmer le nouveau mot de passe")
                NewPasswordField(placeholder: "Confirmez", text: $vm.confirm)
                    .frame(height: 24).padding(12)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 10))
            }
            if !vm.confirm.isEmpty && !vm.passwordsMatch {
                Text("Les mots de passe ne correspondent pas.")
                    .font(.caption).foregroundStyle(.red)
            }
            if let error = vm.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }

            Button {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                Task { await vm.submit() }
            } label: {
                ZStack {
                    Text("Changer le mot de passe").fontWeight(.semibold).opacity(vm.isSaving ? 0 : 1)
                    if vm.isSaving { ProgressView().tint(.white) }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 14).foregroundStyle(.white)
                .background(vm.isValid ? Color.brandNavy : Color.gray, in: .rect(cornerRadius: 12))
            }
            .disabled(!vm.isValid || vm.isSaving)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    private var successBanner: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill").font(.largeTitle).foregroundStyle(.green)
            Text("Mot de passe modifié").font(.headline)
            Text("Votre mot de passe a bien été mis à jour.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(24)
        .background(Color.green.opacity(0.1), in: .rect(cornerRadius: 16))
    }

    private func label(_ text: String) -> some View {
        Text(text).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
    }
}
