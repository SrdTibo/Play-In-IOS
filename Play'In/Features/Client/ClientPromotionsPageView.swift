//
//  ClientPromotionsPageView.swift
//  Play'In
//
//  Created by Thibault Serdet on 24/02/2026.
//

import SwiftUI

struct ClientPromotionsPageView: View {
  var body: some View {
    NavigationStack {
      VStack(spacing: 12) {
        Text("Promotions")
          .font(.title2)
          .fontWeight(.bold)
          .frame(maxWidth: .infinity, alignment: .leading)

        Text("Ici on affichera les promotions actives autour de toi (off-peak, fidélité, etc.).")
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)

        Spacer()
      }
      .padding(16)
      .navigationTitle("Promotions")
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}
