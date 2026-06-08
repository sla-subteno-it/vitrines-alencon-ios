// LoginView.swift
// Vitrines d'Alençon — iOS
// Écran de connexion (identifiant Odoo → session).

import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    #if DEBUG
    @State private var environment: OdooEnvironment = OdooConfig.environment
    #endif

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header

                VStack(spacing: 16) {
                    #if DEBUG
                    debugEnvironmentPicker
                    #endif
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
                    forgotPasswordButton
                }
            }
            .padding(24)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
        .animation(.default, value: auth.errorMessage)
        .sheet(isPresented: $auth.showResetSheet) {
            ResetPasswordSheet().environmentObject(auth)
        }
    }

    // MARK: - Sous-vues

    #if DEBUG
    private var debugEnvironmentPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Environnement (debug)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Picker("Environnement", selection: $environment) {
                ForEach(OdooEnvironment.allCases) { env in
                    Text(env.label).tag(env)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: environment) { _, newValue in
                OdooConfig.environment = newValue
                auth.email = ""
                auth.password = ""
                auth.errorMessage = nil
                LoyaltyCardStore.clear()
                Task { await OdooClient.shared.resetForEnvironmentSwitch() }
            }
            Text(OdooConfig.baseURL)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.bottom, 4)
    }
    #endif

    private var header: some View {
        VStack(spacing: 12) {
            Image("VitrinesLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 180)
                .padding(.top, 32)
                .accessibilityLabel("Les Vitrines d'Alençon")
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
            TextField("", text: $auth.email)
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

    private var forgotPasswordButton: some View {
        Button("Mot de passe oublié ?") {
            focusedField = nil
            auth.openResetSheet()
        }
        .font(.subheadline)
        .tint(Color.accentColor)
    }

    // MARK: - Action

    private func submit() {
        focusedField = nil
        Task { await auth.login() }
    }
}

// MARK: - Feuille « Mot de passe oublié »

private struct ResetPasswordSheet: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Group {
                if auth.resetDone {
                    successContent
                } else {
                    formContent
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Mot de passe oublié")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(auth.resetDone ? "Fermer" : "Annuler") { dismiss() }
                        .disabled(auth.resetLoading)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Saisissez votre identifiant (adresse e-mail). Nous vous enverrons un lien pour réinitialiser votre mot de passe.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("Identifiant", text: $auth.resetEmail)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focused)
                .submitLabel(.go)
                .onSubmit { Task { await auth.requestPasswordReset() } }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
                .disabled(auth.resetLoading)

            if let error = auth.resetError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button {
                focused = false
                Task { await auth.requestPasswordReset() }
            } label: {
                ZStack {
                    Text("Envoyer").fontWeight(.semibold).opacity(auth.resetLoading ? 0 : 1)
                    if auth.resetLoading { ProgressView().tint(.white) }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentColor)
            .disabled(auth.resetLoading)
        }
        .onAppear { focused = true }
        .animation(.default, value: auth.resetError)
    }

    private var successContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.accentColor)
            Text("E-mail envoyé")
                .font(.headline)
            Text("Si un compte correspond à cet identifiant, un e-mail contenant un lien de réinitialisation vient d'être envoyé. Pensez à vérifier vos courriers indésirables.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
