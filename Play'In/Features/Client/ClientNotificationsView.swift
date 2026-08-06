//
//  ClientNotificationsView.swift
//  Play'In
//
//  Cloche de notifications de la home + panneau listant l'historique.
//

import SwiftUI
import Combine
import Supabase

// MARK: - Modèle

struct ClientNotificationRow: Decodable, Identifiable {
  let id: UUID
  let title: String?
  let body: String?
  let sentAt: Date?
  let openedAt: Date?
  let complexId: UUID
  let complexName: String?
  let activityEmoji: String?

  enum CodingKeys: String, CodingKey {
    case id, title, body
    case sent_at, opened_at
    case complex_id, complex_name, activity_emoji
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(UUID.self, forKey: .id)
    title = try c.decodeIfPresent(String.self, forKey: .title)
    body = try c.decodeIfPresent(String.self, forKey: .body)

    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let isoNoFrac = ISO8601DateFormatter()
    isoNoFrac.formatOptions = [.withInternetDateTime]
    func parseDate(_ s: String?) -> Date? {
      guard let s else { return nil }
      return iso.date(from: s) ?? isoNoFrac.date(from: s)
    }
    sentAt = parseDate(try c.decodeIfPresent(String.self, forKey: .sent_at))
    openedAt = parseDate(try c.decodeIfPresent(String.self, forKey: .opened_at))

    complexId = try c.decode(UUID.self, forKey: .complex_id)
    complexName = try c.decodeIfPresent(String.self, forKey: .complex_name)
    activityEmoji = try c.decodeIfPresent(String.self, forKey: .activity_emoji)
  }
}

// MARK: - ViewModel

@MainActor
final class ClientNotificationsViewModel: ObservableObject {
  @Published var rows: [ClientNotificationRow] = []
  @Published var isLoading = false

  var unreadCount: Int { rows.filter { $0.openedAt == nil }.count }

  func load() async {
    isLoading = true
    defer { isLoading = false }
    do {
      let response = try await SupabaseService.shared.client
        .rpc("client_list_notifications")
        .execute()
      rows = try JSONDecoder().decode([ClientNotificationRow].self, from: response.data)
    } catch {
      // Non bloquant : la cloche restera vide
    }
  }

  func markAllRead() async {
    guard unreadCount > 0 else { return }
    do {
      _ = try await SupabaseService.shared.client
        .rpc("client_mark_notifications_read")
        .execute()
      await load()
    } catch {}
  }
}

// MARK: - Bouton cloche (header home)

struct ClientNotificationsBellButton: View {
  let unreadCount: Int
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      ZStack(alignment: .topTrailing) {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(Color.white.opacity(0.06))
          .frame(width: 44, height: 44)
          .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .strokeBorder(Color.appYellow, lineWidth: 1.5)
          )

        Image(systemName: "bell")
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(.white)
          .frame(width: 44, height: 44)

        if unreadCount > 0 {
          Circle()
            .fill(Color.red)
            .frame(width: 9, height: 9)
            .offset(x: -9, y: 9)
        }
      }
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Panneau des notifications

struct ClientNotificationsSheetView: View {
  @ObservedObject var vm: ClientNotificationsViewModel
  let onOpenComplex: (UUID) -> Void

  var body: some View {
    ZStack {
      Color.appBackground.ignoresSafeArea()

      VStack(alignment: .leading, spacing: 0) {
        Text("Notifications")
          .font(.system(size: 28, weight: .black))
          .foregroundStyle(.white)
          .padding(.horizontal, 20)
          .padding(.top, 24)
          .padding(.bottom, 14)

        if vm.isLoading && vm.rows.isEmpty {
          Spacer()
          HStack { Spacer(); ProgressView().tint(.white); Spacer() }
          Spacer()
        } else if vm.rows.isEmpty {
          Spacer()
          VStack(spacing: 8) {
            Image(systemName: "bell.slash")
              .font(.system(size: 34))
              .foregroundStyle(.white.opacity(0.5))
            Text("Aucune notification pour le moment")
              .font(.subheadline)
              .foregroundStyle(.white.opacity(0.6))
          }
          .frame(maxWidth: .infinity)
          Spacer()
        } else {
          ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
              ForEach(groupedRows, id: \.0) { section, rows in
                Text(section)
                  .font(.system(size: 13, weight: .bold))
                  .foregroundStyle(.white.opacity(0.45))
                  .frame(maxWidth: .infinity)
                  .padding(.top, 8)

                ForEach(rows) { row in
                  NotificationCard(row: row) {
                    onOpenComplex(row.complexId)
                  }
                }
              }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
          }
        }
      }
    }
  }

  /// Regroupe par "Aujourd'hui" / "Hier" / date.
  private var groupedRows: [(String, [ClientNotificationRow])] {
    let cal = Calendar.current
    var out: [(String, [ClientNotificationRow])] = []
    for row in vm.rows {
      let label: String
      if let d = row.sentAt {
        if cal.isDateInToday(d) { label = "Aujourd'hui" }
        else if cal.isDateInYesterday(d) { label = "Hier" }
        else {
          let df = DateFormatter()
          df.locale = Locale(identifier: "fr_FR")
          df.dateFormat = "EEEE d MMMM"
          label = df.string(from: d).capitalized
        }
      } else {
        label = "Plus ancien"
      }
      if let idx = out.firstIndex(where: { $0.0 == label }) {
        out[idx].1.append(row)
      } else {
        out.append((label, [row]))
      }
    }
    return out
  }
}

// MARK: - Carte notification

private struct NotificationCard: View {
  let row: ClientNotificationRow
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(alignment: .center, spacing: 12) {
        Text(row.activityEmoji ?? "🏟️")
          .font(.system(size: 24))
          .frame(width: 50, height: 50)
          .background(Color.white.opacity(0.08))
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

        VStack(alignment: .leading, spacing: 3) {
          HStack(spacing: 6) {
            Text(row.title ?? "Notification")
              .font(.system(size: 15, weight: .bold))
              .foregroundStyle(.white)
              .lineLimit(1)
            if row.openedAt == nil {
              Circle().fill(Color.red).frame(width: 7, height: 7)
            }
          }
          if let body = row.body {
            Text(body)
              .font(.system(size: 13))
              .foregroundStyle(.white.opacity(0.6))
              .lineLimit(2)
              .multilineTextAlignment(.leading)
          }
          if let d = row.sentAt {
            Text(relativeLabel(d))
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(.white.opacity(0.35))
          }
        }

        Spacer(minLength: 6)

        Image(systemName: "arrow.up.right")
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(.black)
          .frame(width: 34, height: 34)
          .background(Color.appYellow)
          .clipShape(Circle())
      }
      .padding(12)
      .background(Color.white.opacity(0.06))
      .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  private func relativeLabel(_ date: Date) -> String {
    let f = RelativeDateTimeFormatter()
    f.locale = Locale(identifier: "fr_FR")
    f.unitsStyle = .short
    return f.localizedString(for: date, relativeTo: Date())
  }
}
