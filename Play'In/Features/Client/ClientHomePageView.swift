import SwiftUI
import CoreLocation

extension Notification.Name {
  static let clientOpenMapSearch = Notification.Name("clientOpenMapSearch")
  /// Tap sur une notification push : ouvre la fiche du complexe (objet = UUID).
  static let clientOpenComplexFromNotification = Notification.Name("clientOpenComplexFromNotification")
}

// MARK: - Main View

struct ClientHomePageView: View {
  @StateObject private var locationManager = ClientLocationManager()
  @StateObject private var vm = ClientHomeViewModel()
  @StateObject private var promosVM = ClientMyPromotionsViewModel()

  @State private var selectedComplex: ClientMapComplex?
  @State private var isLoadingComplex = false

  // Notifications
  @StateObject private var notifsVM = ClientNotificationsViewModel()
  @State private var showNotifications = false

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      Color.appBackground.ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: 28) {
          headerSection
          searchBarButton
          if vm.sectionsLoading && vm.trending.isEmpty {
            loadingPlaceholder
          } else {
            sectionsContent
          }
          Spacer(minLength: 80)
        }
        .padding(.top, 20)
      }
      .refreshable {
        // Task interne : survit à l'annulation du geste par SwiftUI
        await Task {
          await vm.loadProfile()
          await vm.loadStats()
          await promosVM.load()
          await notifsVM.load()
          if let loc = locationManager.location {
            await vm.loadSections(userLocation: loc)
          }
        }.value
      }

      ClientQRFloatingButton(usablePromosCount: promosVM.rows.filter { $0.isUsable }.count)
        .padding(.trailing, 20)
        .padding(.bottom, 20)

      if isLoadingComplex {
        Color.black.opacity(0.35).ignoresSafeArea()
        ProgressView().tint(Color.appYellow).scaleEffect(1.4)
      }
    }
    .task {
      locationManager.start()
      await vm.loadProfile()
      await vm.loadStats()
      await promosVM.load()
      await notifsVM.load()
    }
    .onChange(of: locationManager.location) { _, newLoc in
      guard let loc = newLoc, vm.trending.isEmpty else { return }
      Task { await vm.loadSections(userLocation: loc) }
    }
    .onReceive(NotificationCenter.default.publisher(for: .clientOpenMyPromotions)) { _ in
      // "Voir ma promo" depuis une fiche ouverte sur la home :
      // on ferme la fiche pour laisser voir l'onglet Promotions
      selectedComplex = nil
    }
    .onReceive(NotificationCenter.default.publisher(for: .clientOpenComplexFromNotification)) { note in
      guard let complexId = note.object as? UUID else { return }
      showNotifications = false
      openComplex(id: complexId)
    }
    .sheet(item: $selectedComplex) { complex in
      ClientComplexSheetView(complex: complex, userLocation: locationManager.location)
    }
    .sheet(isPresented: $showNotifications, onDismiss: {
      Task { await notifsVM.markAllRead() }
    }) {
      ClientNotificationsSheetView(vm: notifsVM) { complexId in
        showNotifications = false
        // Laisse la sheet se fermer avant d'ouvrir la fiche complexe
        Task {
          try? await Task.sleep(for: .milliseconds(350))
          openComplex(id: complexId)
        }
      }
      .presentationDetents([.large])
      .presentationDragIndicator(.visible)
    }
  }

  private func openComplex(id: UUID) {
    guard !isLoadingComplex else { return }
    isLoadingComplex = true
    Task {
      if let complex = await vm.loadComplex(id: id) {
        selectedComplex = complex
      }
      isLoadingComplex = false
    }
  }

  // MARK: - Header

  private var headerSection: some View {
    HStack {
      Text(vm.firstName.isEmpty
           ? "Hey 👋"
           : "Hey, \(vm.firstName) 👋")
        .font(.system(size: 28, weight: .black))
        .foregroundColor(.white)
      Spacer()
      ClientNotificationsBellButton(unreadCount: notifsVM.unreadCount) {
        showNotifications = true
      }
    }
    .padding(.horizontal, 20)
  }

  // MARK: - Search bar (shortcut → carte)

  private var searchBarButton: some View {
    Button {
      NotificationCenter.default.post(name: .clientOpenMapSearch, object: nil)
    } label: {
      HStack(spacing: 10) {
        Image(systemName: "magnifyingglass")
          .font(.system(size: 15, weight: .semibold))
          .foregroundColor(.white.opacity(0.4))
        Text("Rechercher un complexe...")
          .font(.system(size: 15, weight: .semibold))
          .foregroundColor(.white.opacity(0.35))
        Spacer()
      }
      .padding(.horizontal, 16)
      .frame(height: 48)
      .background(Color.white.opacity(0.08))
      .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
    .padding(.horizontal, 20)
  }

  // MARK: - All sections

  @ViewBuilder
  private var sectionsContent: some View {
    if !vm.trending.isEmpty {
      HomeSectionBlock(title: "En tendance", rows: vm.trending, onTap: openComplex)
    }
    HomeStatsSection(stats: vm.stats)
    if !vm.topPromos.isEmpty {
      HomeSectionBlock(title: "Top promos", rows: vm.topPromos, onTap: openComplex)
    }
    if !vm.nearest.isEmpty {
      HomeSectionBlock(title: "Le plus proche", rows: vm.nearest, onTap: openComplex)
    }
    if !vm.mostVisited.isEmpty {
      HomeSectionBlock(title: "Les plus visités", rows: vm.mostVisited, onTap: openComplex)
    }
    let denied = locationManager.authorizationStatus == .denied
      || locationManager.authorizationStatus == .restricted
    if denied {
      noLocationHint
    } else if vm.trending.isEmpty && vm.nearest.isEmpty && !vm.sectionsLoading {
      noComplexesHint
    }
  }

  private var loadingPlaceholder: some View {
    VStack(spacing: 12) {
      ForEach(0..<2, id: \.self) { _ in
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .fill(Color.white.opacity(0.06))
          .frame(height: 200)
          .padding(.horizontal, 20)
      }
    }
  }

  private var noLocationHint: some View {
    Text("Active la localisation dans les réglages pour voir les complexes près de chez toi.")
      .font(.system(size: 14, weight: .semibold))
      .foregroundColor(.white.opacity(0.45))
      .multilineTextAlignment(.center)
      .padding(.horizontal, 32)
      .padding(.top, 12)
      .frame(maxWidth: .infinity)
  }

  private var noComplexesHint: some View {
    Text("Aucun complexe trouvé dans ton secteur pour le moment.")
      .font(.system(size: 14, weight: .semibold))
      .foregroundColor(.white.opacity(0.45))
      .multilineTextAlignment(.center)
      .padding(.horizontal, 32)
      .padding(.top, 12)
      .frame(maxWidth: .infinity)
  }
}

