// ActivateAccountView.swift
// Vitrines d'Alençon — iOS
// Réplique de /activer-mon-compte : un membre existant demande un lien d'activation.

import SwiftUI
import Combine

@MainActor
final class ActivateAccountViewModel: ObservableObject {
    @Published var email = ""
    @Published var isSending = false
    @Published var didSend = false
    @Published var errorMessage: String?

    private let client = OdooClient.shared

    var isValid: Bool { email.contains("@") }

    func submit() async {
        guard isValid else { return }
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            didSend = try await client.requestAccountActivation(email: email.trimmingCharacters(in: .whitespaces))
        } catch {
            errorMessage = (error as? OdooError)?.errorDescription ?? "Une erreur est survenue. Réessayez plus tard."
        }
    }
}

struct ActivateAccountView: View {
    @StateObject private var vm = ActivateAccountViewModel()
    @FocusState private var focused: Bool

    /// Email pré-rempli (ex. depuis l'écran d'inscription).
    var prefillEmail: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                if vm.didSend {
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
        .navigationTitle("Activer mon compte")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if vm.email.isEmpty { vm.email = prefillEmail } }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "key.fill")
                .font(.system(size: 30))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(Color.brandNavy, in: Circle())
            Text("Vous êtes déjà membre ?")
                .font(.title3.bold())
                .foregroundStyle(Color.brandNavy)
            Text("Entrez votre adresse email pour recevoir un lien d'activation de votre compte.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Adresse email")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("votre.email@exemple.fr", text: $vm.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 10))
            }

            if let error = vm.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button {
                focused = false
                Task { await vm.submit() }
            } label: {
                ZStack {
                    Text("Recevoir le lien d'activation")
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

    private var successBanner: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.green)
            Text("Email envoyé")
                .font(.headline)
            Text("Si votre adresse email est enregistrée, vous recevrez un email avec les instructions pour activer votre compte.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.green.opacity(0.1), in: .rect(cornerRadius: 16))
    }
}
