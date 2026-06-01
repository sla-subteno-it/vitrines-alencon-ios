// CarteCadeauView.swift
// Vitrines d'Alençon — iOS
// Page carte cadeau (réplique de /scanner-carte-cadeau).

import SwiftUI
import AVFoundation

struct CarteCadeauView: View {
    @StateObject private var vm = CarteCadeauViewModel()

    @State private var showScanner = false
    @State private var showManual = false
    @State private var manualNumber = ""
    @State private var showCameraDeniedAlert = false
    @State private var showInfo = false
    @FocusState private var manualFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                scannerSection
                if showManual { manualSection }
                if vm.isScanning { loadingState }
                if let error = vm.scanError { errorState(error) }
                if !vm.giftCards.isEmpty { myCardsSection }
            }
            .padding(20)
        }
        .aboveTabBar()
        .background(Color.brandSurface.ignoresSafeArea())
        .navigationTitle("Scanner carte cadeau")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.loadGiftCards() }
        .refreshable { await vm.loadGiftCards() }
        .fullScreenCover(isPresented: $showScanner) {
            BarcodeScannerView { code in
                Task { await vm.scan(cardnumber: code) }
            }
        }
        .sheet(isPresented: Binding(
            get: { vm.scanResult != nil },
            set: { if !$0 { vm.clearResult() } }
        )) {
            if let result = vm.scanResult, let info = result.giftcard {
                NavigationStack {
                    GiftCardResultView(
                        info: info,
                        events: result.events ?? [],
                        linked: result.linked ?? false
                    )
                }
            }
        }
        .alert("Caméra désactivée", isPresented: $showCameraDeniedAlert) {
            Button("Annuler", role: .cancel) {}
            Button("Réglages") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("Autorisez l'accès à la caméra dans les Réglages pour scanner une carte cadeau.")
        }
        .sheet(isPresented: $showInfo) { infoSheet }
    }

    // MARK: - Section scanner

    private var scannerSection: some View {
        VStack(spacing: 16) {
            Image("CarteCadeauRecto")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 220)
                .opacity(0.9)

            Text("Scannez le code-barres de votre carte cadeau pour voir son solde et son historique.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showInfo = true
            } label: {
                Label("C'est quoi la carte cadeau ?", systemImage: "questionmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button {
                startScanFlow()
            } label: {
                Label("Scanner une carte", systemImage: "camera.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .background(Color.brandNavy, in: .rect(cornerRadius: 12))
            .foregroundStyle(.white)

            Button {
                withAnimation { showManual.toggle() }
                if showManual { manualFocused = true }
            } label: {
                Label("Saisir manuellement", systemImage: "keyboard")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Saisie manuelle

    private var manualSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Saisie manuelle", systemImage: "keyboard")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("Numéro de carte")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("Entrez le numéro de la carte", text: $manualNumber)
                    .keyboardType(.numberPad)
                    .focused($manualFocused)
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 10))
            }

            HStack(spacing: 12) {
                Button {
                    manualFocused = false
                    let number = manualNumber
                    Task { await vm.scan(cardnumber: number) }
                } label: {
                    Label("Rechercher", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .background(Color.brandNavy, in: .rect(cornerRadius: 10))
                .foregroundStyle(.white)
                .disabled(manualNumber.trimmingCharacters(in: .whitespaces).isEmpty)

                Button {
                    manualFocused = false
                    startScanFlow()
                } label: {
                    Label("Scanner", systemImage: "camera")
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                }
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.4)))
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - États

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView().tint(.brandRed)
            Text("Recherche de la carte en cours…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 24)
    }

    private func errorState(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.subheadline)
            Spacer()
        }
        .padding(14)
        .background(Color.red.opacity(0.1), in: .rect(cornerRadius: 12))
    }

    // MARK: - Mes cartes cadeaux

    private var myCardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Mes cartes cadeaux", systemImage: "gift.fill")
                .font(.headline)
                .foregroundStyle(Color.brandRed)

            ForEach(vm.giftCards) { card in
                Button {
                    Task { await vm.scan(cardnumber: card.cardnumber) }
                } label: {
                    GiftCardRow(card: card)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var infoSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Image("CarteCadeauRecto")
                        .resizable().scaledToFit()
                        .frame(maxWidth: 200)
                        .frame(maxWidth: .infinity)
                    Text("La carte cadeau Vitrines d'Alençon")
                        .font(.title3.bold())
                    Text("La carte cadeau est utilisable chez les commerçants partenaires acceptant la carte cadeau. Scannez son code-barres pour consulter à tout moment son solde disponible et l'historique de ses transactions.")
                        .foregroundStyle(.secondary)
                    Text("Une fois scannée, la carte est associée à votre compte fidélité et apparaît dans « Mes cartes cadeaux ».")
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .navigationTitle("Carte cadeau")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { showInfo = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Permission caméra

    private func startScanFlow() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showScanner = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    if granted { showScanner = true } else { showCameraDeniedAlert = true }
                }
            }
        default:
            showCameraDeniedAlert = true
        }
    }
}

// MARK: - Ligne de carte cadeau (liste)

private struct GiftCardRow: View {
    let card: GiftCard

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "creditcard.fill")
                .font(.title2)
                .foregroundStyle(Color.brandNavy)

            VStack(alignment: .leading, spacing: 3) {
                Text(card.cardnumber)
                    .font(.subheadline.weight(.semibold))
                if let date = GiftCardFormat.frenchDate(card.endDate) {
                    Text("Valide jusqu'au \(date)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(GiftCardFormat.euros(card.credit))
                    .font(.headline)
                    .foregroundStyle(Color.brandRed)
                StatusBadge(label: card.statusLabel, isActive: !card.isExpired && card.status == "ACTIVE")
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }
}

struct StatusBadge: View {
    let label: String
    let isActive: Bool

    var body: some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background((isActive ? Color.green : Color.gray).opacity(0.18), in: Capsule())
            .foregroundStyle(isActive ? .green : .gray)
    }
}