// MARK: - Section block (titre + carrousel)

private struct HomeSectionBlock: View {
  let title: String
  let rows: [HomeComplexRow]
  let onTap: (UUID) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(title)
        .font(.system(size: 20, weight: .black))
        .foregroundColor(.white)
        .padding(.horizontal, 20)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 14) {
          ForEach(rows) { row in
            HomeComplexCard(row: row, onTap: { onTap(row.id) })
          }
        }
        .padding(.horizontal, 20)
      }
    }
  }
}

// MARK: - Complex card

private struct HomeComplexCard: View {
  let row: HomeComplexRow
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      VStack(alignment: .leading, spacing: 8) {
        photoBlock
        infoBlock
      }
      .frame(width: 260)
    }
    .buttonStyle(.plain)
  }

  private var photoBlock: some View {
    ZStack(alignment: .bottom) {
      Group {
        if let urlStr = row.photos.first, let url = URL(string: urlStr) {
          AsyncImage(url: url) { phase in
            switch phase {
            case .success(let img):
              img.resizable().scaledToFill()
            default:
              Color.white.opacity(0.05)
            }
          }
        } else {
          Color.white.opacity(0.05)
        }
      }
      .frame(width: 260, height: 170)
      .clipped()

      // Gradient + nom
      ZStack(alignment: .bottomLeading) {
        LinearGradient(
          colors: [.clear, .black.opacity(0.75)],
          startPoint: .top, endPoint: .bottom
        )
        .frame(height: 80)

        Text(row.name ?? "")
          .font(.system(size: 17, weight: .black))
          .foregroundColor(.white)
          .lineLimit(1)
          .padding(.horizontal, 12)
          .padding(.bottom, 10)
      }

      // Emojis activités (haut droit)
      VStack {
        HStack {
          Spacer()
          HStack(spacing: 4) {
            ForEach(Array(row.activitiesJson.prefix(3))) { act in
              Text(act.emoji ?? "")
                .font(.system(size: 18))
                .frame(width: 32, height: 32)
                .background(Color.black.opacity(0.5))
                .clipShape(Circle())
            }
          }
          .padding(.trailing, 10)
        }
        Spacer()
      }
      .padding(.top, 10)
    }
    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
  }

  private var infoBlock: some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack(spacing: 4) {
        Image(systemName: "mappin.fill")
          .font(.system(size: 10))
          .foregroundColor(Color.appYellow)
        Text(locationText)
          .font(.system(size: 13, weight: .semibold))
          .foregroundColor(.white)
          .lineLimit(1)
      }

      if !row.activitiesJson.isEmpty {
        Text(row.activitiesJson.compactMap { $0.label }.joined(separator: " - "))
          .font(.system(size: 12, weight: .semibold))
          .foregroundColor(.white.opacity(0.5))
          .lineLimit(1)
          .padding(.horizontal, 10)
          .padding(.vertical, 5)
          .background(Color.white.opacity(0.08))
          .clipShape(Capsule())
      }
    }
  }

  private var locationText: String {
    var parts: [String] = []
    if let city = row.city { parts.append(city) }
    if row.distanceKm > 0 {
      let km = row.distanceKm < 1
        ? String(format: "%.0fm", row.distanceKm * 1000)
        : "\(Int(row.distanceKm.rounded()))km"
      parts.append(km)
    }
    return parts.joined(separator: " – ")
  }
}

