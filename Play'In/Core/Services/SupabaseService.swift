//
//  SupabaseService.swift
//  Play'In
//
//  Created by Thibault Serdet on 22/02/2026.
//

import Foundation
import Supabase

enum SupabaseServiceError: LocalizedError {
  case missingInfoPlistValue(String)
  case invalidURL(String)
  case emptyValue(String)
  case unauthenticated
  case wrongRole

  var errorDescription: String? {
    switch self {
    case .missingInfoPlistValue(let key):
      return "Missing Info.plist key: \(key)"
    case .invalidURL(let value):
      return "Invalid URL value: \(value)"
    case .emptyValue(let key):
      return "Empty Info.plist value for key: \(key)"
    case .unauthenticated:
      return "Unauthenticated"
    case .wrongRole:
      return "Wrong role"
    }
  }
}

struct SupabaseConfig: Sendable {
  let url: URL
  let anonKey: String
  let redirectURL: URL

  static func load(from bundle: Bundle = .main) throws -> SupabaseConfig {
    let urlString = try readString("SupabaseURL", from: bundle)
    let anonKey = try readString("SupabaseAnonKey", from: bundle)
    let redirectString = try readString("SupabaseRedirectURL", from: bundle)

    guard let url = URL(string: urlString) else { throw SupabaseServiceError.invalidURL(urlString) }
    guard let redirectURL = URL(string: redirectString) else { throw SupabaseServiceError.invalidURL(redirectString) }

    return SupabaseConfig(url: url, anonKey: anonKey, redirectURL: redirectURL)
  }

  private static func readString(_ key: String, from bundle: Bundle) throws -> String {
    guard let raw = bundle.object(forInfoDictionaryKey: key) as? String else {
      throw SupabaseServiceError.missingInfoPlistValue(key)
    }
    let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if value.isEmpty { throw SupabaseServiceError.emptyValue(key) }
    return value
  }
}

final class SupabaseService {
  static let shared = SupabaseService()

  let client: SupabaseClient
  let redirectURL: URL

  private init() {
    do {
      let config = try SupabaseConfig.load()
      self.redirectURL = config.redirectURL
      self.client = SupabaseClient(
        supabaseURL: config.url,
        supabaseKey: config.anonKey
      )
    } catch {
      fatalError(String(describing: error))
    }
  }

  func currentUserId() -> UUID? {
    client.auth.currentSession?.user.id
  }

  func handleOpenURL(_ url: URL) {
    client.auth.handle(url)
  }

  func signInWithGoogle() async throws {
    _ = try await client.auth.signInWithOAuth(
      provider: .google,
      redirectTo: redirectURL
    )
  }

  func signInWithGoogle(redirectTo: URL?) async throws {
    _ = try await client.auth.signInWithOAuth(
      provider: .google,
      redirectTo: redirectTo ?? redirectURL
    )
  }

  func sendMagicLink(email: String) async throws {
    try await client.auth.signInWithOTP(
      email: email,
      redirectTo: redirectURL
    )
  }

  func sendMagicLink(email: String, redirectTo: URL?) async throws {
    try await client.auth.signInWithOTP(
      email: email,
      redirectTo: redirectTo ?? redirectURL
    )
  }

  func fetchOrCreateClientProfile(userId: UUID) async throws -> Profile {
    let existing: [Profile] = try await client
      .from("profiles")
      .select()
      .eq("id", value: userId)
      .limit(1)
      .execute()
      .value

    if let profile = existing.first {
      if profile.role != UserRole.client.rawValue { throw SupabaseServiceError.wrongRole }
      return profile
    }

    let inserted: Profile = try await client
      .from("profiles")
      .insert(ProfileInsert(id: userId, role: UserRole.client.rawValue, onboardingCompleted: false))
      .select()
      .single()
      .execute()
      .value

    return inserted
  }

  func fetchOrCreateClientProfile() async throws -> Profile {
    guard let userId = currentUserId() else { throw SupabaseServiceError.unauthenticated }
    return try await fetchOrCreateClientProfile(userId: userId)
  }

  func signOut() async throws {
    try await client.auth.signOut()
  }
}
