import SwiftUI
import Combine
import MapKit
import CoreLocation
import Supabase
import PostgREST

extension Notification.Name {
  static let clientOpenMyPromotions = Notification.Name("ClientOpenMyPromotions")
}

struct ClientActivityRow: Decodable, Hashable {
  let id: UUID?
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

struct ClientActivity: Hashable, Identifiable {
  let id: UUID
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
  let maxPromoPercent: Int?
  let promotionsCount: Int

  var coordinate: CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }
}

struct AnnotationPromoOffPeakDetail: Decodable {
  let rewardAmount: Int?
  let rewardUnit: String?
  enum CodingKeys: String, CodingKey {
    case rewardAmount = "reward_amount"
    case rewardUnit = "reward_unit"
  }
}

struct AnnotationPromoLoyaltyDetail: Decodable {
  let rewardAmount: Int?
  let rewardUnit: String?
  enum CodingKeys: String, CodingKey {
    case rewardAmount = "reward_amount"
    case rewardUnit = "reward_unit"
  }
}

struct AnnotationPromoRow: Decodable {
  let complexId: UUID
  let offPeak: AnnotationPromoOffPeakDetail?
  let loyalty: AnnotationPromoLoyaltyDetail?
  enum CodingKeys: String, CodingKey {
    case complexId = "complex_id"
    case offPeak = "promotion_off_peak"
    case loyalty = "promotion_loyalty"
  }
}

enum ClientPromotionType: String, Decodable, Hashable {
  case loyalty
  case off_peak
}

enum ClientRewardUnit: String, Decodable, Hashable {
  case session
  case percent
  case euro
  case custom
}

struct ClientPromotionSheetRow: Decodable, Identifiable, Hashable {
  let promotionId: UUID
  let promotionType: ClientPromotionType
  let activityLabel: String
  let activityEmoji: String?
  let requiredSessions: Int?
  let completedSessions: Int?
  let rewardAmount: Int?
  let rewardUnit: ClientRewardUnit?
  let rewardCustomLabel: String?
  let scheduleSummary: String?
  let offPeakWindowId: UUID?
  let scheduledDate: String?
  let validFrom: String?
  let validUntil: String?
  let graceMinutes: Int?

  var id: String {
    switch promotionType {
    case .loyalty:
      return "loyalty-\(promotionId.uuidString)"
    case .off_peak:
      return "offpeak-\(promotionId.uuidString)-\(offPeakWindowId?.uuidString ?? "nil")-\(scheduledDate ?? "nil")"
    }
  }

  enum CodingKeys: String, CodingKey {
    case promotionId = "promotion_id"
    case promotionType = "promotion_type"
    case activityLabel = "activity_label"
    case activityEmoji = "activity_emoji"
    case requiredSessions = "required_sessions"
    case completedSessions = "completed_sessions"
    case rewardAmount = "reward_amount"
    case rewardUnit = "reward_unit"
    case rewardCustomLabel = "reward_custom_label"
    case scheduleSummary = "schedule_summary"
    case offPeakWindowId = "off_peak_window_id"
    case scheduledDate = "scheduled_date"
    case validFrom = "valid_from"
    case validUntil = "valid_until"
    case graceMinutes = "grace_minutes"
  }
}

struct ClientPromotionGroup: Identifiable, Hashable {
  let activity: ClientActivity
  let promotions: [ClientPromotionSheetRow]

  var id: UUID { activity.id }
}

enum ClientPromoGenerateTarget: Identifiable, Hashable {
  case loyalty(ClientPromotionSheetRow, ClientActivity)
  case offPeak(ClientPromotionSheetRow, ClientActivity)

  var id: String {
    switch self {
    case .loyalty(let row, let activity):
      return "loyalty-\(row.promotionId.uuidString)-\(activity.id.uuidString)"
    case .offPeak(let row, let activity):
      return "offpeak-\(row.promotionId.uuidString)-\(activity.id.uuidString)-\(row.offPeakWindowId?.uuidString ?? "nil")-\(row.scheduledDate ?? "nil")"
    }
  }

  var row: ClientPromotionSheetRow {
    switch self {
    case .loyalty(let row, _), .offPeak(let row, _):
      return row
    }
  }

  var activity: ClientActivity {
    switch self {
    case .loyalty(_, let activity), .offPeak(_, let activity):
      return activity
    }
  }
}

struct GeneratedPromotionResult: Identifiable, Hashable {
  let id: UUID
}

struct ClientGeneratedPromotionRow: Decodable, Hashable {
  let id: UUID
  let promotionId: UUID
  let activityId: UUID
  let type: String
  let displayStatus: String
  let offPeakWindowId: UUID?
  let scheduledForDate: String?

  enum CodingKeys: String, CodingKey {
    case id
    case promotionId = "promotion_id"
    case activityId = "activity_id"
    case type
    case displayStatus = "display_status"
    case offPeakWindowId = "off_peak_window_id"
    case scheduledForDate = "scheduled_for_date"
  }
}

final class ClientLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
  @Published var authorizationStatus: CLAuthorizationStatus
  @Published var location: CLLocation?
  @Published var heading: CLLocationDirection = 0

  private let manager: CLLocationManager

  override init() {
    let manager = CLLocationManager()
    self.manager = manager
    self.authorizationStatus = manager.authorizationStatus
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    manager.distanceFilter = 25
    manager.headingFilter = 3
  }

  func start() {
    if authorizationStatus == .notDetermined {
      manager.requestWhenInUseAuthorization()
    }
    manager.startUpdatingLocation()
    manager.startUpdatingHeading()
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    authorizationStatus = manager.authorizationStatus
    if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
      manager.startUpdatingLocation()
      manager.startUpdatingHeading()
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    location = locations.last
  }

  func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
    let value = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
    heading = value
  }
}

struct ClientUserLocationIndicatorView: View {
  let heading: CLLocationDirection

  var body: some View {
    ZStack {
      Circle()
        .fill(Color.appYellow.opacity(0.22))
        .frame(width: 56, height: 56)

      Circle()
        .fill(Color(red: 0.18, green: 0.19, blue: 0.15))
        .frame(width: 32, height: 32)
        .overlay(
          Circle().strokeBorder(Color.appYellow, lineWidth: 2)
        )

      Image(systemName: "location.north.fill")
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(Color.appYellow)
        .rotationEffect(.degrees(heading))
    }
    .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
  }
}

// MARK: - Search

struct ClientMapSearchResult: Identifiable, Hashable {
  let id: UUID
  let name: String
  let city: String?
  let postalCode: String?
  let latitude: Double
  let longitude: Double
  let photos: [String]
  let promotionsCount: Int
  let distanceKm: Double?
  let mainEmoji: String?

  var locationText: String {
    let parts = [city, postalCode].compactMap {
      $0?.trimmingCharacters(in: .whitespacesAndNewlines)
    }.filter { !$0.isEmpty }
    return parts.joined(separator: " ")
  }
}

@MainActor
final class ClientMapSearchViewModel: ObservableObject {
  @Published var query: String = ""
  @Published var results: [ClientMapSearchResult] = []
  @Published var isSearching: Bool = false

  private var searchTask: Task<Void, Never>?

  func search(userLocation: CLLocation?) {
    searchTask?.cancel()

    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      results = []
      isSearching = false
      return
    }

    isSearching = true
    searchTask = Task {
      try? await Task.sleep(nanoseconds: 300_000_000) // debounce 300ms
      if Task.isCancelled { return }

      do {
        // Recherche par nom avec ilike
        let pattern = "%\(trimmed)%"

        struct SearchRaw: Decodable {
          let id: UUID
          let name: String?
          let city: String?
          let postalCode: String?
          let latitude: Double?
          let longitude: Double?
          let photos: [String]

          enum CodingKeys: String, CodingKey {
            case id, name, city, latitude, longitude, photos
            case postalCode = "postal_code"
          }

          init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(UUID.self, forKey: .id)
            name = try c.decodeIfPresent(String.self, forKey: .name)
            city = try c.decodeIfPresent(String.self, forKey: .city)
            postalCode = try c.decodeIfPresent(String.self, forKey: .postalCode)
            latitude = try c.decodeIfPresent(Double.self, forKey: .latitude)
            longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)
            if let arr = try? c.decodeIfPresent([String].self, forKey: .photos) {
              photos = arr
            } else {
              photos = []
            }
          }
        }

