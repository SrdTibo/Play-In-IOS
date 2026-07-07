//
//  AuthViewModel.swift
//  Play'In
//
//  Created by Thibault Serdet on 22/02/2026.
//

import Foundation
import Combine
import Supabase
import PostgREST
import AuthenticationServices
import CryptoKit
import UIKit

enum AuthRoute {
  case unknown
  case signedOut
  case wrongRole
  case onboarding
  case client
}

struct ProfileOnboardingUpdate: Encodable {
  let onboardingCompleted: Bool

  enum CodingKeys: String, CodingKey {
    case onboardingCompleted = "onboarding_completed"
  }
}

@MainActor
final class AuthViewModel: ObservableObject {
  @Published var route: AuthRoute = .unknown
  @Published var isLoading: Bool = false
  @Published var errorMessage: String?
  @Published var email: String = ""
  @Published var otpCode: String = ""
  @Published var pendingOTPEmail: String?
  @Published var profile: Profile?

  private let supabase: SupabaseService

  init(supabase: SupabaseService) {
    self.supabase = supabase
  }

  func start() {
    Task { await refresh() }
  }

  func refresh() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    guard let userId = supabase.currentUserId() else {
      profile = nil
      route = .signedOut
      return
    }

    do {
      let profile = try await supabase.fetchOrCreateClientProfile(userId: userId)
      self.profile = profile

      if profile.role != UserRole.client.rawValue {
        route = .wrongRole
        return
      }

      route = (profile.onboardingCompleted ?? false) ? .client : .onboarding
    } catch let error as SupabaseServiceError {
      switch error {
      case .wrongRole:
        profile = nil
        route = .wrongRole
      case .unauthenticated:
        profile = nil
        route = .signedOut
      default:
        profile = nil
        route = .signedOut
        errorMessage = error.localizedDescription
      }
    } catch {
      profile = nil
      route = .signedOut
      errorMessage = error.localizedDescription
    }
  }
    
    func signInWithGoogle() {
      isLoading = true
      errorMessage = nil

      Task {
        defer { isLoading = false }
        do {
          try await supabase.signInWithGoogle()
          pendingOTPEmail = nil
          otpCode = ""
          await refresh()
        } catch {
          errorMessage = error.localizedDescription
        }
      }
    }

  // MARK: - Sign in with Apple

  /// Nonce brut de la requête Apple en cours (anti-rejeu).
  var currentAppleNonce: String?

  /// Garde le délégué en vie pendant le flow Apple.
  private var appleCoordinator: AppleSignInCoordinator?

  /// Lance le flow natif Sign in with Apple (appelé depuis un bouton custom).
  func signInWithApple() {
    let nonce = Self.randomNonceString()
    currentAppleNonce = nonce

    let request = ASAuthorizationAppleIDProvider().createRequest()
    request.requestedScopes = [.fullName, .email]
    request.nonce = Self.sha256(nonce)

    let controller = ASAuthorizationController(authorizationRequests: [request])
    let coordinator = AppleSignInCoordinator { [weak self] result in
      Task { @MainActor in
        self?.handleAppleSignIn(result)
        self?.appleCoordinator = nil
      }
    }
    appleCoordinator = coordinator
    controller.delegate = coordinator
    controller.presentationContextProvider = coordinator
    controller.performRequests()
  }

  private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
    switch result {
    case .failure(let error):
      // L'utilisateur a annulé : pas une erreur
      if let authError = error as? ASAuthorizationError, authError.code == .canceled { return }
      errorMessage = error.localizedDescription

    case .success(let auth):
      guard
        let credential = auth.credential as? ASAuthorizationAppleIDCredential,
        let tokenData = credential.identityToken,
        let idToken = String(data: tokenData, encoding: .utf8),
        let nonce = currentAppleNonce
      else {
        errorMessage = "Connexion avec Apple impossible."
        return
      }

      // Apple ne fournit le nom qu'à la toute première connexion
      let givenName = credential.fullName?.givenName
      let familyName = credential.fullName?.familyName

      isLoading = true
      errorMessage = nil

      Task {
        defer { isLoading = false }
        do {
          _ = try await supabase.client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
          )
          pendingOTPEmail = nil
          otpCode = ""
          await refresh()
          await fillNameFromAppleIfEmpty(givenName: givenName, familyName: familyName)
        } catch {
          errorMessage = error.localizedDescription
        }
      }
    }
  }

  private func fillNameFromAppleIfEmpty(givenName: String?, familyName: String?) async {
    guard let userId = supabase.currentUserId() else { return }
    let currentFirst = (profile?.firstName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    guard currentFirst.isEmpty, let first = givenName, !first.isEmpty else { return }

    struct NameUpdate: Encodable {
      let firstName: String
      let lastName: String?
      enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
      }
    }
    do {
      _ = try await supabase.client
        .from("profiles")
        .update(NameUpdate(firstName: first, lastName: familyName))
        .eq("id", value: userId)
        .execute()
      await refresh()
    } catch {
      // Non bloquant : l'utilisateur pourra remplir son nom dans l'onboarding
    }
  }

  private static func randomNonceString(length: Int = 32) -> String {
    let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var bytes = [UInt8](repeating: 0, count: length)
    let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
    precondition(status == errSecSuccess, "SecRandomCopyBytes a échoué")
    return String(bytes.map { charset[Int($0) % charset.count] })
  }

  private static func sha256(_ input: String) -> String {
    SHA256.hash(data: Data(input.utf8))
      .map { String(format: "%02x", $0) }
      .joined()
  }

}

