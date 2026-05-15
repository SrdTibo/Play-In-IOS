//
//  WrongRoleView.swift
//  Play'In
//
//  Created by Thibault Serdet on 22/02/2026.
//

import SwiftUI

struct WrongRoleView: View {
  @EnvironmentObject var authViewModel: AuthViewModel

  var body: some View {
    ZStack {
      AuthBackground()

      VStack(spacing: 0) {
        Spacer()

        VStack(spacing: 20) {
          // Icône
          ZStack {
            Circle()
              .fill(Color.white.opacity(0.07))
              .frame(width: 80, height: 80)
            Image(systemName: "lock.shield.fill")
              .font(.system(size: 34, weight: .bold))
              .foregroundStyle(.white.opacity(0.55))
          }

          // Texte
          VStack(spacing: 10) {
            Text("Accès refusé")
              .font(.system(size: 26, weight: .black))
              .foregroundStyle(.white)

            Text("Cette app iOS est réservée aux clients.\nMerci d'utiliser le backoffice web\npour ce compte.")
              .font(.system(size: 14, weight: .medium))
              .foregroundStyle(.white.opacity(0.45))
              .multilineTextAlignment(.center)
              .lineSpacing(3)
          }
        }

        Spacer()

        PIActionButton(title: "Se déconnecter", style: .outlined) {
          authViewModel.signOut()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 52)
      }
    }
    .preferredColorScheme(.dark)
  }
}
