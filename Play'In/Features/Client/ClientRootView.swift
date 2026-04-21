//
//  ClientRootView.swift
//  Play'In
//
//  Created by Thibault Serdet on 22/02/2026.
//

import SwiftUI

struct ClientRootView: View {
  @State private var selection: Int = 0

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
    .onReceive(NotificationCenter.default.publisher(for: .clientOpenMyPromotions)) { _ in
      selection = 2
    }
  }
}