        let raws: [SearchRaw] = try await SupabaseService.shared.client
          .from("complexes")
          .select("id,name,city,postal_code,latitude,longitude,photos")
          .ilike("name", pattern: pattern)
          .limit(20)
          .execute()
          .value

        if Task.isCancelled { return }

        let ids = raws.map(\.id)

        // Récupérer le nombre de promos par complexe
        var countByComplex: [UUID: Int] = [:]
        var emojiByComplex: [UUID: String] = [:]
        if !ids.isEmpty {
          async let promoFetch2: [AnnotationPromoRow] = SupabaseService.shared.client
            .from("promotions")
            .select("complex_id,promotion_off_peak(reward_amount,reward_unit),promotion_loyalty(reward_amount,reward_unit)")
            .eq("is_active", value: true)
            .in("complex_id", values: ids)
            .execute()
            .value

          async let activityFetch: [ClientComplexOfferJoinRow] = SupabaseService.shared.client
            .from("complex_activity_offers")
            .select("complex_id,activities(id,label,emoji)")
            .eq("is_active", value: true)
            .in("complex_id", values: ids)
            .execute()
            .value

          let (promoRows, activityRows) = try await (promoFetch2, activityFetch)

          for row in promoRows {
            countByComplex[row.complexId, default: 0] += 1
          }

          for row in activityRows {
            if emojiByComplex[row.id] == nil,
               let emoji = row.activities?.emoji?.trimmingCharacters(in: .whitespacesAndNewlines),
               !emoji.isEmpty {
              emojiByComplex[row.id] = emoji
            }
          }
        }

        if Task.isCancelled { return }

        let mapped: [ClientMapSearchResult] = raws.compactMap { raw in
          guard let lat = raw.latitude, let lng = raw.longitude else { return nil }
          let name = (raw.name?.trimmingCharacters(in: .whitespacesAndNewlines))
            .flatMap { $0.isEmpty ? nil : $0 } ?? "Complexe"

          var distanceKm: Double? = nil
          if let userLocation {
            let dest = CLLocation(latitude: lat, longitude: lng)
            distanceKm = userLocation.distance(from: dest) / 1000
          }

          return ClientMapSearchResult(
            id: raw.id,
            name: name,
            city: raw.city,
            postalCode: raw.postalCode,
            latitude: lat,
            longitude: lng,
            photos: raw.photos,
            promotionsCount: countByComplex[raw.id] ?? 0,
            distanceKm: distanceKm,
            mainEmoji: emojiByComplex[raw.id]
          )
        }
        // Tri par distance (les plus proches en premier)
        .sorted { a, b in
          guard let da = a.distanceKm else { return false }
          guard let db = b.distanceKm else { return true }
          return da < db
        }

        results = Array(mapped.prefix(8))
      } catch {
        if !Task.isCancelled {
          results = []
        }
      }
      isSearching = false
    }
  }

  func clear() {
    query = ""
    results = []
    isSearching = false
    searchTask?.cancel()
  }
}

struct ClientMapSearchBarView: View {
  @ObservedObject var searchVM: ClientMapSearchViewModel
  let userLocation: CLLocation?
  let onSelect: (ClientMapSearchResult) -> Void

  @FocusState private var isFocused: Bool
  @State private var showResults: Bool = false

  private let accent = Color.appYellow

  var body: some View {
    VStack(spacing: 0) {
      // Barre de recherche
      HStack(spacing: 10) {
        Image(systemName: "magnifyingglass")
          .font(.system(size: 16, weight: .medium))
          .foregroundStyle(.white.opacity(0.4))

        TextField("", text: $searchVM.query, prompt: Text("Rechercher un complexe").foregroundStyle(.white.opacity(0.3)))
          .font(.system(size: 16))
          .foregroundStyle(.white)
          .tint(accent)
          .focused($isFocused)
          .autocorrectionDisabled()
          .textInputAutocapitalization(.never)
          .submitLabel(.search)
          .onChange(of: searchVM.query) { _, _ in
            searchVM.search(userLocation: userLocation)
          }

        if !searchVM.query.isEmpty {
          Button {
            searchVM.clear()
            isFocused = false
          } label: {
            Image(systemName: "xmark.circle.fill")
              .font(.system(size: 16))
              .foregroundStyle(.white.opacity(0.4))
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 13)
      .background(
        RoundedRectangle(cornerRadius: 40, style: .continuous)
          .fill(.ultraThinMaterial)
          .environment(\.colorScheme, .dark)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 40, style: .continuous)
          .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
      )

      // Résultats
      if isFocused && !searchVM.results.isEmpty {
        VStack(spacing: 0) {
          ForEach(Array(searchVM.results.enumerated()), id: \.element.id) { index, result in
            Button {
              isFocused = false
              searchVM.clear()
              onSelect(result)
            } label: {
              HStack(spacing: 12) {
                Text(result.mainEmoji ?? "🏟️")
                  .font(.system(size: 22))
                  .frame(width: 36, height: 36)
                  .background(Color.white.opacity(0.08))
                  .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                  Text(result.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                  HStack(spacing: 4) {
                    if !result.locationText.isEmpty {
                      Text(result.locationText)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                    }
                    if let km = result.distanceKm {
                      Text("·")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.35))
                      Text(km >= 10 ? String(format: "%.0f km", km) : String(format: "%.1f km", km))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                    }
                  }
                }

                Spacer()

                if result.promotionsCount > 0 {
                  Text("\(result.promotionsCount) promo\(result.promotionsCount > 1 ? "s" : "")")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(accent)
                    .clipShape(Capsule())
                }
              }
              .padding(.horizontal, 16)
              .padding(.vertical, 11)
              .offset(y: showResults ? 0 : -8)
              .opacity(showResults ? 1 : 0)
              .animation(
                .spring(response: 0.35, dampingFraction: 0.8)
                  .delay(Double(index) * 0.04),
                value: showResults
              )
            }
            .buttonStyle(.plain)

            if result.id != searchVM.results.last?.id {
              Divider()
                .background(Color.white.opacity(0.08))
                .padding(.leading, 16)
            }
          }
        }
        .padding(.top, 6)
        .background(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(white: 0.12))
            .opacity(showResults ? 1 : 0)
            .animation(.easeOut(duration: 0.2), value: showResults)
        )
        .padding(.top, 6)
        .onAppear { showResults = true }
        .onDisappear { showResults = false }
      }
    }
    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isFocused)
    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: searchVM.results.map(\.id))
  }
}

// MARK: - Map ViewModel

@MainActor
final class ClientMapViewModel: ObservableObject {
  @Published var complexes: [ClientMapComplex] = []
  @Published var isLoading: Bool = false
  @Published var errorMessage: String?

  private var lastBoxKey: String?

