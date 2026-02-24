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
