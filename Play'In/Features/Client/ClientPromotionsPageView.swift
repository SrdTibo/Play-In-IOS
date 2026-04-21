//
//  ClientPromotionsPageView.swift
//  Play'In
//
//  Created by Thibault Serdet on 24/02/2026.
//

import SwiftUI
import Combine
import Supabase
import PostgREST

struct ClientMyPromotionRow: Decodable, Hashable, Identifiable {
  let id: UUID
  let promotionId: UUID
  let complexId: UUID
  let complexName: String?
  let complexPhoto: String?
  let activityId: UUID
  let activityLabel: String?
  let activityEmoji: String?
  let type: String
  let generatedAt: Date?
  let validFrom: Date?
  let validUntil: Date?
  let rewardAmount: Int?
  let rewardUnit: String?
  let rewardCustomLabel: String?
  let offPeakWindowId: UUID?
  let scheduledForDate: String?
  let opwDow: Int?
  let opwStartTime: String?
  let opwEndTime: String?
  let requiredSessions: Int?
  let displayStatus: String

  enum CodingKeys: String, CodingKey {
    case id, promotion_id, complex_id, complex_name, complex_photo
    case activity_id, activity_label, activity_emoji
    case type, generated_at, valid_from, valid_until
    case reward_amount, reward_unit, reward_custom_label
    case off_peak_window_id, scheduled_for_date
    case opw_dow, opw_start_time, opw_end_time
    case required_sessions
    case display_status
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(UUID.self, forKey: .id)
    promotionId = try c.decode(UUID.self, forKey: .promotion_id)
    complexId = try c.decode(UUID.self, forKey: .complex_id)
    complexName = try c.decodeIfPresent(String.self, forKey: .complex_name)
    complexPhoto = try c.decodeIfPresent(String.self, forKey: .complex_photo)
    activityId = try c.decode(UUID.self, forKey: .activity_id)
    activityLabel = try c.decodeIfPresent(String.self, forKey: .activity_label)
    activityEmoji = try c.decodeIfPresent(String.self, forKey: .activity_emoji)
    type = try c.decode(String.self, forKey: .type)

    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let isoNoFrac = ISO8601DateFormatter()
    isoNoFrac.formatOptions = [.withInternetDateTime]
    func parseDate(_ s: String?) -> Date? {
      guard let s else { return nil }
      return iso.date(from: s) ?? isoNoFrac.date(from: s)
    }
    generatedAt = parseDate(try c.decodeIfPresent(String.self, forKey: .generated_at))
    validFrom = parseDate(try c.decodeIfPresent(String.self, forKey: .valid_from))
    validUntil = parseDate(try c.decodeIfPresent(String.self, forKey: .valid_until))

    rewardAmount = try c.decodeIfPresent(Int.self, forKey: .reward_amount)
    rewardUnit = try c.decodeIfPresent(String.self, forKey: .reward_unit)
    rewardCustomLabel = try c.decodeIfPresent(String.self, forKey: .reward_custom_label)
    offPeakWindowId = try c.decodeIfPresent(UUID.self, forKey: .off_peak_window_id)
    scheduledForDate = try c.decodeIfPresent(String.self, forKey: .scheduled_for_date)
    opwDow = try c.decodeIfPresent(Int.self, forKey: .opw_dow)
    opwStartTime = try c.decodeIfPresent(String.self, forKey: .opw_start_time)
    opwEndTime = try c.decodeIfPresent(String.self, forKey: .opw_end_time)
    requiredSessions = try c.decodeIfPresent(Int.self, forKey: .required_sessions)
    displayStatus = try c.decode(String.self, forKey: .display_status)
  }

  var isUsable: Bool {
    displayStatus == "generated" || displayStatus == "usable"
  }

  var rewardPillText: String {
    if let label = rewardCustomLabel, !label.isEmpty { return label }
    guard let amount = rewardAmount else { return "-" }
    switch rewardUnit ?? "" {
    case "percent": return "-\(amount)%"
    case "euro": return "-\(amount)€"
    case "session": return amount > 1 ? "\(amount) offertes" : "1 offerte"
    default: return "\(amount)"
    }
  }
}

@MainActor
final class ClientMyPromotionsViewModel: ObservableObject {
  @Published var rows: [ClientMyPromotionRow] = []
  @Published var isLoading = false
  @Published var errorMessage: String?