  func loadComplexes(in region: MKCoordinateRegion, force: Bool = false) async {
    let box = regionBoundingBox(region: region)
    let key = "\(round6(box.minLat))_\(round6(box.maxLat))_\(round6(box.minLng))_\(round6(box.maxLng))"
    if key == lastBoxKey && !force { return }
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

      async let joinFetch: [ClientComplexOfferJoinRow] = SupabaseService.shared.client
        .from("complex_activity_offers")
        .select("complex_id,activities(id,label,emoji)")
        .eq("is_active", value: true)
        .in("complex_id", values: ids)
        .execute()
        .value

      async let promoFetch: [AnnotationPromoRow] = SupabaseService.shared.client
        .from("promotions")
        .select("complex_id,promotion_off_peak(reward_amount,reward_unit),promotion_loyalty(reward_amount,reward_unit)")
        .eq("is_active", value: true)
        .in("complex_id", values: ids)
        .execute()
        .value

      let (joinRows, promoRows) = try await (joinFetch, promoFetch)

      var activitiesByComplex: [UUID: [ClientActivity]] = [:]
      activitiesByComplex.reserveCapacity(256)

      for row in joinRows {
        guard
          let activityId = row.activities?.id,
          let labelRaw = row.activities?.label?.trimmingCharacters(in: .whitespacesAndNewlines),
          !labelRaw.isEmpty
        else { continue }

        let emojiRaw = (row.activities?.emoji?.trimmingCharacters(in: .whitespacesAndNewlines))
          .flatMap { $0.isEmpty ? nil : $0 } ?? "🏟️"

        let activity = ClientActivity(id: activityId, label: labelRaw, emoji: emojiRaw)

        var arr = activitiesByComplex[row.id] ?? []
        if !arr.contains(activity) {
          arr.append(activity)
          activitiesByComplex[row.id] = arr
        }
      }

      var maxPercentByComplex: [UUID: Int] = [:]
      var countByComplex: [UUID: Int] = [:]
      for row in promoRows {
        countByComplex[row.complexId, default: 0] += 1
        var amounts: [Int] = []
        if let detail = row.offPeak, detail.rewardUnit == "percent", let amt = detail.rewardAmount { amounts.append(amt) }
        if let detail = row.loyalty, detail.rewardUnit == "percent", let amt = detail.rewardAmount { amounts.append(amt) }
        if let max = amounts.max() {
          let current = maxPercentByComplex[row.complexId] ?? 0
          if max > current { maxPercentByComplex[row.complexId] = max }
        }
      }

      complexes = raws.compactMap { raw in
        guard let lat = raw.latitude, let lng = raw.longitude else { return nil }
        let title = (raw.name?.trimmingCharacters(in: .whitespacesAndNewlines))
          .flatMap { $0.isEmpty ? nil : $0 } ?? "Complexe"

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
          activities: activitiesByComplex[raw.id] ?? [],
          maxPromoPercent: maxPercentByComplex[raw.id],
          promotionsCount: countByComplex[raw.id] ?? 0
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

@MainActor
final class ClientComplexPromotionsViewModel: ObservableObject {
  @Published var groups: [ClientPromotionGroup] = []
  @Published var isLoading = false
  @Published var errorMessage: String?
  /// Clés (promotionId + activityId) des promos déjà générées au moins une fois par le client,
  /// quel que soit le statut actuel (generated, redeemed, expired, cancelled…).
  /// Une promo marquée ici ne peut plus JAMAIS être régénérée.
  @Published var generatedKeys: Set<String> = []

  func load(for complex: ClientMapComplex) async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      async let sheetRequest = SupabaseService.shared.client
        .rpc("client_complex_promotions_sheet", params: ["p_complex_id": complex.id.uuidString])
        .execute()

      async let generatedKeysRequest = SupabaseService.shared.client
        .rpc("client_list_generated_promotion_keys")
        .execute()

      let (sheetResponse, generatedKeysResponse) = try await (sheetRequest, generatedKeysRequest)

      let rows = try JSONDecoder().decode([ClientPromotionSheetRow].self, from: sheetResponse.data)

      struct GeneratedKeyRow: Decodable {
        let promotion_id: UUID
        let activity_id: UUID
      }
      let generatedRows = try JSONDecoder().decode([GeneratedKeyRow].self, from: generatedKeysResponse.data)

      let grouped = Dictionary(grouping: rows) { $0.activityLabel }

      groups = complex.activities.map { activity in
        ClientPromotionGroup(
          activity: activity,
          promotions: grouped[activity.label] ?? []
        )
      }

      // Toute instance existante (quel que soit son statut et son ancienneté)
      // verrouille la promo pour ce client.
      generatedKeys = Set(
        generatedRows.map { item in
          Self.generatedKey(
            promotionId: item.promotion_id,
            activityId: item.activity_id
          )
        }
      )
    } catch {
      groups = complex.activities.map { ClientPromotionGroup(activity: $0, promotions: []) }
      errorMessage = error.localizedDescription
    }
  }

  func generatePromotion(target: ClientPromoGenerateTarget) async throws -> GeneratedPromotionResult {
    let row = target.row
    let activity = target.activity

    struct GenerateResponse: Decodable {
      let id: UUID
    }

    switch target {
    case .loyalty:
      let params: [String: String?] = [
        "p_promotion_id": row.promotionId.uuidString,
        "p_activity_id": activity.id.uuidString,
        "p_off_peak_window_id": nil,
        "p_scheduled_for_date": nil
      ]

      let response = try await SupabaseService.shared.client
        .rpc("client_generate_promotion_instance", params: params)
        .execute()

      // Pas d'insertion dans generatedKeys : la fidélité reste régénérable tant que le compteur couvre required_sessions.

      let decoded = try JSONDecoder().decode(GenerateResponse.self, from: response.data)
      return GeneratedPromotionResult(id: decoded.id)

    case .offPeak:
      struct OffPeakWindowRow: Decodable {
        let id: UUID
        let dow: Int
        let startTime: String
        let endTime: String

        enum CodingKeys: String, CodingKey {
          case id
          case dow
          case startTime = "start_time"
          case endTime = "end_time"
        }
      }

      let windows: [OffPeakWindowRow] = try await SupabaseService.shared.client
        .from("promotion_off_peak_windows")
        .select("id,dow,start_time,end_time")
        .eq("promotion_id", value: row.promotionId.uuidString)
        .execute()
        .value

      guard !windows.isEmpty else {
        throw NSError(
          domain: "ClientPromo",
          code: 3,
          userInfo: [NSLocalizedDescriptionKey: "Aucun créneau configuré pour cette promo."]
        )
      }

      let cal = Calendar(identifier: .gregorian)
      let now = Date()
      let today = cal.startOfDay(for: now)

      var best: (window: OffPeakWindowRow, date: Date)?

      for window in windows {
        let targetWeekday = (window.dow % 7) + 1

        for offset in 0...3 {
          guard let candidate = cal.date(byAdding: .day, value: offset, to: today) else { continue }
          guard cal.component(.weekday, from: candidate) == targetWeekday else { continue }

          if offset == 0 {
            let parts = window.endTime.split(separator: ":")
            if parts.count >= 2,
               let eh = Int(parts[0]),
               let em = Int(parts[1]) {
              var c = cal.dateComponents([.year, .month, .day], from: candidate)
              c.hour = eh
              c.minute = em
              if let endDate = cal.date(from: c), endDate <= now { continue }
            }
          }

          if best == nil || candidate < best!.date {
            best = (window, candidate)
          }
          break
        }
      }

      guard let pick = best else {
        throw NSError(
          domain: "ClientPromo",
          code: 4,
          userInfo: [NSLocalizedDescriptionKey: "Aucun créneau disponible dans les 3 prochains jours."]
        )
      }

      let dateFmt = DateFormatter()
      dateFmt.locale = Locale(identifier: "en_US_POSIX")
      dateFmt.dateFormat = "yyyy-MM-dd"
      let scheduledDate = dateFmt.string(from: pick.date)

      let params: [String: String?] = [
        "p_promotion_id": row.promotionId.uuidString,
        "p_activity_id": activity.id.uuidString,
        "p_off_peak_window_id": pick.window.id.uuidString,
        "p_scheduled_for_date": scheduledDate
      ]

      let response = try await SupabaseService.shared.client
        .rpc("client_generate_promotion_instance", params: params)
        .execute()

      generatedKeys.insert(
        Self.generatedKey(
          promotionId: row.promotionId,
          activityId: activity.id
        )
      )

      let decoded = try JSONDecoder().decode(GenerateResponse.self, from: response.data)
      return GeneratedPromotionResult(id: decoded.id)
    }
  }

  /// Seules les promos HC (heure creuse) sont verrouillées après génération.
  /// Les promos fidélité restent régénérables à l'infini tant que le compteur couvre required_sessions.
  func isAlreadyGenerated(_ target: ClientPromoGenerateTarget) -> Bool {
    switch target {
    case .loyalty:
      return false
    case .offPeak:
      let row = target.row
      let activity = target.activity
      return generatedKeys.contains(
        Self.generatedKey(
          promotionId: row.promotionId,
          activityId: activity.id
        )
      )
    }
  }

  fileprivate static func generatedKey(promotionId: UUID, activityId: UUID) -> String {
    "\(promotionId.uuidString)-\(activityId.uuidString)"
  }
}

struct ActivityAnchorPreferenceKey: PreferenceKey {
  static var defaultValue: [String: Anchor<CGRect>] = [:]

  static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
    value.merge(nextValue(), uniquingKeysWith: { $1 })
  }
}

extension MKDirections {
  func calculateETAAsync() async throws -> MKDirections.ETAResponse {
    try await withCheckedThrowingContinuation { cont in
      self.calculateETA { response, error in
        if let error {
          cont.resume(throwing: error)
          return
        }
        if let response {
          cont.resume(returning: response)
          return
        }
        cont.resume(throwing: URLError(.badServerResponse))
      }
    }
  }
}

