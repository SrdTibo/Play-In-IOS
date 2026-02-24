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
        VStack(spacing: 16) {
            Text("Accès refusé")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Cette app iOS est réservée aux clients. Merci d’utiliser le web pour ce compte.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Se déconnecter") {
                authViewModel.signOut()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
        .padding()
    }
}
