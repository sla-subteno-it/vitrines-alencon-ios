// MerchantsMapView.swift
// Vitrines d'Alençon — iOS
// Carte des commerçants (MapKit natif, sans clé API).
// Place un repère par commerçant à partir des coordonnées Odoo
// (partner_latitude/longitude) ; pour ceux qui n'en ont pas, géocode l'adresse
// côté appareil (CLGeocoder, avec cache mémoire). Tap sur un repère → carte de
// sélection en bas → fiche commerçant. Bouton « Autour de moi » (géoloc).

import SwiftUI
import MapKit
import Combine

/// Centre d'Alençon (place de l'hôtel de ville).
private let alenconCenter = CLLocationCoordinate2D(latitude: 48.4304, longitude: 0.0915)

struct MerchantsMapView: View {
    let merchants: [Merchant]
    let brandNames: (Merchant) -> [String]
    /// Ouvre la fiche commerçant (le parent l'ajoute au NavigationPath).
    let onOpenMerchant: (Merchant) -> Void

    @State private var camera: MapCameraPosition = .region(
        MKCoordinateRegion(center: alenconCenter,
                           span: MKCoordinateSpan(latitudeDelta: 0.045, longitudeDelta: 0.045))
    )
    @State private var selectedId: Int?
    /// Coordonnées géocodées pour les commerçants sans coords Odoo (cache).
    @State private var geocoded: [Int: CLLocationCoordinate2D] = [:]
    @StateObject private var location = LocationManager()

    /// Map id → coordonnée (Odoo prioritaire, sinon géocodée).
    private var positions: [Int: CLLocationCoordinate2D] {
        var map: [Int: CLLocationCoordinate2D] = [:]
        for m in merchants {
            if let c = m.coordinate { map[m.id] = c }
            else if let c = geocoded[m.id] { map[m.id] = c }
        }
        return map
    }

    /// Commerçants effectivement positionnables (coords Odoo ou géocodées).
    private var placedMerchants: [Merchant] {
        let map = positions
        return merchants.filter { map[$0.id] != nil }
    }

    private var selectedMerchant: Merchant? {
        guard let id = selectedId else { return nil }
        return merchants.first { $0.id == id }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $camera, selection: $selectedId) {
                let placed = positions
                ForEach(placedMerchants) { m in
                    Marker(m.name, systemImage: "bag.fill", coordinate: placed[m.id]!)
                        .tint(Color.brandRed)
                        .tag(m.id)
                }
                UserAnnotation()
            }
            .mapControls {
                MapCompass()
                MapUserLocationButton()
            }
            .ignoresSafeArea(edges: .bottom)

            if let merchant = selectedMerchant {
                selectionCard(merchant)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                aroundMeButton
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedId)
        .task { await geocodeMissing() }
        .onChange(of: location.lastLocation) { _, loc in
            guard let loc else { return }
            withAnimation {
                camera = .region(MKCoordinateRegion(
                    center: loc.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))
            }
        }
    }

    // MARK: - Bouton « Autour de moi »

    private var aroundMeButton: some View {
        Button {
            location.requestAndLocate()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .font(.system(size: 15, weight: .semibold))
                Text("Autour de moi")
                    .font(BrandFont.sans(15, weight: .semibold))
            }
            .foregroundStyle(Color.brandNavy)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.white, in: .capsule)
            .overlay(Capsule().stroke(Color.brandNavy.opacity(0.08), lineWidth: 1))
            .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
        }
        .padding(.bottom, 24)
    }

    // MARK: - Carte de sélection (callout en bas)

    private func selectionCard(_ merchant: Merchant) -> some View {
        Button {
            onOpenMerchant(merchant)
        } label: {
            HStack(spacing: 12) {
                AsyncImage(url: merchant.imageURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Color.brandSurface2
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 3) {
                    Text(merchant.name)
                        .font(BrandFont.serif(17, weight: .bold))
                        .foregroundStyle(Color.brandNavy)
                        .lineLimit(1)
                    if let address = merchant.formattedAddress {
                        Text(address)
                            .font(BrandFont.sans(13))
                            .foregroundStyle(Color.brandTextMuted)
                            .lineLimit(1)
                    }
                    let brands = brandNames(merchant)
                    if !brands.isEmpty {
                        Text(brands.prefix(3).joined(separator: " · "))
                            .font(BrandFont.sans(12, weight: .medium))
                            .foregroundStyle(Color.brandRed)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.brandTextMuted)
            }
            .padding(12)
            .background(.white, in: .rect(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.brandNavy.opacity(0.06), lineWidth: 1))
            .shadow(color: .black.opacity(0.15), radius: 14, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }

    // MARK: - Géocodage des commerçants sans coordonnées Odoo

    private func geocodeMissing() async {
        let geocoder = CLGeocoder()
        for m in merchants {
            if m.coordinate != nil || geocoded[m.id] != nil { continue }
            guard let address = m.formattedAddress else { continue }
            if let placemarks = try? await geocoder.geocodeAddressString("\(address), France"),
               let coord = placemarks.first?.location?.coordinate {
                geocoded[m.id] = coord
            }
            // CLGeocoder est strictement limité en débit → on espace les requêtes.
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
    }
}

// MARK: - Gestion de la localisation

@MainActor
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var lastLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Demande l'autorisation si besoin puis déclenche une localisation ponctuelle.
    func requestAndLocate() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break // refusé : MapUserLocationButton reste disponible si déjà autorisé
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in self.lastLocation = loc }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
