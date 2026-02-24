//
//  ClientMapPageView.swift
//  Play'In
//
//  Created by Thibault Serdet on 23/02/2026.
//

import SwiftUI
import Combine
import MapKit
import CoreLocation
import Supabase
import PostgREST

// MARK: - Async helpers

extension MKDirections {
  func calculateETAAsync() async throws -> MKDirections.ETAResponse {
    try await withCheckedThrowingContinuation { cont in
      self.calculateETA { response, error in
        if let error { cont.resume(throwing: error); return }
        if let response { cont.resume(returning: response); return }
        cont.resume(throwing: URLError(.badServerResponse))
      }
    }
  }
}

// MARK: - Models

struct ClientActivityRow: Decodable, Hashable {
  let label: String?
  let emoji: String?
}

struct ClientComplexOfferJoinRow: Decodable, Identifiable {
  let id: UUID
  let activities: ClientActivityRow?

  enum CodingKeys: String, CodingKey {
    case id = "complex_id"
    case activities
  }
}

struct ClientMapComplexRaw: Decodable, Identifiable {
  let id: UUID
  let name: String?
  let city: String?
  let country: String?
  let postalCode: String?
  let addressFull: String?
  let bio: String?
  let website: String?
  let phone: String?
  let latitude: Double?
  let longitude: Double?
  let photos: [String]

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case city
    case country
    case postalCode = "postal_code"
    case addressFull = "address_full"
    case bio
    case website
    case phone
    case latitude
    case longitude
    case photos
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)

    id = try c.decode(UUID.self, forKey: .id)
    name = try c.decodeIfPresent(String.self, forKey: .name)
    city = try c.decodeIfPresent(String.self, forKey: .city)
    country = try c.decodeIfPresent(String.self, forKey: .country)
    postalCode = try c.decodeIfPresent(String.self, forKey: .postalCode)
    addressFull = try c.decodeIfPresent(String.self, forKey: .addressFull)
    bio = try c.decodeIfPresent(String.self, forKey: .bio)
    website = try c.decodeIfPresent(String.self, forKey: .website)
    phone = try c.decodeIfPresent(String.self, forKey: .phone)
    latitude = try c.decodeIfPresent(Double.self, forKey: .latitude)
    longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)

    if let arr = try? c.decodeIfPresent([String].self, forKey: .photos) {
      photos = arr
    } else if let s = try? c.decodeIfPresent(String.self, forKey: .photos) {
      let parts = s
        .split(whereSeparator: { $0 == "," || $0 == ";" || $0 == "|" || $0 == "\n" })
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
      photos = parts
    } else {
      photos = []
    }
  }
}

struct ClientActivity: Hashable {
  let label: String
  let emoji: String
}

struct ClientMapComplex: Identifiable, Hashable {
  let id: UUID
  let name: String
  let city: String?
  let country: String?
  let postalCode: String?
  let addressFull: String?
  let bio: String?
  let website: String?
  let phone: String?
  let latitude: Double
  let longitude: Double
  let photos: [String]
  let activities: [ClientActivity]

  var coordinate: CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }
}

// MARK: - Location

final class ClientLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
  @Published var authorizationStatus: CLAuthorizationStatus
  @Published var location: CLLocation?

  private let manager: CLLocationManager

  override init() {
    let manager = CLLocationManager()
    self.manager = manager
    self.authorizationStatus = manager.authorizationStatus
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    manager.distanceFilter = 25
  }

  func start() {
    if authorizationStatus == .notDetermined {
      manager.requestWhenInUseAuthorization()
    }
    manager.startUpdatingLocation()
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    authorizationStatus = manager.authorizationStatus
    if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
      manager.startUpdatingLocation()
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    location = locations.last
  }
}

// MARK: - ViewModel

@MainActor
final class ClientMapViewModel: ObservableObject {
  @Published var complexes: [ClientMapComplex] = []
  @Published var isLoading: Bool = false
  @Published var errorMessage: String?

  private var lastBoxKey: String?