struct ClientMapComplexAnnotationView: View {
  let complex: ClientMapComplex

  var body: some View {
    VStack(spacing: 5) {
      Text(complex.name)
        .font(.system(size: 12, weight: .bold))
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.75), radius: 3, x: 0, y: 1)
        .lineLimit(1)

      HStack(spacing: 0) {
        Text(mainEmoji)
          .font(.system(size: 15))
          .frame(width: 30, height: 30)
          .background(Color(white: 0.18))
          .clipShape(Circle())
          .overlay(Circle().strokeBorder(.white.opacity(0.22), lineWidth: 1.5))
          .padding(3)

        if let percent = complex.maxPromoPercent {
          Text("-\(percent)%")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.black)
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(Color.appYellow)
            .clipShape(Capsule())
            .padding(.trailing, 4)
        }
      }
      .background(Color(white: 0.1))
      .clipShape(Capsule())
      .overlay(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 1))
      .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
    }
  }

  private var mainEmoji: String {
    complex.activities.first?.emoji ?? "🏟️"
  }
}

struct ClientComplexMiniCardView: View {
  let complex: ClientMapComplex
  let userLocation: CLLocation?
  let onTap: () -> Void
  let onClose: () -> Void
  private let accent = Color.appYellow

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        if complex.promotionsCount > 0 {
          Text("\(complex.promotionsCount) promotion\(complex.promotionsCount > 1 ? "s" : "")")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(accent)
            .clipShape(Capsule())
            .padding(.leading, 4)
        }

        Spacer()

        Button(action: onClose) {
          Image(systemName: "xmark")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(Color.black.opacity(0.75))
            .clipShape(Circle())
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(.trailing, 4)
      }

      cardContent
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture {
          onTap()
        }
    }
  }

  @ViewBuilder
  private var cardContent: some View {
    VStack(alignment: .leading, spacing: 0) {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(Color(white: 0.88))
        .frame(height: 160)
        .overlay {
          heroImage
        }
        .overlay {
          LinearGradient(
            colors: [.clear, .black.opacity(0.55)],
            startPoint: .center,
            endPoint: .bottom
          )
        }
        .overlay(alignment: .topTrailing) {
          HStack(spacing: 6) {
            ForEach(Array(complex.activities.prefix(3))) { activity in
              Text(activity.emoji)
                .font(.system(size: 14))
                .frame(width: 30, height: 30)
                .background(Color(white: 0.12))
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.22), lineWidth: 1))
            }
          }
          .padding(10)
        }
        .overlay(alignment: .bottomLeading) {
          Text(complex.name)
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.6), radius: 4, y: 1)
            .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(8)

      HStack(spacing: 6) {
        Image(systemName: "mappin.circle.fill")
          .foregroundStyle(accent)
          .font(.system(size: 15))
        Text(locationText)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.black)
        Spacer()
      }
      .padding(.horizontal, 14)
      .padding(.top, 2)

      if !complex.activities.isEmpty {
        Text(complex.activities.map { $0.label }.joined(separator: " - "))
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.black)
          .padding(.horizontal, 10)
          .padding(.vertical, 7)
          .background(Color.black.opacity(0.06))
          .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
          .padding(.horizontal, 14)
          .padding(.top, 10)
          .padding(.bottom, 14)
          .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        Spacer().frame(height: 14)
      }
    }
    .background(Color.white)
    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    .shadow(color: .black.opacity(0.22), radius: 14, x: 0, y: 6)
  }

  @ViewBuilder
  private var heroImage: some View {
    if let first = complex.photos.first, let url = URL(string: first) {
      AsyncImage(url: url) { phase in
        switch phase {
        case .success(let image):
          image
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .transition(.opacity.animation(.easeOut(duration: 0.25)))
        default:
          Color(white: 0.15)
        }
      }
    } else {
      Color(white: 0.15)
    }
  }

  private var locationText: String {
    var parts: [String] = []
    let city = (complex.city ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let postal = (complex.postalCode ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if !city.isEmpty && !postal.isEmpty {
      parts.append("\(city) \(postal)")
    } else if !city.isEmpty {
      parts.append(city)
    } else if !postal.isEmpty {
      parts.append(postal)
    }

    if let userLocation {
      let dest = CLLocation(latitude: complex.latitude, longitude: complex.longitude)
      let km = userLocation.distance(from: dest) / 1000
      if km >= 10 {
        parts.append(String(format: "%.0fkm", km))
      } else {
        parts.append(String(format: "%.1fkm", km))
      }
    }

    return parts.joined(separator: " - ")
  }
}

struct ClientComplexSheetView: View {
  let complex: ClientMapComplex
  let userLocation: CLLocation?

  @Environment(\.openURL) private var openURL

  @StateObject private var promotionsViewModel = ClientComplexPromotionsViewModel()

  @State private var selectedTab: SheetTab = .promotions
  @State private var selectedPromotionActivityId: UUID?
  @State private var driveTimeText: String?
  @State private var isDriveTimeLoading: Bool = false
  @State private var showDirectionsPicker: Bool = false
  @State private var tooltipTokensByLabel: [String: UUID] = [:]
  @State private var tooltipPopByLabel: [String: Bool] = [:]
  @State private var generateTarget: ClientPromoGenerateTarget?
  @State private var generatedResult: GeneratedPromotionResult?
  @State private var generationErrorMessage: String?

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
          HStack(alignment: .center, spacing: 10) {
            Text(complex.name)
              .font(.title2)
              .fontWeight(.bold)
              .lineLimit(2)
            Spacer(minLength: 8)
          }
          .padding(.top, 28)

          HStack(alignment: .center, spacing: 8) {
            if !complex.activities.isEmpty {
              HStack(spacing: 6) {
                ForEach(complex.activities) { activity in
                  Button {
                    showTooltip(for: activity)
                  } label: {
                    Text(activity.emoji)
                      .font(.system(size: 14))
                      .frame(width: 28, height: 28)
                      .background(Color(white: 0.12))
                      .clipShape(Circle())
                  }
                  .buttonStyle(.plain)
                  .anchorPreference(key: ActivityAnchorPreferenceKey.self, value: .bounds) { anchor in
                    [activity.label: anchor]
                  }
                }
              }
            }

            Image(systemName: "mappin.circle.fill")
              .font(.system(size: 18))
              .foregroundStyle(Color.red)

            Text(locationPillText)
              .font(.system(size: 14, weight: .medium))
              .foregroundStyle(.secondary)
              .lineLimit(1)

            Spacer(minLength: 0)
          }
        }
        .padding(.horizontal, 16)

        HStack(spacing: 12) {
          Button {
            openWebsite()
          } label: {
            HStack(spacing: 10) {
              Image(systemName: "calendar")
                .font(.system(size: 16, weight: .semibold))
              Text("Réserver")
                .font(.system(size: 16, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(white: 0.93))
            .foregroundStyle(Color.black)
            .clipShape(Capsule())
          }
          .disabled(websiteURL == nil)
          .opacity(websiteURL == nil ? 0.45 : 1)

          Button {
            callComplex()
          } label: {
            HStack(spacing: 10) {
              Image(systemName: "phone.fill")
                .font(.system(size: 15, weight: .semibold))
              Text("Appeler")
                .font(.system(size: 16, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(white: 0.93))
            .foregroundStyle(Color.black)
            .clipShape(Capsule())
          }
          .disabled(!canCall)
          .opacity(canCall ? 1 : 0.45)
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

        HStack(spacing: 40) {
          Spacer(minLength: 0)
          ForEach(SheetTab.allCases) { tab in
            Button {
              withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
            } label: {
              VStack(spacing: 6) {
                HStack(spacing: 6) {
                  if selectedTab == tab {
                    Circle().fill(Color.appYellow).frame(width: 6, height: 6)
                  }
                  Text(tab.rawValue)
                    .font(.system(size: 16, weight: selectedTab == tab ? .semibold : .regular))
                    .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                }
                Rectangle()
                  .fill(selectedTab == tab ? Color.primary : Color.clear)
                  .frame(height: 2)
              }
            }
            .buttonStyle(.plain)
          }
          Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)

        Group {
          switch selectedTab {
          case .promotions:
            ClientPromotionsBlock(
              cardBg: cardBg,
              border: border,
              isLoading: promotionsViewModel.isLoading,
              groups: promotionsViewModel.groups,
              onGenerate: { target in
                generateTarget = target
              },
              isAlreadyGenerated: { target in
                promotionsViewModel.isAlreadyGenerated(target)
              },
              selectedActivityId: $selectedPromotionActivityId
            )
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
    .task(id: etaTaskKey) {
      await updateDriveTime()
    }
    .task(id: complex.id) {
      await promotionsViewModel.load(for: complex)
      if selectedPromotionActivityId == nil {
        selectedPromotionActivityId = promotionsViewModel.groups.first?.id
      }
    }
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
    .confirmationDialog("Ouvrir l’itinéraire dans…", isPresented: $showDirectionsPicker, titleVisibility: .visible) {
      Button("Plans (Apple)") { openInAppleMaps() }
      Button("Google Maps") { openInGoogleMaps() }
      Button("Waze") { openInWaze() }
      Button("Annuler", role: .cancel) {}
    }
    .sheet(item: $generateTarget) { target in
      ClientPromotionGenerateSummaryView(
        complex: complex,
        target: target,
        alreadyGenerated: promotionsViewModel.isAlreadyGenerated(target),
        onConfirm: {
          do {
            let result = try await promotionsViewModel.generatePromotion(target: target)
            generateTarget = nil
            generatedResult = result
            await promotionsViewModel.load(for: complex)
          } catch {
            generationErrorMessage = error.localizedDescription
          }
        }
      )
      .presentationDetents([.large])
      .presentationDragIndicator(.visible)
    }
    .sheet(item: $generatedResult) { result in
      ClientPromotionGeneratedSuccessView(
        promotionInstanceId: result.id,
        onShowMyPromo: {
          NotificationCenter.default.post(name: .clientOpenMyPromotions, object: result.id)
        }
      )
      .presentationDetents([.medium])
      .presentationDragIndicator(.visible)
    }
    .alert("Erreur", isPresented: Binding(
      get: { generationErrorMessage != nil },
      set: { newValue in
        if !newValue { generationErrorMessage = nil }
      }
    )) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(generationErrorMessage ?? "")
    }
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
              .animation(.spring(response: 0.22, dampingFraction: 0.72), value: tooltipTokensByLabel[label])
          }
        }
      }
    }
  }

  private func showTooltip(for activity: ClientActivity) {
    let label = activity.label
    let token = UUID()
    tooltipTokensByLabel[label] = token
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

  private var locationPillText: String {
    var parts: [String] = []
    if let city = complex.city, !city.isEmpty {
      if let postal = complex.postalCode, !postal.isEmpty {
        parts.append("\(city) \(postal)")
      } else {
        parts.append(city)
      }
    } else if let postal = complex.postalCode, !postal.isEmpty {
      parts.append(postal)
    }
    if let userLocation {
      let d = userLocation.distance(from: CLLocation(latitude: complex.latitude, longitude: complex.longitude))
      let km = d / 1000.0
      if km >= 10 {
        parts.append("\(Int(km.rounded()))km")
      } else {
        parts.append(String(format: "%.1fkm", km))
      }
    }
    return parts.joined(separator: " - ")
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

struct ClientPromotionsBlock: View {
  let cardBg: Color
  let border: Color
  let isLoading: Bool
  let groups: [ClientPromotionGroup]
  let onGenerate: (ClientPromoGenerateTarget) -> Void
  let isAlreadyGenerated: (ClientPromoGenerateTarget) -> Bool

  @Binding var selectedActivityId: UUID?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Promotions")
        .font(.headline)

      if isLoading {
        HStack(spacing: 10) {
          ProgressView()
          Text("Chargement…")
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
      } else if groups.isEmpty {
        Text("Aucune activité disponible.")
          .foregroundStyle(.secondary)
          .padding(14)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(cardBg)
          .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
              .strokeBorder(border, lineWidth: 1)
          )
      } else {
        VStack(spacing: 10) {
          ForEach(groups) { group in
            ClientPromotionActivityCard(
              group: group,
              isExpanded: selectedActivityId == group.id,
              cardBg: cardBg,
              border: border,
              onTap: {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                  selectedActivityId = selectedActivityId == group.id ? nil : group.id
                }
              },
              onGenerate: onGenerate,
              isAlreadyGenerated: isAlreadyGenerated
            )
          }
        }
      }
    }
  }
}

struct ClientPromotionActivityCard: View {
  let group: ClientPromotionGroup
  let isExpanded: Bool
  let cardBg: Color
  let border: Color
  let onTap: () -> Void
  let onGenerate: (ClientPromoGenerateTarget) -> Void
  let isAlreadyGenerated: (ClientPromoGenerateTarget) -> Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Button(action: onTap) {
        HStack(spacing: 12) {
          Text(group.activity.emoji)
            .font(.system(size: 22))
            .frame(width: 44, height: 44)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

          Text(group.activity.label)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.primary)

          if !group.promotions.isEmpty {
            Text("Promotion !")
              .font(.system(size: 12, weight: .semibold))
              .foregroundStyle(.black)
              .padding(.horizontal, 10)
              .padding(.vertical, 5)
              .background(Color.appYellow)
              .clipShape(Capsule())
          }

          Spacer()

          Image(systemName: "chevron.down")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.primary)
            .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
      }
      .buttonStyle(.plain)

      if isExpanded {
        VStack(spacing: 10) {
          let loyaltyPromos = group.promotions.filter { $0.promotionType == .loyalty }
          let offPeakPromos = group.promotions.filter { $0.promotionType == .off_peak }

          if loyaltyPromos.isEmpty && offPeakPromos.isEmpty {
            Text("Aucune promotion pour cette activité.")
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.top, 2)
          } else {
            ForEach(loyaltyPromos) { promotion in
              ClientLoyaltyPromotionCard(
                promotion: promotion,
                activity: group.activity,
                cardBg: Color.white.opacity(0.58),
                border: border.opacity(0.7),
                onGenerate: onGenerate
              )
            }

            if !offPeakPromos.isEmpty {
              ClientOffPeakPromotionCard(
                promotions: offPeakPromos,
                activity: group.activity,
                cardBg: Color.white.opacity(0.58),
                border: border.opacity(0.7),
                onGenerate: onGenerate,
                isAlreadyGenerated: isAlreadyGenerated
              )
            }
          }
        }
        .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.98)), removal: .opacity))
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(white: 0.93))
    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
  }
}

