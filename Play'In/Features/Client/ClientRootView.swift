//
//  ClientRootView.swift
//  Play'In
//
//  Created by Thibault Serdet on 22/02/2026.
//

import SwiftUI

struct ClientRootView: View {
  var body: some View {
    TabView {
      ClientHomePageView()
        .tabItem {
          Image(systemName: "house.fill")
          Text("Home")
        }

      ClientMapPageView()
        .tabItem {
          Image(systemName: "map.fill")
          Text("Carte")
        }

      ClientPromotionsPageView()
        .tabItem {
          Image(systemName: "tag.fill")
          Text("Promos")
        }

      ClientAccountPageView()
        .tabItem {
          Image(systemName: "person.fill")
          Text("Profil")
        }
    }
  }
}