  func loadComplexes(in region: MKCoordinateRegion) async {
    let box = regionBoundingBox(region: region)
    let key = "\(round6(box.minLat))_\(round6(box.maxLat))_\(round6(box.minLng))_\(round6(box.maxLng))"
    if key == lastBoxKey { return }
    lastBoxKey = key

    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      let raws: [ClientMapComplexRaw] = try await SupabaseService.shared.client
        .from("complexes")
        .select("id,name,city,country,postal_code,address_full,bio,website,phone,latitude,longitude,photos")
        .gte("latitude", value: box.minLat)
        .lte("latitude", value: box.maxLat)
        .gte("longitude", value: box.minLng)
        .lte("longitude", value: box.maxLng)
        .limit(400)
        .execute()
        .value

      let ids = raws.map(\.id)
      if ids.isEmpty {
        complexes = []
        return
      }

      let joinRows: [ClientComplexOfferJoinRow] = try await SupabaseService.shared.client
        .from("complex_activity_offers")
        .select("complex_id,activities(label,emoji)")
        .eq("is_active", value: true)
        .in("complex_id", values: ids)
        .execute()
        .value

      var activitiesByComplex: [UUID: [ClientActivity]] = [:]
      activitiesByComplex.reserveCapacity(256)

      for row in joinRows {
        guard
          let labelRaw = row.activities?.label?.trimmingCharacters(in: .whitespacesAndNewlines),
          !labelRaw.isEmpty
        else { continue }

        let emojiRaw = (row.activities?.emoji?.trimmingCharacters(in: .whitespacesAndNewlines))
          .flatMap { $0.isEmpty ? nil : $0 } ?? "🏟️"

        let activity = ClientActivity(label: labelRaw, emoji: emojiRaw)

        var arr = activitiesByComplex[row.id] ?? []
        if !arr.contains(activity) {
          arr.append(activity)
          activitiesByComplex[row.id] = arr
        }
      }

      complexes = raws.compactMap { raw in
        guard let lat = raw.latitude, let lng = raw.longitude else { return nil }
        let title = (raw.name?.trimmingCharacters(in: .whitespacesAndNewlines))
          .flatMap { $0.isEmpty ? nil : $0 } ?? "Complexe"

        let acts = activitiesByComplex[raw.id] ?? []

        return ClientMapComplex(
          id: raw.id,
          name: title,
          city: raw.city,
          country: raw.country,
          postalCode: raw.postalCode,
          addressFull: raw.addressFull,
          bio: raw.bio,
          website: raw.website,
          phone: raw.phone,
          latitude: lat,
          longitude: lng,
          photos: raw.photos,
          activities: acts
        )
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func round6(_ x: Double) -> Double {
    (x * 1_000_000).rounded() / 1_000_000
  }

  private func regionBoundingBox(region: MKCoordinateRegion) -> (minLat: Double, maxLat: Double, minLng: Double, maxLng: Double) {
    let center = region.center
    let span = region.span
    let minLat = center.latitude - span.latitudeDelta / 2
    let maxLat = center.latitude + span.latitudeDelta / 2
    let minLng = center.longitude - span.longitudeDelta / 2
    let maxLng = center.longitude + span.longitudeDelta / 2
    return (minLat, maxLat, minLng, maxLng)
  }
}

// MARK: - Preferences (tooltip anchors)

private struct ActivityAnchorPreferenceKey: PreferenceKey {
  static var defaultValue: [String: Anchor<CGRect>] = [:]
  static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
    value.merge(nextValue(), uniquingKeysWith: { $1 })
  }
}

// MARK: - Annotation view

struct ClientMapComplexAnnotationView: View {
  let complex: ClientMapComplex

  var body: some View {
    Text(emojiLine)
      .font(.system(size: 18, weight: .semibold))
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .background(.ultraThinMaterial)
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .strokeBorder(.white.opacity(0.18), lineWidth: 1)
      )
      .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
  }

  private var emojiLine: String {
    let emojis = complex.activities.map { $0.emoji }.filter { !$0.isEmpty }
    let unique = Array(NSOrderedSet(array: emojis)) as? [String] ?? emojis
    if unique.isEmpty { return "🏟️" }
    let firstTwo = unique.prefix(2).joined()
    if unique.count > 2 { return firstTwo + "…" }
    return firstTwo
  }
}