  func load() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }
    do {
      let response = try await SupabaseService.shared.client
        .rpc("client_list_my_promotions")
        .execute()
      rows = try JSONDecoder().decode([ClientMyPromotionRow].self, from: response.data)
    } catch {
      errorMessage = "Impossible de charger tes promos"
    }
  }

  func cancel(_ row: ClientMyPromotionRow) async {
    do {
      _ = try await SupabaseService.shared.client
        .rpc("client_cancel_promotion_instance", params: ["p_instance_id": row.id.uuidString])
        .execute()
      await load()
    } catch {
      errorMessage = "Suppression impossible"
    }
  }
}

struct ClientPromotionsPageView: View {
  @StateObject private var vm = ClientMyPromotionsViewModel()
  @State private var selectedTab: Tab = .upcoming
  @State private var selectedActivity: UUID? = nil
  @State private var pendingDelete: ClientMyPromotionRow?

  enum Tab { case upcoming, past }

  private var upcomingRows: [ClientMyPromotionRow] { vm.rows.filter { $0.isUsable } }
  private var pastRows: [ClientMyPromotionRow] { vm.rows.filter { !$0.isUsable } }

  private var activityEmojis: [(id: UUID, emoji: String)] {
    let source = selectedTab == .upcoming ? upcomingRows : pastRows
    var seen = Set<UUID>()
    var out: [(UUID, String)] = []
    for r in source {
      if !seen.contains(r.activityId), let e = r.activityEmoji {
        out.append((r.activityId, e))
        seen.insert(r.activityId)
      }
    }
    return out
  }

  private var visibleRows: [ClientMyPromotionRow] {
    let base = selectedTab == .upcoming ? upcomingRows : pastRows
    if let a = selectedActivity { return base.filter { $0.activityId == a } }
    return base
  }

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      VStack(alignment: .leading, spacing: 16) {
        Text("Promotions")
          .font(.system(size: 34, weight: .heavy))
          .foregroundStyle(.white)
          .padding(.horizontal, 20)
          .padding(.top, 8)

        tabSwitcher
          .padding(.horizontal, 20)

        if !activityEmojis.isEmpty {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
              ForEach(activityEmojis, id: \.id) { item in
                let isSelected = selectedActivity == item.id
                Text(item.emoji)
                  .font(.system(size: 16))
                  .frame(width: 32, height: 32)
                  .background(Circle().fill(Color(white: 0.18)))
                  .overlay(
                    Circle().stroke(isSelected ? Color.appYellow : Color.white.opacity(0.35), lineWidth: 1.5)
                  )
                  .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                      selectedActivity = isSelected ? nil : item.id
                    }
                  }
              }
            }
            .padding(.horizontal, 20)
          }
        }

        if vm.isLoading && vm.rows.isEmpty {
          Spacer()
          HStack { Spacer(); ProgressView().tint(.white); Spacer() }
          Spacer()
        } else if visibleRows.isEmpty {
          Spacer()
          emptyState
          Spacer()
        } else {
          ScrollView {
            LazyVStack(spacing: 14) {
              ForEach(visibleRows) { row in
                ClientMyPromotionCard(row: row, isUsable: row.isUsable) {
                  pendingDelete = row
                }
              }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
          }
        }
      }
    }
    .task { await vm.load() }
    .onChange(of: selectedTab) { _, _ in selectedActivity = nil }
    .toolbar(.hidden, for: .navigationBar)
    .alert(
      "Supprimer cette promo ?",
      isPresented: Binding(
        get: { pendingDelete != nil },
        set: { if !$0 { pendingDelete = nil } }
      ),
      presenting: pendingDelete
    ) { row in
      Button("Supprimer", role: .destructive) {
        Task { await vm.cancel(row) }
        pendingDelete = nil
      }
      Button("Annuler", role: .cancel) {
        pendingDelete = nil
      }
    } message: { _ in
      Text("Cette action est irréversible.")
    }
  }

  private var tabSwitcher: some View {
    HStack(spacing: 0) {
      tabButton("Passées", tab: .past)
      tabButton("À venir", tab: .upcoming)
    }
    .padding(4)
    .background(Capsule().fill(Color(white: 0.18)))
  }

  private func tabButton(_ title: String, tab: Tab) -> some View {
    let selected = selectedTab == tab
    return Text(title)
      .font(.subheadline.weight(.semibold))
      .foregroundStyle(selected ? .black : .white)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 10)
      .background(Capsule().fill(selected ? Color.appYellow : .clear))
      .contentShape(Capsule())
      .onTapGesture {
        withAnimation(.easeInOut(duration: 0.15)) { selectedTab = tab }
      }
  }

  private var emptyState: some View {
    VStack(spacing: 8) {
      Image(systemName: "tag")
        .font(.system(size: 34))
        .foregroundStyle(.white.opacity(0.5))
      Text(selectedTab == .upcoming ? "Aucune promo à venir" : "Aucune promo passée")
        .font(.subheadline)
        .foregroundStyle(.white.opacity(0.6))
    }
    .frame(maxWidth: .infinity)
  }
}