// MARK: - Stats section

private struct HomeStatsSection: View {
  let stats: HomeStatsRow?

  var body: some View {
    if let s = stats {
      VStack(alignment: .leading, spacing: 14) {
        Text("Statistiques")
          .font(.system(size: 20, weight: .black))
          .foregroundColor(.white)
          .padding(.horizontal, 20)

        // Cartes d'activité (pleine largeur)
        if !s.activitySessions.isEmpty {
          VStack(spacing: 10) {
            ForEach(Array(s.activitySessions.prefix(2).enumerated()), id: \.offset) { i, stat in
              StatActivityCard(stat: stat, isAccent: i == 1)
            }
          }
          .padding(.horizontal, 20)
        }

        // Mini cards : promos utilisées + gains
        HStack(spacing: 10) {
          StatMiniCard(label: "Promotions utilisées", value: "\(s.promosUsed)")
          StatMiniCard(label: "Gains réalisés",       value: "\(s.savingsEuros)€")
        }
        .padding(.horizontal, 20)
      }
    }
  }
}

private struct StatActivityCard: View {
  let stat: HomeActivityStat
  let isAccent: Bool

  private var fg: Color { isAccent ? Color.appDark : .white }
  private var bg: Color { isAccent ? Color.appYellow : Color.white.opacity(0.06) }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Sur les 30 derniers jours")
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(fg.opacity(0.6))

      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text("\(stat.count)")
          .font(.system(size: 44, weight: .black))
          .foregroundColor(fg)

        HStack(spacing: 4) {
          Text(stat.activityLabel ?? "")
            .font(.system(size: 17, weight: .bold))
            .foregroundColor(fg)
          if let emoji = stat.activityEmoji {
            Text(emoji).font(.system(size: 22))
          }
        }
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(bg)
    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
  }
}

private struct StatMiniCard: View {
  let label: String
  let value: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label)
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(.white.opacity(0.55))
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
      Text(value)
        .font(.system(size: 34, weight: .black))
        .foregroundColor(.white)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.white.opacity(0.06))
    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
  }
}