// MARK: - Sheet view (fiche complexe)

struct ClientComplexSheetView: View {
  let complex: ClientMapComplex
  let userLocation: CLLocation?

  @Environment(\.openURL) private var openURL
  @State private var selectedTab: SheetTab = .promotions

  @State private var driveTimeText: String?
  @State private var isDriveTimeLoading: Bool = false
  @State private var showDirectionsPicker: Bool = false

  // ✅ Tooltips indépendants (un token par activité) + "pop"
  @State private var tooltipTokensByLabel: [String: UUID] = [:]
  @State private var tooltipPopByLabel: [String: Bool] = [:]

  enum SheetTab: String, CaseIterable, Identifiable {
    case promotions = "Promotions"
    case about = "À propos"
    var id: String { rawValue }
  }

  private let cardBg = Color(.secondarySystemBackground)
  private let border = Color.black.opacity(0.08)

  var body: some View {
    ScrollView(showsIndicators: false) {
      VStack(alignment: .leading, spacing: 14) {
        VStack(alignment: .leading, spacing: 10) {
          Text(complex.name)
            .font(.title2)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 28)

          if !complex.activities.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 10) {
                ForEach(complex.activities, id: \.label) { a in
                  Button {
                    showTooltip(for: a)
                  } label: {
                    Text(a.emoji)
                      .font(.system(size: 18, weight: .semibold))
                      .frame(width: 40, height: 34)
                      .background(cardBg)
                      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                      .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                          .strokeBorder(border, lineWidth: 1)
                      )
                  }
                  .buttonStyle(.plain)
                  .anchorPreference(key: ActivityAnchorPreferenceKey.self, value: .bounds) { anchor in
                    [a.label: anchor]
                  }
                }
              }
              .padding(.vertical, 2)
            }
          }

          if isDriveTimeLoading {
            HStack(spacing: 6) {
              Image(systemName: "car.fill")
              Text("…")
            }
            .foregroundStyle(.secondary)
          } else if let t = driveTimeText {
            HStack(spacing: 6) {
              Image(systemName: "car.fill")
              Text(t)
            }
            .foregroundStyle(.secondary)
          }
        }
        .padding(.horizontal, 16)

        if !complex.photos.isEmpty {
          ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
              ForEach(complex.photos, id: \.self) { url in
                ClientComplexHeroPhoto(urlString: url)
              }
            }
            .padding(.horizontal, 16)
          }
        }

        HStack(spacing: 12) {
          Button { callComplex() } label: {
            HStack(spacing: 10) {
              Image(systemName: "phone.fill")
              Text("Appeler").fontWeight(.semibold)
              Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
              RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(border, lineWidth: 1)
            )
          }
          .disabled(!canCall)

          Button { openWebsite() } label: {
            HStack(spacing: 10) {
              Image(systemName: "calendar.badge.plus")
              Text("Réserver").fontWeight(.semibold)
              Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
              RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(border, lineWidth: 1)
            )
          }
          .disabled(websiteURL == nil)
          .opacity(websiteURL == nil ? 0.45 : 1)
        }
        .padding(.horizontal, 16)

        Picker("", selection: $selectedTab) {
          ForEach(SheetTab.allCases) { tab in
            Text(tab.rawValue).tag(tab)
          }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.top, 6)

        Group {
          switch selectedTab {
          case .promotions:
            PromotionsPlaceholder(cardBg: cardBg, border: border)
              .padding(.horizontal, 16)
              .padding(.top, 6)

          case .about:
            AboutBlock(
              cardBg: cardBg,
              border: border,
              bio: bioText,
              address: addressText,
              placeLine: placeLine,
              phone: phonePretty,
              websiteURL: websiteURL,
              canCall: canCall,
              onCall: callComplex,
              onDirections: { showDirectionsPicker = true }
            )
            .padding(.horizontal, 16)
            .padding(.top, 6)
          }
        }

        Spacer(minLength: 10)
      }
      .padding(.bottom, 18)
    }
    .background(Color.white.ignoresSafeArea())
    .preferredColorScheme(.light)
    .task(id: etaTaskKey) { await updateDriveTime() }
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    .confirmationDialog("Ouvrir l’itinéraire dans…", isPresented: $showDirectionsPicker, titleVisibility: .visible) {
      Button("Plans (Apple)") { openInAppleMaps() }
      Button("Google Maps") { openInGoogleMaps() }
      Button("Waze") { openInWaze() }
      Button("Annuler", role: .cancel) {}
    }
    // ✅ Tooltips overlay + pop animation
    .overlayPreferenceValue(ActivityAnchorPreferenceKey.self) { anchors in
      GeometryReader { proxy in
        ForEach(Array(tooltipTokensByLabel.keys), id: \.self) { label in
          if let anchor = anchors[label] {
            let rect = proxy[anchor]
            let popped = tooltipPopByLabel[label] ?? false

            Text(label)
              .font(.caption)
              .fontWeight(.semibold)
              .foregroundStyle(.white)
              .padding(.horizontal, 12)
              .padding(.vertical, 8)
              .background(Color.black.opacity(0.92))
              .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
              .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 4)
              .scaleEffect(popped ? 1.0 : 0.92)
              .opacity(popped ? 1.0 : 0.0)
              .position(x: rect.midX, y: rect.minY - 18)
              .allowsHitTesting(false)
              // pop: on anime quand le token change
              .animation(.spring(response: 0.22, dampingFraction: 0.72), value: tooltipTokensByLabel[label])
          }
        }
      }
    }
  }

  // ✅ Show tooltip: token + trigger pop
  private func showTooltip(for activity: ClientActivity) {
    let label = activity.label
    let token = UUID()
    tooltipTokensByLabel[label] = token

    // reset then pop
    tooltipPopByLabel[label] = false
    DispatchQueue.main.async {
      tooltipPopByLabel[label] = true
    }

    Task {
      try? await Task.sleep(nanoseconds: 1_200_000_000)
      await MainActor.run {
        guard tooltipTokensByLabel[label] == token else { return }
        tooltipTokensByLabel.removeValue(forKey: label)
        tooltipPopByLabel.removeValue(forKey: label)
      }
    }
  }

  private var bioText: String? {
    let t = (complex.bio ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    return t.isEmpty ? nil : t
  }

  private var addressText: String? {
    let t = (complex.addressFull ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    return t.isEmpty ? nil : t
  }

  private var placeLine: String? {
    var parts: [String] = []
    if let city = complex.city, !city.isEmpty { parts.append(city) }
    if let postal = complex.postalCode, !postal.isEmpty { parts.append(postal) }
    if let country = complex.country, !country.isEmpty { parts.append(country) }
    let s = parts.joined(separator: " • ")
    return s.isEmpty ? nil : s
  }

  private var phonePretty: String? {
    let raw = (complex.phone ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    return raw.isEmpty ? nil : raw
  }

  private var websiteURL: URL? {
    guard let raw = complex.website?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
    if raw.lowercased().hasPrefix("http://") || raw.lowercased().hasPrefix("https://") {
      return URL(string: raw)
    }
    return URL(string: "https://\(raw)")
  }

  private func openWebsite() {
    guard let url = websiteURL else { return }
    openURL(url)
  }

  private var canCall: Bool {
    let p = (complex.phone ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    return !p.isEmpty && phoneURL != nil
  }

  private var phoneURL: URL? {
    let raw = (complex.phone ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if raw.isEmpty { return nil }
    let allowed = CharacterSet(charactersIn: "+0123456789")
    let filtered = raw.unicodeScalars.filter { allowed.contains($0) }
    let digits = String(String.UnicodeScalarView(filtered))
    if digits.isEmpty { return nil }
    return URL(string: "tel://\(digits)")
  }

  private func callComplex() {
    guard let url = phoneURL else { return }
    openURL(url)
  }

  private var encodedDestination: String {
    if let addr = complex.addressFull?.trimmingCharacters(in: .whitespacesAndNewlines), !addr.isEmpty {
      return addr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    }
    return "\(complex.latitude),\(complex.longitude)"
  }

  private func openInAppleMaps() {
    let url = URL(string: "http://maps.apple.com/?daddr=\(encodedDestination)")!
    openURL(url)
  }

  private func openInGoogleMaps() {
    let url = URL(string: "comgooglemaps://?daddr=\(encodedDestination)&directionsmode=driving")!
    openURL(url)
  }

  private func openInWaze() {
    let url = URL(string: "waze://?q=\(encodedDestination)&navigate=yes")!
    openURL(url)
  }

  private var etaTaskKey: String {
    let lat = userLocation?.coordinate.latitude ?? 0
    let lng = userLocation?.coordinate.longitude ?? 0
    return "\(complex.id.uuidString)-\(String(format: "%.3f", lat))-\(String(format: "%.3f", lng))"
  }

  private func updateDriveTime() async {
    guard let userLocation else {
      driveTimeText = nil
      return
    }

    isDriveTimeLoading = true
    defer { isDriveTimeLoading = false }

    let req = MKDirections.Request()
    req.source = MKMapItem(placemark: MKPlacemark(coordinate: userLocation.coordinate))
    req.destination = MKMapItem(placemark: MKPlacemark(coordinate: complex.coordinate))
    req.transportType = .automobile
    req.requestsAlternateRoutes = false

    let directions = MKDirections(request: req)

    do {
      let eta = try await directions.calculateETAAsync()
      driveTimeText = formattedTravelTime(seconds: eta.expectedTravelTime)
    } catch {
      driveTimeText = nil
    }
  }

  private func formattedTravelTime(seconds: TimeInterval) -> String {
    let f = DateComponentsFormatter()
    f.unitsStyle = .abbreviated
    f.allowedUnits = seconds >= 3600 ? [.hour, .minute] : [.minute]
    f.maximumUnitCount = 2
    return f.string(from: seconds) ?? "\(max(1, Int(seconds / 60))) min"
  }
}

// MARK: - Promotions placeholder

private struct PromotionsPlaceholder: View {
  let cardBg: Color
  let border: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Promotions")
        .font(.headline)
      Text("Aucune promotion pour le moment.")
        .foregroundStyle(.secondary)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(cardBg)
    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .strokeBorder(border, lineWidth: 1)
    )
  }
}

// MARK: - About block

private struct AboutBlock: View {
  let cardBg: Color
  let border: Color

  let bio: String?
  let address: String?
  let placeLine: String?
  let phone: String?
  let websiteURL: URL?
  let canCall: Bool
  let onCall: () -> Void
  let onDirections: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("À propos")
        .font(.headline)

      if let bio {
        Text(bio)
          .foregroundStyle(.secondary)
      }

      if let address {
        InfoRow(icon: "mappin.and.ellipse", title: "Adresse", value: address)
      }

      if let placeLine {
        InfoRow(icon: "globe.europe.africa.fill", title: "Lieu", value: placeLine)
      }

      if let phone {
        Button(action: onCall) {
          InfoRow(icon: "phone.fill", title: "Téléphone", value: phone, isInteractive: true)
        }
        .buttonStyle(.plain)
        .disabled(!canCall)
        .opacity(canCall ? 1 : 0.45)
      }

      Button(action: onDirections) {
        HStack(spacing: 10) {
          Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
            .frame(width: 22)
            .foregroundStyle(.primary)
          Text("Itinéraire")
            .fontWeight(.semibold)
          Spacer()
          Image(systemName: "chevron.right")
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
      }
      .buttonStyle(.plain)

      if let websiteURL {
        Link(destination: websiteURL) {
          InfoRow(icon: "link", title: "Site", value: websiteURL.absoluteString, isInteractive: true)
        }
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(cardBg)
    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .strokeBorder(border, lineWidth: 1)
    )
  }
}

private struct InfoRow: View {
  let icon: String
  let title: String
  let value: String
  var isInteractive: Bool = false

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: icon)
        .frame(width: 22)
        .foregroundStyle(isInteractive ? .primary : .secondary)

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.subheadline)
          .foregroundStyle(.secondary)
        Text(value)
          .font(.body)
          .foregroundStyle(isInteractive ? .primary : .secondary)
          .lineLimit(3)
      }

      Spacer(minLength: 0)
    }
    .padding(.vertical, 4)
  }
}

