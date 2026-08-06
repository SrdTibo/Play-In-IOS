import Foundation
import Combine
import CoreLocation
import Supabase

// MARK: - Models

struct HomeComplexRow: Decodable, Identifiable {
  let id: UUID
  let name: String?
  let city: String?
  let postalCode: String?
  let photos: [String]
  let activitiesJson: [HomeActivity]
  let distanceKm: Double
  let sectionScore: Double
  let promosCount: Int

  enum CodingKeys: String, CodingKey {
    case id, name, city
    case postalCode    = "postal_code"
    case photos
    case activitiesJson = "activities_json"
    case distanceKm    = "distance_km"
    case sectionScore  = "section_score"
    case promosCount   = "promos_count"
  }
}

struct HomeActivity: Decodable, Hashable, Identifiable {
  let id: UUID
  let label: String?
  let emoji: String?
}

struct HomeActivityStat: Decodable {
  let activityLabel: String?
  let activityEmoji: String?
  let count: Int

  enum CodingKeys: String, CodingKey {
    case activityLabel = "activity_label"
    case activityEmoji = "activity_emoji"
    case count
  }
}

struct HomeStatsRow: Decodable {
  let promosUsed: Int
  let savingsEuros: Int
  let activitySessions: [HomeActivityStat]

  enum CodingKeys: String, CodingKey {
    case promosUsed        = "promos_used"
    case savingsEuros      = "savings_euros"
    case activitySessions  = "activity_sessions"
  }
}

// MARK: - ViewModel

@MainActor
final class ClientHomeViewModel: ObservableObject {
  @Published var firstName: String = ""
  @Published var trending: [HomeComplexRow] = []
  @Published var topPromos: [HomeComplexRow] = []
  @Published var nearest: [HomeComplexRow] = []
  @Published var mostVisited: [HomeComplexRow] = []
  @Published var stats: HomeStatsRow?
  @Published var sectionsLoading = false

  func loadProfile() async {
    guard let uid = SupabaseService.shared.currentUserId() else { return }
    do {
      struct Row: Decodable {
        let fn: String?
        enum CodingKeys: String, CodingKey { case fn = "first_name" }
      }
      let rows: [Row] = try await SupabaseService.shared.client
        .from("profiles")
        .select("first_name")
        .eq("id", value: uid)
        .limit(1)
        .execute()
        .value
      firstName = rows.first?.fn ?? ""
    } catch {}
  }

  func loadStats() async {
    do {
      let rows: [HomeStatsRow] = try await SupabaseService.shared.client
        .rpc("client_home_stats")
        .execute()
        .value
      stats = rows.first
    } catch {}
  }

  func loadSections(userLocation: CLLocation) async {
    guard !sectionsLoading else { return }
    sectionsLoading = true
    defer { sectionsLoading = false }

    let lat = userLocation.coordinate.latitude
    let lng = userLocation.coordinate.longitude

    async let t  = fetch("client_home_trending",     lat: lat, lng: lng)
    async let tp = fetch("client_home_top_promos",   lat: lat, lng: lng)
    async let n  = fetch("client_home_nearest",      lat: lat, lng: lng)
    async let mv = fetch("client_home_most_visited", lat: lat, lng: lng)

    // En cas d'échec réseau (ou d'annulation du refresh), on garde les données affichées
    if let rows = await t  { trending    = rows }
    if let rows = await tp { topPromos   = rows }
    if let rows = await n  { nearest     = rows }
    if let rows = await mv { mostVisited = rows }
  }

  private nonisolated func fetch(_ rpc: String, lat: Double, lng: Double) async -> [HomeComplexRow]? {
    let params: [String: Double] = [
      "p_lat": lat, "p_lng": lng, "p_radius_km": 50, "p_limit": 10
    ]
    return try? await SupabaseService.shared.client
      .rpc(rpc, params: params)
      .execute()
      .value
  }

  func loadComplex(id: UUID) async -> ClientMapComplex? {
    do {
      let raw: ClientMapComplexRaw = try await SupabaseService.shared.client
        .from("complexes")
        .select("id,name,city,country,postal_code,address_full,bio,website,phone,latitude,longitude,photos")
        .eq("id", value: id)
        .single()
        .execute()
        .value

      let joinRows: [ClientComplexOfferJoinRow] = try await SupabaseService.shared.client
        .from("complex_activity_offers")
        .select("complex_id,activities(id,label,emoji)")
        .eq("is_active", value: true)
        .eq("complex_id", value: id)
        .execute()
        .value

      let promoRows: [AnnotationPromoRow] = try await SupabaseService.shared.client
        .from("promotions")
        .select("complex_id,promotion_off_peak(reward_amount,reward_unit),promotion_loyalty(reward_amount,reward_unit)")
        .eq("is_active", value: true)
        .eq("complex_id", value: id)
        .execute()
        .value

      var activities: [ClientActivity] = []
      for row in joinRows {
        guard let actId = row.activities?.id,
              let labelRaw = row.activities?.label?.trimmingCharacters(in: .whitespacesAndNewlines),
              !labelRaw.isEmpty else { continue }
        let emoji = (row.activities?.emoji?.trimmingCharacters(in: .whitespacesAndNewlines))
          .flatMap { $0.isEmpty ? nil : $0 } ?? "🏟️"
        let act = ClientActivity(id: actId, label: labelRaw, emoji: emoji)
        if !activities.contains(act) { activities.append(act) }
      }

      var maxPercent: Int? = nil
      var count = 0
      for row in promoRows {
        count += 1
        var amounts: [Int] = []
        if let d = row.offPeak, d.rewardUnit == "percent", let a = d.rewardAmount { amounts.append(a) }
        if let d = row.loyalty, d.rewardUnit == "percent", let a = d.rewardAmount { amounts.append(a) }
        if let m = amounts.max() { maxPercent = max(maxPercent ?? 0, m) }
      }

      guard let lat = raw.latitude, let lng = raw.longitude else { return nil }
      let title = (raw.name?.trimmingCharacters(in: .whitespacesAndNewlines))
        .flatMap { $0.isEmpty ? nil : $0 } ?? "Complexe"

      return ClientMapComplex(
        id: raw.id, name: title,
        city: raw.city, country: raw.country, postalCode: raw.postalCode,
        addressFull: raw.addressFull, bio: raw.bio,
        website: raw.website, phone: raw.phone,
        latitude: lat, longitude: lng,
        photos: raw.photos,
        activities: activities,
        maxPromoPercent: maxPercent,
        promotionsCount: count
      )
    } catch {
      return nil
    }
  }
}
