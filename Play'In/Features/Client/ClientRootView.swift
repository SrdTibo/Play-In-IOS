//
//  ClientRootView.swift
//  Play'In
//
//  Created by Thibault Serdet on 22/02/2026.
//

import SwiftUI

struct ClientRootView: View {
  @State private var selection: Int = 0

  init() {
    let dark = Color(red: 0.10, green: 0.10, blue: 0.08)
    let darkUI = UIColor(red: 0.10, green: 0.10, blue: 0.08, alpha: 1)
    let yellowUI = UIColor(red: 0.88, green: 1.0, blue: 0.18, alpha: 1)
    let inactiveUI = UIColor(white: 0.45, alpha: 1)

    let appearance = UITabBarAppearance()
    appearance.configureWithOpaqueBackground()
    appearance.backgroundColor = darkUI

    let normalAttrs: [NSAttributedString.Key: Any] = [.foregroundColor: inactiveUI]
    let selectedAttrs: [NSAttributedString.Key: Any] = [.foregroundColor: yellowUI]

    appearance.stackedLayoutAppearance.normal.iconColor = inactiveUI
    appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttrs
    appearance.stackedLayoutAppearance.selected.iconColor = yellowUI
    appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttrs

    appearance.inlineLayoutAppearance.normal.iconColor = inactiveUI
    appearance.inlineLayoutAppearance.normal.titleTextAttributes = normalAttrs
    appearance.inlineLayoutAppearance.selected.iconColor = yellowUI
    appearance.inlineLayoutAppearance.selected.titleTextAttributes = selectedAttrs

    appearance.compactInlineLayoutAppearance.normal.iconColor = inactiveUI
    appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = normalAttrs
    appearance.compactInlineLayoutAppearance.selected.iconColor = yellowUI
    appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = selectedAttrs

    UITabBar.appearance().standardAppearance = appearance
    UITabBar.appearance().scrollEdgeAppearance = appearance

    _ = dark // suppress unused warning
  }

  var body: some View {
    TabView(selection: $selection) {
      ClientHomePageView()
        .tabItem {
          Image(systemName: "house.fill")
          Text("Home")
        }
        .tag(0)

      ClientMapPageView()
        .tabItem {
          Image(systemName: "map.fill")
          Text("Carte")
        }
        .tag(1)

      ClientPromotionsPageView()
        .tabItem {
          Image(systemName: "tag.fill")
          Text("Promos")
        }
        .tag(2)

      ClientAccountPageView()
        .tabItem {
          Image(systemName: "person.fill")
          Text("Profil")
        }
        .tag(3)
    }
    .tint(Color.appYellow)
    .onReceive(NotificationCenter.default.publisher(for: .clientOpenMyPromotions)) { _ in
      selection = 2
    }
  }
}
