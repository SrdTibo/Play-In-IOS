//
//  AuthView.swift
//  Play'In
//
//  Created by Thibault Serdet on 22/02/2026.
//

import SwiftUI

struct AuthView: View {
  @EnvironmentObject var authViewModel: AuthViewModel

  var body: some View {
    ZStack {
      AuthBackground()

      VStack(spacing: 0) {
        Spacer()

        // ── Logo ──────────────────────────────────────────────────────
        PlayInBrandMark()

        Spacer()

        // ── Formulaire de connexion ───────────────────────────────────
        VStack(spacing: 14) {

          // Bouton Google
          Button { authViewModel.signInWithGoogle() } label: {
            HStack(spacing: 10) {
              Text("G")
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96))
              Text("Continuer avec Google")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.appDark)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
          }

          PIOrSeparator()

          // Champ email
          TextField("Adresse email", text: $authViewModel.email)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(.emailAddress)
            .piInputStyle()

          if authViewModel.pendingOTPEmail == nil {
            // Étape 1 : envoyer le code
            PIActionButton(title: "Envoyer le code", style: .outlined) {
              authViewModel.sendEmailOTPCode()
            }
          } else {
            // Étape 2 : saisir et vérifier le code
            VStack(spacing: 10) {
              Text("Code envoyé à \(authViewModel.pendingOTPEmail ?? "")")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)

              TextField("Code à 6 chiffres", text: $authViewModel.otpCode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .piInputStyle()

              PIActionButton(title: "Vérifier le code", style: .primary) {
                authViewModel.verifyEmailOTPCode()
              }

              HStack(spacing: 10) {
                PIActionButton(title: "Renvoyer", style: .ghost) {
                  authViewModel.sendEmailOTPCode()
                }
                PIActionButton(title: "Changer d'email", style: .ghost) {
                  authViewModel.pendingOTPEmail = nil
                  authViewModel.otpCode = ""
                }
              }
            }
          }

          if let msg = authViewModel.errorMessage, !msg.isEmpty {
            PIErrorRow(message: msg)
          }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 52)
      }

      if authViewModel.isLoading {
        PILoadingOverlay()
      }
    }
    .preferredColorScheme(.dark)
  }
}