struct ClientLoyaltyPromotionCard: View {
  let promotion: ClientPromotionSheetRow
  let activity: ClientActivity
  let cardBg: Color
  let border: Color
  let onGenerate: (ClientPromoGenerateTarget) -> Void

  private var target: ClientPromoGenerateTarget {
    .loyalty(promotion, activity)
  }

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 8) {
          Text("Fidélité")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.black)
            .clipShape(Capsule())

          Text(rewardPillText)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.appYellow)
            .clipShape(Capsule())

          Text(progressText)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
        }

        Text(descriptionText)
          .font(.system(size: 13))
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }

      Spacer(minLength: 6)

      if canGenerate {
        Button {
          onGenerate(target)
        } label: {
          Image(systemName: "arrow.right")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(Color.black)
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
      } else {
        Image(systemName: "arrow.right")
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(.white)
          .frame(width: 36, height: 36)
          .background(Color.black.opacity(0.3))
          .clipShape(Circle())
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.white)
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
  }

  private var rewardPillText: String {
    let required = max(1, promotion.requiredSessions ?? 0)
    return "\(required) = \(shortReward)"
  }

  private var shortReward: String {
    guard let unit = promotion.rewardUnit else { return "offert" }
    switch unit {
    case .session:
      let amount = max(1, promotion.rewardAmount ?? 1)
      return "\(amount) offert\(amount > 1 ? "s" : "")"
    case .percent:
      return "-\(max(1, promotion.rewardAmount ?? 0))%"
    case .euro:
      return "-\(max(1, promotion.rewardAmount ?? 0))€"
    case .custom:
      let label = (promotion.rewardCustomLabel ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      return label.isEmpty ? "offert" : label
    }
  }

  private var descriptionText: String {
    let required = max(1, promotion.requiredSessions ?? 0)
    return "Après \(required) séance\(required > 1 ? "s" : "") sur cette activité, \(formattedReward.lowercased())."
  }

  private var canGenerate: Bool {
    let done = max(0, promotion.completedSessions ?? 0)
    let required = max(1, promotion.requiredSessions ?? 0)
    return done >= required
  }

  private var progressText: String {
    let done = max(0, promotion.completedSessions ?? 0)
    let required = max(1, promotion.requiredSessions ?? 0)
    return "\(min(done, required))/\(required)"
  }

  private var rewardText: String {
    let required = max(1, promotion.requiredSessions ?? 0)
    return "\(required) séance\(required > 1 ? "s" : "") → \(formattedReward)"
  }

  private var formattedReward: String {
    guard let unit = promotion.rewardUnit else { return "Récompense" }

    switch unit {
    case .session:
      let amount = max(1, promotion.rewardAmount ?? 1)
      return "\(amount) séance\(amount > 1 ? "s" : "") offerte\(amount > 1 ? "s" : "")"
    case .percent:
      return "\(max(1, promotion.rewardAmount ?? 0))% de réduction"
    case .euro:
      return "\(max(1, promotion.rewardAmount ?? 0))€ de réduction"
    case .custom:
      let label = (promotion.rewardCustomLabel ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      return label.isEmpty ? "Récompense" : label
    }
  }
}

struct ClientOffPeakPromotionCard: View {
  let promotions: [ClientPromotionSheetRow]
  let activity: ClientActivity
  let cardBg: Color
  let border: Color
  let onGenerate: (ClientPromoGenerateTarget) -> Void
  let isAlreadyGenerated: (ClientPromoGenerateTarget) -> Bool

  var body: some View {
    VStack(spacing: 10) {
      ForEach(nextUpcomingPromotions) { promotion in
        let target = ClientPromoGenerateTarget.offPeak(promotion, activity)
        let alreadyGenerated = isAlreadyGenerated(target)

        HStack(alignment: .center, spacing: 12) {
          VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
              Text("Heure creuse")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black)
                .clipShape(Capsule())

              Text(shortReward(for: promotion))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.appYellow)
                .clipShape(Capsule())
            }

            if let schedule = ClientPromotionRowScheduleFormatter.nextOccurrenceLine(for: promotion) {
              Text(schedule)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            }

            if let note = ClientPromotionRowScheduleFormatter.toleranceLine(for: promotion) {
              Text("Sous condition — \(note)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary.opacity(0.8))
            }
          }

          Spacer(minLength: 6)

          if alreadyGenerated {
            Image(systemName: "checkmark")
              .font(.system(size: 14, weight: .bold))
              .foregroundStyle(.white)
              .frame(width: 36, height: 36)
              .background(Color.black.opacity(0.4))
              .clipShape(Circle())
          } else {
            Button {
              onGenerate(target)
            } label: {
              Image(systemName: "arrow.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.black)
                .clipShape(Circle())
            }
            .buttonStyle(.plain)
          }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
    }
  }

  private var nextUpcomingPromotions: [ClientPromotionSheetRow] {
    let now = Date()
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime]
    let dayFmt = DateFormatter()
    dayFmt.dateFormat = "yyyy-MM-dd"
    dayFmt.locale = Locale(identifier: "fr_FR")

    let upcoming = promotions.filter { promo in
      if let start = promo.validFrom, let d = iso.date(from: start) {
        return d >= now || (promo.validUntil.flatMap { iso.date(from: $0) }.map { $0 >= now } ?? true)
      }
      if let day = promo.scheduledDate, let d = dayFmt.date(from: day) {
        return Calendar.current.isDateInToday(d) || d >= now
      }
      return true
    }

    let sorted = upcoming.sorted { lhs, rhs in
      let ld = iso.date(from: lhs.validFrom ?? "") ?? dayFmt.date(from: lhs.scheduledDate ?? "") ?? .distantFuture
      let rd = iso.date(from: rhs.validFrom ?? "") ?? dayFmt.date(from: rhs.scheduledDate ?? "") ?? .distantFuture
      return ld < rd
    }

    return Array(sorted.prefix(1))
  }

  private func shortReward(for promotion: ClientPromotionSheetRow) -> String {
    guard let unit = promotion.rewardUnit else { return "-" }
    switch unit {
    case .session:
      let amount = max(1, promotion.rewardAmount ?? 1)
      return "\(amount) offert\(amount > 1 ? "s" : "")"
    case .percent:
      return "-\(max(1, promotion.rewardAmount ?? 0))%"
    case .euro:
      return "-\(max(1, promotion.rewardAmount ?? 0))€"
    case .custom:
      let label = (promotion.rewardCustomLabel ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      return label.isEmpty ? "-" : label
    }
  }


  private var sortedPromotions: [ClientPromotionSheetRow] {
    promotions.sorted { lhs, rhs in
      let ld = lhs.scheduledDate ?? ""
      let rd = rhs.scheduledDate ?? ""
      if ld != rd { return ld < rd }
      let ls = lhs.validFrom ?? ""
      let rs = rhs.validFrom ?? ""
      return ls < rs
    }
  }

  private func formattedReward(for promotion: ClientPromotionSheetRow) -> String {
    guard let unit = promotion.rewardUnit else { return "Récompense" }

    switch unit {
    case .session:
      let amount = max(1, promotion.rewardAmount ?? 1)
      return "\(amount) séance\(amount > 1 ? "s" : "") offerte\(amount > 1 ? "s" : "")"
    case .percent:
      return "\(max(1, promotion.rewardAmount ?? 0))% de réduction"
    case .euro:
      return "\(max(1, promotion.rewardAmount ?? 0))€ de réduction"
    case .custom:
      let label = (promotion.rewardCustomLabel ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      return label.isEmpty ? "Récompense" : label
    }
  }
}

struct ClientPromotionGenerateSummaryView: View {
  let complex: ClientMapComplex
  let target: ClientPromoGenerateTarget
  let alreadyGenerated: Bool
  let onConfirm: () async -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var isSubmitting = false

  private let cardBg = Color(white: 0.94)

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 10) {
        Text(typeLabel)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.white)
          .padding(.horizontal, 12)
          .padding(.vertical, 7)
          .background(Color.black)
          .clipShape(Capsule())

        Text(target.activity.emoji)
          .font(.system(size: 14))
          .frame(width: 30, height: 30)
          .background(Color(white: 0.12))
          .clipShape(Circle())

        Text(rewardShort)
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(.black)
          .padding(.horizontal, 12)
          .padding(.vertical, 7)
          .background(Color.appYellow)
          .clipShape(Capsule())

        Spacer()

        Button {
          dismiss()
        } label: {
          Image(systemName: "xmark")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.primary)
            .frame(width: 32, height: 32)
            .background(Color(white: 0.93))
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
      }
      .padding(.horizontal, 20)
      .padding(.top, 18)

      ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 14) {
          summaryCard {
            VStack(spacing: 16) {
              detailRow(label: "Date :", value: dateText)
              detailRow(label: "Créneau :", value: scheduleText)
              detailRow(label: "Activité :", value: "\(target.activity.label) \(target.activity.emoji)")
              detailRow(label: "Promotion :", value: rewardShort)
            }
          }

          summaryCard {
            HStack(alignment: .center, spacing: 12) {
              Text("Lieu :")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.black)
              Spacer(minLength: 8)
              Text(complex.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.black)
                .multilineTextAlignment(.trailing)
            }
          }

          summaryCard {
            HStack(alignment: .center, spacing: 12) {
              Text("Condition :")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.black)
              Spacer(minLength: 8)
              Text(conditionLine)
                .font(.system(size: 14))
                .italic()
                .foregroundStyle(Color(white: 0.55))
                .multilineTextAlignment(.trailing)
            }
          }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
      }

      Group {
        if alreadyGenerated {
          HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
              .font(.system(size: 22, weight: .bold))
              .foregroundStyle(.black)
            Text("Tu possèdes déjà cette promotion")
              .font(.system(size: 16, weight: .semibold))
              .foregroundStyle(.black)
              .multilineTextAlignment(.center)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 20)
          .background(Color.appYellow)
          .clipShape(Capsule())
        } else {
          SwipeToUnlockButton(
            title: "Débloquer la promotion",
            isSubmitting: isSubmitting
          ) {
            guard !isSubmitting else { return }
            isSubmitting = true
            Task {
              await onConfirm()
              isSubmitting = false
            }
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 20)
    }
    .background(Color.white.ignoresSafeArea())
  }

  private func summaryCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    content()
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(cardBg)
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private func detailRow(label: String, value: String) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Text(label)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(.black)
      Spacer(minLength: 8)
      Text(value)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(.black)
        .multilineTextAlignment(.trailing)
    }
  }

  private var typeLabel: String {
    switch row.promotionType {
    case .loyalty: return "Fidélité"
    case .off_peak: return "Heure creuse"
    }
  }

  private var dateText: String {
    if row.promotionType == .loyalty { return "À utiliser librement" }
    if let occ = ClientPromotionRowScheduleFormatter.nextOccurrence(for: row) {
      let f = DateFormatter()
      f.locale = Locale(identifier: "fr_FR")
      f.dateFormat = "EEEE d MMMM"
      return f.string(from: occ.date).capitalized
    }
    return "—"
  }

  private var scheduleText: String {
    if row.promotionType == .loyalty { return "—" }
    if let occ = ClientPromotionRowScheduleFormatter.nextOccurrence(for: row) {
      return "\(occ.startTime) à \(occ.endTime)"
    }
    return "—"
  }

  private var conditionLine: String {
    switch row.promotionType {
    case .loyalty: return "*Utilisable une seule fois.*"
    case .off_peak: return "*Sous condition d'une réservation*"
    }
  }

  private var rewardShort: String {
    guard let unit = row.rewardUnit else { return "-" }
    switch unit {
    case .session:
      let amount = max(1, row.rewardAmount ?? 1)
      return "\(amount) offert\(amount > 1 ? "s" : "")"
    case .percent:
      return "-\(max(1, row.rewardAmount ?? 0))%"
    case .euro:
      return "-\(max(1, row.rewardAmount ?? 0))€"
    case .custom:
      let label = (row.rewardCustomLabel ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      return label.isEmpty ? "-" : label
    }
  }

  private var row: ClientPromotionSheetRow { target.row }
}

