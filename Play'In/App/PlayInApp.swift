//
//  PlayInApp.swift
//  Play'In
//
//  Created by Thibault Serdet on 22/02/2026.
//

import SwiftUI

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
    }
}

@main
struct PlayInApp: App {
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