// MARK: - Photos (hero)

struct ClientComplexHeroPhoto: View {
  let urlString: String

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .fill(Color(.secondarySystemBackground))

      if let url = URL(string: urlString) {
        AsyncImage(url: url) { phase in
          switch phase {
          case .success(let image):
            image.resizable().scaledToFill()
          default:
            Color.clear
          }
        }
        .frame(width: 320, height: 200)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
      } else {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
          .fill(Color(.secondarySystemBackground))
          .frame(width: 320, height: 200)
      }
    }
    .frame(width: 320, height: 200)
  }
}

// MARK: - Map page

struct ClientMapPageView: View {
  @StateObject private var viewModel = ClientMapViewModel()
  @StateObject private var locationManager = ClientLocationManager()

  @State private var position: MapCameraPosition = .region(
    MKCoordinateRegion(
      center: CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522),
      span: MKCoordinateSpan(latitudeDelta: 0.10, longitudeDelta: 0.10)
    )
  )

  @State private var hasCenteredOnUser: Bool = false
  @State private var selectedComplex: ClientMapComplex?

  @State private var region: MKCoordinateRegion = MKCoordinateRegion(
    center: CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522),
    span: MKCoordinateSpan(latitudeDelta: 0.10, longitudeDelta: 0.10)
  )

  @State private var lastQueryAt: Date = .distantPast
  @State private var pendingRecenter: Bool = false

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      Map(position: $position, interactionModes: .all, selection: $selectedComplex) {
        UserAnnotation()

        ForEach(viewModel.complexes) { complex in
          Annotation("", coordinate: complex.coordinate) {
            ClientMapComplexAnnotationView(complex: complex)
          }
          .tag(complex)
        }
      }
      .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
      .ignoresSafeArea()
      .sheet(item: $selectedComplex, onDismiss: { selectedComplex = nil }) { complex in
        ClientComplexSheetView(complex: complex, userLocation: locationManager.location)
      }
      .onMapCameraChange { ctx in
        region = ctx.region
        let now = Date()
        if now.timeIntervalSince(lastQueryAt) < 0.6 { return }
        lastQueryAt = now
        Task { await viewModel.loadComplexes(in: region) }
      }

      Button {
        recenter()
      } label: {
        Image(systemName: "location.fill")
          .font(.system(size: 16, weight: .bold))
          .foregroundStyle(.primary)
          .frame(width: 44, height: 44)
          .background(.ultraThinMaterial)
          .clipShape(Circle())
          .overlay(
            Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1)
          )
          .shadow(radius: 10, y: 6)
      }
      .padding(.trailing, 16)
      .padding(.bottom, 22)

      if viewModel.isLoading {
        ProgressView()
          .padding(12)
          .background(.ultraThinMaterial)
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
          .padding(.leading, 16)
          .padding(.bottom, 22)
          .frame(maxWidth: .infinity, alignment: .bottomLeading)
      }
    }
    .task {
      locationManager.start()
      await viewModel.loadComplexes(in: region)
    }
    .onReceive(locationManager.$location.compactMap { $0 }) { loc in
      if pendingRecenter {
        pendingRecenter = false
        recenter(to: loc)
        return
      }

      if !hasCenteredOnUser {
        hasCenteredOnUser = true
        recenter(to: loc)
      }
    }
  }

  private func recenter() {
    if let loc = locationManager.location {
      recenter(to: loc)
      return
    }

    pendingRecenter = true
    locationManager.start()
  }

  private func recenter(to loc: CLLocation) {
    let r = MKCoordinateRegion(
      center: loc.coordinate,
      span: MKCoordinateSpan(latitudeDelta: 0.10, longitudeDelta: 0.10)
    )
    region = r
    position = .region(r)
    Task { await viewModel.loadComplexes(in: r) }
  }
}