struct SwipeToUnlockButton: View {
  let title: String
  let isSubmitting: Bool
  let onComplete: () -> Void

  @State private var dragOffset: CGFloat = 0
  @State private var unlocked: Bool = false

  private let handleSize: CGFloat = 52
  private let height: CGFloat = 66

  var body: some View {
    GeometryReader { proxy in
      let maxOffset = max(0, proxy.size.width - handleSize - 8)
      let progress = min(1, max(0, dragOffset / max(1, maxOffset)))

      ZStack(alignment: .leading) {
        Capsule()
          .fill(Color.appYellow)

        Capsule()
          .fill(Color.appYellow.opacity(0.65))
          .frame(width: max(handleSize + 8, dragOffset + handleSize + 8))
          .animation(.easeOut(duration: 0.12), value: dragOffset)

        HStack {
          Spacer()
          Text(title)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.black.opacity(Double(1 - progress * 0.8)))
          Spacer()
        }
        .padding(.horizontal, handleSize)

        ZStack {
          Circle()
            .fill(Color.white)
            .frame(width: handleSize, height: handleSize)
            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)

          if isSubmitting {
            ProgressView()
              .tint(.black)
          } else {
            Image(systemName: unlocked ? "checkmark" : "arrow.right")
              .font(.system(size: 16, weight: .bold))
              .foregroundStyle(.black)
          }
        }
        .offset(x: 4 + dragOffset)
        .gesture(
          DragGesture()
            .onChanged { value in
              guard !isSubmitting, !unlocked else { return }
              dragOffset = min(maxOffset, max(0, value.translation.width))
            }
            .onEnded { _ in
              guard !isSubmitting, !unlocked else { return }
              if dragOffset >= maxOffset * 0.9 {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                  dragOffset = maxOffset
                  unlocked = true
                }
                onComplete()
              } else {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                  dragOffset = 0
                }
              }
            }
        )
      }
    }
    .frame(height: height)
  }
}

