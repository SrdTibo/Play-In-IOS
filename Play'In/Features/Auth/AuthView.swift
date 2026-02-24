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
      VStack(spacing: 16) {
        Spacer()

        Text("Play’In")
          .font(.largeTitle)
          .fontWeight(.semibold)

        Button {
          authViewModel.signInWithGoogle()
        } label: {
          Text("Continuer avec Google")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)

        VStack(spacing: 12) {
          TextField("Email", text: $authViewModel.email)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .padding(12)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

          if authViewModel.pendingOTPEmail == nil {
            Button {
              authViewModel.sendEmailOTPCode()
            } label: {
              Text("Envoyer le code")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
          } else {
            Text("Code envoyé à \(authViewModel.pendingOTPEmail ?? "")")
              .font(.footnote)
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)

            TextField("Code", text: $authViewModel.otpCode)
              .keyboardType(.numberPad)
              .textContentType(.oneTimeCode)
              .textInputAutocapitalization(.never)
              .autocorrectionDisabled()
              .padding(12)
              .background(.thinMaterial)
              .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
              authViewModel.verifyEmailOTPCode()
            } label: {
              Text("Vérifier le code")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            HStack(spacing: 12) {
              Button {
                authViewModel.sendEmailOTPCode()
              } label: {
                Text("Renvoyer")
                  .frame(maxWidth: .infinity)
              }
              .buttonStyle(.bordered)

              Button {
                authViewModel.pendingOTPEmail = nil
                authViewModel.otpCode = ""
              } label: {
                Text("Changer d’email")
                  .frame(maxWidth: .infinity)
              }
              .buttonStyle(.bordered)
            }
          }

          if let message = authViewModel.errorMessage, !message.isEmpty {
            Text(message)
              .font(.footnote)
              .foregroundStyle(.red)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }

        Spacer()
      }
      .padding()

      if authViewModel.isLoading {
        Color.black.opacity(0.2)
          .ignoresSafeArea()

        ProgressView()
      }
    }
  }
}