private struct ClientMyPromotionCard: View {
  let row: ClientMyPromotionRow
  let isUsable: Bool
  let onDelete: () -> Void

  var body: some View {
    ZStack(alignment: .topLeading) {
      background
        .allowsHitTesting(false)
      gradient
        .allowsHitTesting(false)
      content
    }
    .frame(height: 130)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(Color.appYellow, lineWidth: 2)
    )
    .overlay(alignment: .bottomTrailing) {
      if isUsable {
        Button(action: onDelete) {
          Image(systemName: "trash.fill")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.black)
            .frame(width: 36, height: 36)
            .background(Circle().fill(Color.white))
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(12)
      }
    }
    .opacity(isUsable ? 1.0 : 0.55)
  }

  @ViewBuilder private var background: some View {
    GeometryReader { geo in
      Group {
        if let s = row.complexPhoto, let url = URL(string: s) {
          AsyncImage(url: url) { phase in
            switch phase {
            case .success(let img):
              img.resizable().scaledToFill()
            default:
              Color(white: 0.15)
            }
          }
        } else {
          Color(white: 0.15)
        }
      }
      .frame(width: geo.size.width, height: geo.size.height)
      .clipped()
    }
  }

  private var gradient: some View {
    LinearGradient(
      colors: [Color.black.opacity(0.85), Color.black.opacity(0.55), Color.black.opacity(0.85)],
      startPoint: .top, endPoint: .bottom
    )
  }

  private var content: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .top, spacing: 6) {
        if let label = row.activityLabel {
          HStack(spacing: 4) {
            if let e = row.activityEmoji { Text(e).font(.system(size: 12)) }
            Text(label)
              .font(.caption.weight(.semibold))
              .foregroundStyle(.white)
          }
          .padding(.horizontal, 8).padding(.vertical, 5)
          .background(Capsule().fill(Color.black))
        }
        if let name = row.complexName {
          Text(name)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(Capsule().fill(Color.black))
        }
        Spacer()
        Text(row.rewardPillText)
          .font(.caption.weight(.bold))
          .foregroundStyle(.black)
          .padding(.horizontal, 10).padding(.vertical, 5)
          .background(Capsule().fill(Color.appYellow))
      }

      Spacer()

      HStack(alignment: .bottom) {
        VStack(alignment: .leading, spacing: 2) {
          Text(primaryBottomLine)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
          Text("*Sous condition d'une réservation*")
            .font(.caption)
            .italic()
            .foregroundStyle(.white.opacity(0.85))
            .lineLimit(1)
        }
        Spacer()
        // Réserve la place du bouton placé en overlay pour éviter le chevauchement avec le texte
        if isUsable {
          Color.clear.frame(width: 36, height: 36)
        }
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private var primaryBottomLine: String {
    if row.type == "off_peak" {
      let date = offPeakDateLine()
      if let hours = offPeakHoursLine() {
        return "\(date) / \(hours)"
      }
      return date
    } else {
      if let req = row.requiredSessions {
        return req > 1 ? "\(req) séances réalisées" : "\(req) séance réalisée"
      }
      return "Fidélité"
    }
  }

  private func offPeakDateLine() -> String {
    if let s = row.scheduledForDate {
      let inFmt = DateFormatter()
      inFmt.locale = Locale(identifier: "en_US_POSIX")
      inFmt.dateFormat = "yyyy-MM-dd"
      if let d = inFmt.date(from: s) {
        let df = DateFormatter()
        df.locale = Locale(identifier: "fr_FR")
        df.dateFormat = "EEEE d MMMM"
        return df.string(from: d).capitalized
      }
    }
    return "Heure creuse"
  }

  private func offPeakHoursLine() -> String? {
    guard let start = row.opwStartTime, let end = row.opwEndTime else { return nil }
    return "\(trimSeconds(start)) à \(trimSeconds(end))"
  }

  private func trimSeconds(_ s: String) -> String {
    let parts = s.split(separator: ":")
    if parts.count >= 2 { return "\(parts[0]):\(parts[1])" }
    return s
  }
}
