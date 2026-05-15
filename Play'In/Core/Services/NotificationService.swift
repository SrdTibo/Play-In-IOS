//
//  NotificationService.swift
//  Play'In
//
//  Gère les permissions APNs, l'enregistrement du token,
//  et l'upload du token dans profiles.apns_token.
//

import Foundation
import UserNotifications
import UIKit

final class NotificationService {
  static let shared = NotificationService()
  private init() {}

  // MARK: - Permission

  /// Demande la permission push (alert + badge + son).
  /// À appeler dès que l'utilisateur est en route .client.
  func requestPermission() {
    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .badge, .sound]
    ) { granted, error in
      if let error {
        print("[NotificationService] Permission error: \(error.localizedDescription)")
        return
      }
      guard granted else { return }
      DispatchQueue.main.async {
        UIApplication.shared.registerForRemoteNotifications()
      }
    }
  }

  // MARK: - Token

  /// Appelé depuis AppDelegate.didRegisterForRemoteNotificationsWithDeviceToken.
  func handleToken(_ tokenData: Data) {
    let hex = tokenData.map { String(format: "%02x", $0) }.joined()
    Task { await saveToken(hex) }
  }

  private func saveToken(_ token: String) async {
    guard let userId = SupabaseService.shared.currentUserId() else { return }
    do {
      try await SupabaseService.shared.client
        .from("profiles")
        .update(["apns_token": token])
        .eq("id", value: userId)
        .execute()
    } catch {
      print("[NotificationService] Failed to save token: \(error.localizedDescription)")
    }
  }
}
