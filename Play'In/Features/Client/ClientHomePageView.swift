//
//  ClientHomePageView.swift
//  Play'In
//
//  Created by Thibault Serdet on 24/02/2026.
//

import SwiftUI

struct ClientHomePageView: View {
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          Text("Accueil")
            .font(.title)
            .fontWeight(.bold)
            .padding(.top, 8)

          VStack(alignment: .leading, spacing: 8) {
            Text("Bienvenue sur Play’In 👋")
              .font(.headline)
            Text("Trouve un complexe, découvre des offres et profite des promos.")
              .foregroundStyle(.secondary)
          }
          .padding(14)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(.ultraThinMaterial)
          .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

          VStack(alignment: .leading, spacing: 10) {
            Text("Raccourcis")
              .font(.headline)

            HStack(spacing: 10) {
              NavigationLink {
                ClientMapPageView()
              } label: {
                HStack(spacing: 10) {
                  Image(systemName: "map.fill")
                  Text("Ouvrir la carte")
                    .fontWeight(.semibold)
                  Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
              }

              NavigationLink {
                ClientPromotionsPageView()
              } label: {
                HStack(spacing: 10) {
                  Image(systemName: "tag.fill")
                  Text("Promos")
                    .fontWeight(.semibold)
                  Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
              }
            }
          }

          Spacer(minLength: 0)
        }
        .padding(16)
      }
      .navigationTitle("Home")
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}
