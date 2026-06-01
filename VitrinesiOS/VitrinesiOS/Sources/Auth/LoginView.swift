// LoginView.swift
// Vitrines d'Alençon — iOS
// Écran de connexion (identifiant Odoo → session).

import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header

                VStack(spacing: 16) {
                    emailField
                    passwordField

                    if let error = auth.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity)
                    }

                    loginButton
                }
            }
            .padding(24)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
        .animation(.default, value: auth.errorMessage)
    }

    // MARK: - Sous-vues

    private var header: some View {
        VStack(spacing: 12) {
            Image("VitrinesLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 180)
                .padding(.top, 32)
            Text("Connectez-vous pour accéder à votre carte fidélité et vos avantages.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Identifiant")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField("email@exemple.fr", text: $auth.email)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
                .onSubmit { focusedField = .password }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Mot de passe")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            SecureField("••••••••", text: $auth.password)
                .textContentType(.password)
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit { submit() }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
        }
    }

    private var loginButton: some View {
        Button(action: submit) {
            ZStack {
                Text("Se connecter")
                    .fontWeight(.semibold)
                    .opacity(auth.isLoading ? 0 : 1)
                if auth.isLoading {
                    ProgressView()
                        .tint(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.accentColor)
        .disabled(auth.isLoading)
        .padding(.top, 8)
    }

    // MARK: - Action

    private func submit() {
        focusedField = nil
        Task { await auth.login() }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