/// Délégué du flow ASAuthorization (fenêtre de présentation + résultat).
final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
  private let onResult: (Result<ASAuthorization, Error>) -> Void

  init(onResult: @escaping (Result<ASAuthorization, Error>) -> Void) {
    self.onResult = onResult
  }

  func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
    onResult(.success(authorization))
  }

  func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
    onResult(.failure(error))
  }

  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    let window = UIApplication.shared.connectedScenes
      .compactMap { ($0 as? UIWindowScene)?.keyWindow }
      .first
    return window ?? ASPresentationAnchor()
  }
}

extension AuthViewModel {

  func sendEmailOTPCode() {
    let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }

    isLoading = true
    errorMessage = nil

    Task {
      defer { isLoading = false }
      do {
        try await supabase.client.auth.signInWithOTP(email: trimmed, redirectTo: nil)
        pendingOTPEmail = trimmed
        otpCode = ""
      } catch {
        errorMessage = error.localizedDescription
      }
    }
  }

  func verifyEmailOTPCode() {
    let code = otpCode.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !code.isEmpty else { return }
    guard let otpEmail = pendingOTPEmail else { return }

    isLoading = true
    errorMessage = nil

    Task {
      defer { isLoading = false }
      do {
        _ = try await supabase.client.auth.verifyOTP(
          email: otpEmail,
          token: code,
          type: .email,
          redirectTo: nil
        )
        pendingOTPEmail = nil
        otpCode = ""
        await refresh()
      } catch {
        errorMessage = error.localizedDescription
      }
    }
  }

  func sendMagicLink() {
    sendEmailOTPCode()
  }

  func handleOpenURL(_ url: URL) {
    supabase.handleOpenURL(url)
    Task { await refresh() }
  }

  func completeOnboarding() {
    isLoading = true
    errorMessage = nil

    Task {
      defer { isLoading = false }

      guard let userId = supabase.currentUserId() else {
        profile = nil
        route = .signedOut
        return
      }

      do {
        _ = try await supabase.client
          .from("profiles")
          .update(ProfileOnboardingUpdate(onboardingCompleted: true))
          .eq("id", value: userId)
          .execute()

        await refresh()
      } catch {
        errorMessage = error.localizedDescription
      }
    }
  }

  func signOut() {
    isLoading = true
    errorMessage = nil

    Task {
      defer { isLoading = false }
      do {
        try await supabase.signOut()
        profile = nil
        route = .signedOut
        pendingOTPEmail = nil
        otpCode = ""
      } catch {
        errorMessage = error.localizedDescription
      }
    }
  }
}