struct ClientPromotionGeneratedSuccessView: View {
  let promotionInstanceId: UUID
  let onShowMyPromo: () -> Void

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      VStack(spacing: 18) {
        Spacer()

        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 56, weight: .semibold))
          .foregroundStyle(Color.appYellow)

        Text("Promotion générée")
          .font(.title3)
          .fontWeight(.semibold)

        Text("Ta promotion a été ajoutée à tes promotions.\nTu peux maintenant la présenter au complexe pour en profiter.")
          .multilineTextAlignment(.center)
          .foregroundStyle(.secondary)
          .padding(.horizontal, 28)

        Button {
          onShowMyPromo()
          dismiss()
        } label: {
          Text("Voir ma promo")
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.black)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)

        Spacer()
      }
      .background(Color.white.ignoresSafeArea())
      .navigationTitle("")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Fermer") {
            dismiss()
          }
        }
      }
    }
  }
}

enum ClientPromotionRowScheduleFormatter {
  static let dayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "fr_FR")
    f.dateFormat = "yyyy-MM-dd"
    return f
  }()

  static let weekdayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "fr_FR")
    f.dateFormat = "EEE"
    return f
  }()

  static let dayNumberFormatter: DateFormatter = {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "fr_FR")
    f.dateFormat = "d"
    return f
  }()

  static let isoFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()

  static let isoFormatterNoFraction: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
  }()

  static let hourFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "fr_FR")
    f.dateFormat = "HH:mm"
    return f
  }()

  static func mainLine(for row: ClientPromotionSheetRow) -> String? {
    guard let rawDate = row.scheduledDate,
          let date = dayFormatter.date(from: rawDate) else {
      let t = (row.scheduleSummary ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      return t.isEmpty ? nil : t
    }

    let weekday = weekdayFormatter.string(from: date)
    let day = dayNumberFormatter.string(from: date)
    let start = timePart(from: row.validFrom) ?? timeFromSummary(row.scheduleSummary, first: true)
    let end = timePart(from: row.validUntil) ?? timeFromSummary(row.scheduleSummary, first: false)

    let prefix = "\(weekday) \(day)"
    if let start, let end {
      return "\(prefix) • \(start)–\(end)"
    }
    return prefix
  }

  static func exactWindowLine(for row: ClientPromotionSheetRow) -> String? {
    guard let rawDate = row.scheduledDate,
          let date = dayFormatter.date(from: rawDate) else {
      return mainLine(for: row)
    }

    let weekday = weekdayFormatter.string(from: date)
    let day = dayNumberFormatter.string(from: date)
    let start = exactStart(for: row)
    let end = exactEnd(for: row)

    guard let start, let end else {
      return "\(weekday) \(day)"
    }
    return "\(weekday) \(day) • \(start)–\(end)"
  }

  static func toleranceLine(for row: ClientPromotionSheetRow) -> String? {
    guard let validFrom = timePart(from: row.validFrom),
          let validUntil = timePart(from: row.validUntil) else {
      return nil
    }
    return "\(validFrom) – \(validUntil)"
  }

  private static func exactStart(for row: ClientPromotionSheetRow) -> String? {
    guard let from = timePart(from: row.validFrom),
          let grace = row.graceMinutes else {
      return timeFromSummary(row.scheduleSummary, first: true)
    }
    return offset(timeString: from, minutes: grace)
  }

  private static func exactEnd(for row: ClientPromotionSheetRow) -> String? {
    guard let until = timePart(from: row.validUntil),
          let grace = row.graceMinutes else {
      return timeFromSummary(row.scheduleSummary, first: false)
    }
    return offset(timeString: until, minutes: -grace)
  }

  private static func timePart(from isoString: String?) -> String? {
    guard let isoString else { return nil }
    if let date = isoFormatter.date(from: isoString) ?? isoFormatterNoFraction.date(from: isoString) {
      return hourFormatter.string(from: date)
    }
    return nil
  }

  private static func timeFromSummary(_ summary: String?, first: Bool) -> String? {
    guard let summary, !summary.isEmpty else { return nil }
    let matches = summary.components(separatedBy: CharacterSet(charactersIn: " •–-"))
      .filter { $0.range(of: #"^\d{2}:\d{2}$"#, options: .regularExpression) != nil }
    guard !matches.isEmpty else { return nil }
    return first ? matches.first : matches.dropFirst().first ?? matches.last
  }

  struct NextOccurrence {
    let date: Date
    let startTime: String
    let endTime: String
  }

  private static let weekdayMap: [String: Int] = [
    "dim": 1, "lun": 2, "mar": 3, "mer": 4, "jeu": 5, "ven": 6, "sam": 7
  ]

  static func nextOccurrence(for row: ClientPromotionSheetRow, referenceDate now: Date = Date()) -> NextOccurrence? {
    if let rawDate = row.scheduledDate,
       let date = dayFormatter.date(from: rawDate) {
      let start = timePart(from: row.validFrom) ?? timeFromSummary(row.scheduleSummary, first: true) ?? "—"
      let end = timePart(from: row.validUntil) ?? timeFromSummary(row.scheduleSummary, first: false) ?? "—"
      return NextOccurrence(date: date, startTime: start, endTime: end)
    }

    guard let summary = row.scheduleSummary, !summary.isEmpty else { return nil }

    let segments = summary.components(separatedBy: "•").map { $0.trimmingCharacters(in: .whitespaces) }
    var parsed: [(weekday: Int, start: String, end: String)] = []

    for seg in segments {
      let parts = seg.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
      guard parts.count >= 1 else { continue }
      let wdKey = parts[0].lowercased().prefix(3)
      guard let weekday = weekdayMap[String(wdKey)] else { continue }
      let rest = parts.count > 1 ? String(parts[1]) : ""
      let times = rest.components(separatedBy: CharacterSet(charactersIn: " –-"))
        .filter { $0.range(of: #"^\d{2}:\d{2}$"#, options: .regularExpression) != nil }
      guard times.count >= 2 else { continue }
      parsed.append((weekday, times[0], times[1]))
    }

    guard !parsed.isEmpty else { return nil }

    let cal = Calendar(identifier: .gregorian)
    let todayWeekday = cal.component(.weekday, from: now)

    let candidate = parsed.compactMap { item -> (Date, String, String)? in
      var days = (item.weekday - todayWeekday + 7) % 7
      if days == 0 {
        let parts = item.end.split(separator: ":")
        if parts.count == 2, let eh = Int(parts[0]), let em = Int(parts[1]) {
          var c = cal.dateComponents([.year, .month, .day], from: now)
          c.hour = eh
          c.minute = em
          if let endDate = cal.date(from: c), endDate <= now { days = 7 }
        }
      }
      guard let target = cal.date(byAdding: .day, value: days, to: cal.startOfDay(for: now)) else { return nil }
      return (target, item.start, item.end)
    }.min(by: { $0.0 < $1.0 })

    guard let c = candidate else { return nil }
    return NextOccurrence(date: c.0, startTime: c.1, endTime: c.2)
  }

  static func nextOccurrenceLine(for row: ClientPromotionSheetRow) -> String? {
    guard let occ = nextOccurrence(for: row) else { return mainLine(for: row) }
    let wd = weekdayFormatter.string(from: occ.date)
    let d = dayNumberFormatter.string(from: occ.date)
    return "\(wd) \(d) • \(occ.startTime)–\(occ.endTime)"
  }

  private static func offset(timeString: String, minutes: Int) -> String? {
    let parts = timeString.split(separator: ":")
    guard parts.count == 2,
          let h = Int(parts[0]),
          let m = Int(parts[1]) else { return nil }

    let total = h * 60 + m + minutes
    let normalized = ((total % 1440) + 1440) % 1440
    let nh = normalized / 60
    let nm = normalized % 60
    return String(format: "%02d:%02d", nh, nm)
  }
}

struct AboutBlock: View {
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

struct InfoRow: View {
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
            image
              .resizable()
              .scaledToFill()
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

struct ClientMapPageView: View {
  @StateObject private var viewModel = ClientMapViewModel()
  @StateObject private var locationManager = ClientLocationManager()
  @StateObject private var searchVM = ClientMapSearchViewModel()

  @State private var position: MapCameraPosition = .region(
    MKCoordinateRegion(
      center: CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522),
      span: MKCoordinateSpan(latitudeDelta: 0.10, longitudeDelta: 0.10)
    )
  )

  @State private var hasCenteredOnUser: Bool = false
  @State private var visibleComplex: ClientMapComplex?
  @State private var expandedComplex: ClientMapComplex?
  @State private var region: MKCoordinateRegion = MKCoordinateRegion(
    center: CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522),
    span: MKCoordinateSpan(latitudeDelta: 0.10, longitudeDelta: 0.10)
  )
  @State private var lastQueryAt: Date = .distantPast
  @State private var pendingRecenter: Bool = false

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      Map(position: $position, interactionModes: .all) {
        // 1. Complexes sans promo (arrière-plan)
        ForEach(viewModel.complexes.filter { $0.promotionsCount == 0 }) { complex in
          Annotation("", coordinate: complex.coordinate) {
            ClientMapComplexAnnotationView(complex: complex)
              .onTapGesture {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                  if visibleComplex == complex {
                    visibleComplex = nil
                  } else {
                    visibleComplex = complex
                  }
                }
              }
          }
        }

        // 2. Complexes avec promos (au-dessus)
        ForEach(viewModel.complexes.filter { $0.promotionsCount > 0 }) { complex in
          Annotation("", coordinate: complex.coordinate) {
            ClientMapComplexAnnotationView(complex: complex)
              .onTapGesture {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                  if visibleComplex == complex {
                    visibleComplex = nil
                  } else {
                    visibleComplex = complex
                  }
                }
              }
          }
        }

        // 3. Position utilisateur
        if let userLoc = locationManager.location {
          Annotation("", coordinate: userLoc.coordinate) {
            ClientUserLocationIndicatorView(heading: locationManager.heading)
          }
          .annotationTitles(.hidden)
        }
      }
      .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
      .ignoresSafeArea()
      .sheet(item: $expandedComplex) { complex in
        ClientComplexSheetView(complex: complex, userLocation: locationManager.location)
      }
      .onMapCameraChange { ctx in
        region = ctx.region
        let now = Date()
        if now.timeIntervalSince(lastQueryAt) < 0.6 { return }
        lastQueryAt = now
        Task {
          await viewModel.loadComplexes(in: region)
        }
      }

      Button {
        recenter()
      } label: {
        ZStack {
          Circle()
            .fill(Color(red: 0.18, green: 0.19, blue: 0.15))
            .frame(width: 46, height: 46)
            .overlay(
              Circle().strokeBorder(Color.appYellow, lineWidth: 2.5)
            )

          Image(systemName: "scope")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(Color.appYellow)
        }
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
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
    .overlay(alignment: .bottom) {
      if let complex = visibleComplex, expandedComplex == nil {
        ClientComplexMiniCardView(
          complex: complex,
          userLocation: locationManager.location,
          onTap: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
              expandedComplex = complex
            }
          },
          onClose: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
              visibleComplex = nil
            }
          }
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .transition(.asymmetric(
          insertion: .move(edge: .bottom).combined(with: .opacity),
          removal: .move(edge: .bottom).combined(with: .opacity)
        ))
      }
    }
    .overlay(alignment: .top) {
      ClientMapSearchBarView(
        searchVM: searchVM,
        userLocation: locationManager.location,
        onSelect: { result in
          selectSearchResult(result)
        }
      )
      .padding(.horizontal, 16)
      .padding(.top, 8)
    }
    .animation(.spring(response: 0.35, dampingFraction: 0.82), value: expandedComplex)
    .onReceive(NotificationCenter.default.publisher(for: .clientOpenMyPromotions)) { _ in
      withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
        expandedComplex = nil
        visibleComplex = nil
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
    Task {
      await viewModel.loadComplexes(in: r)
    }
  }

  private func selectSearchResult(_ result: ClientMapSearchResult) {
    // Fermer la mini card actuelle
    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
      visibleComplex = nil
    }

    // Centrer la carte sur le complexe
    let coord = CLLocationCoordinate2D(latitude: result.latitude, longitude: result.longitude)
    let r = MKCoordinateRegion(
      center: coord,
      span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )
    region = r
    withAnimation(.easeInOut(duration: 0.5)) {
      position = .region(r)
    }

    // Charger les complexes de la zone puis sélectionner celui recherché
    Task {
      await viewModel.loadComplexes(in: r, force: true)
      if let match = viewModel.complexes.first(where: { $0.id == result.id }) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
          visibleComplex = match
        }
      }
    }
  }
}
