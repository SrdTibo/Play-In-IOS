//
//  PlayInApp.swift
//  Play'In
//
//  Created by Thibault Serdet on 22/02/2026.
//

import SwiftUI
import UIKit

// MARK: - AppDelegate (APNs token)

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        NotificationService.shared.handleToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[AppDelegate] Remote notification registration failed: \(error.localizedDescription)")
    }
}

// MARK: - Root view

struct AppRootView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        Group {
            if authViewModel.isLoading || authViewModel.route == .unknown {
                ProgressView()
            } else {
                switch authViewModel.route {
                case .signedOut:
                    AuthView()
                case .wrongRole:
                    WrongRoleView()
                case .onboarding:
                    OnboardingView()
                case .client:
                    ClientRootView()
                case .unknown:
                    ProgressView()
                }
            }
        }
        .onAppear {
            authViewModel.start()
        }
        .onChange(of: authViewModel.route) { _, newRoute in
            // Demande la permission push dès que l'utilisateur est un client vérifié
            if newRoute == .client {
                NotificationService.shared.requestPermission()
            }
        }
    }
}

// MARK: - App

@main
struct PlayInApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authViewModel = AuthViewModel(supabase: SupabaseService.shared)

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(authViewModel)
                .onOpenURL { url in
                    authViewModel.handleOpenURL(url)
                }
        }
    }
}
