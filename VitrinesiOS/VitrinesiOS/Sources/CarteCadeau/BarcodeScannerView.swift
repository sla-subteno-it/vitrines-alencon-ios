// BarcodeScannerView.swift
// Vitrines d'Alençon — iOS
// Scan de code-barres via VisionKit (DataScannerViewController).

import SwiftUI
import VisionKit

/// Sheet plein écran présentant le flux caméra et capturant le premier code-barres lu.
struct BarcodeScannerView: View {
    let onScan: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                DataScannerRepresentable { code in
                    onScan(code)
                    dismiss()
                }
                .ignoresSafeArea()

                // Cadre de visée
                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.85), lineWidth: 2)
                        .frame(width: 260, height: 110)
                    Text("Placez le code-barres dans le cadre")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(.top, 12)
                    Spacer()
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                    Text("Le scan n'est pas disponible sur cet appareil.")
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }
}

/// Wrapper UIKit du DataScannerViewController.
private struct DataScannerRepresentable: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        try? uiViewController.startScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        private var didScan = false

        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            handle(addedItems)
        }

        private func handle(_ items: [RecognizedItem]) {
            guard !didScan else { return }
            for item in items {
                if case let .barcode(barcode) = item,
                   let value = barcode.payloadStringValue,
                   !value.isEmpty {
                    didScan = true
                    onScan(value)
                    break
                }
            }
        }
    }
}
