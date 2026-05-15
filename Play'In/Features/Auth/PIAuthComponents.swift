//
//  PIAuthComponents.swift
//  Play'In
//
//  Composants partagés pour les vues d'authentification et d'onboarding.
//

import SwiftUI

// MARK: - Background

struct AuthBackground: View {
  var body: some View {
    Color.black.ignoresSafeArea()
  }
}

// MARK: - Brand mark

struct PlayInBrandMark: View {
  var body: some View {
    VStack(spacing: 14) {
      Image("PlayInLogo")
        .resizable()
        .scaledToFit()
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 16))
      VStack(spacing: 5) {
        Text("Play'In")
          .font(.system(size: 36, weight: .black))
          .foregroundStyle(.white)
        Text("SCANNE · JOUE · PROFITE")
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(.white.opacity(0.35))
          .tracking(2)
      }
    }
  }
}

// MARK: - Input style

extension View {
  func piInputStyle() -> some View {
    self
      .font(.system(size: 15, weight: .medium))
      .padding(.horizontal, 14)
      .padding(.vertical, 15)
      .background(Color.white.opacity(0.07))
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color.white.opacity(0.12), lineWidth: 1)
      )
  }
}

// MARK: - Button

enum PIButtonVariant { case primary, outlined, ghost }

struct PIActionButton: View {
  let title: String
  let style: PIButtonVariant
  var disabled: Bool = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.system(size: 15, weight: .bold))
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .foregroundStyle(textColor)
        .background(bgColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(strokeColor, lineWidth: 1)
        )
    }
    .disabled(disabled)
    .opacity(disabled ? 0.4 : 1)
  }

  private var textColor: Color {
    switch style {
    case .primary:           return Color.appDark
    case .outlined, .ghost:  return .white
    }
  }

  private var bgColor: Color {
    switch style {
    case .primary:  return Color.appYellow
    case .outlined: return Color.white.opacity(0.08)
    case .ghost:    return Color.clear
    }
  }

  private var strokeColor: Color {
    switch style {
    case .primary:  return Color.clear
    case .outlined: return Color.white.opacity(0.18)
    case .ghost:    return Color.white.opacity(0.2)
    }
  }
}

// MARK: - "ou" separator

struct PIOrSeparator: View {
  var body: some View {
    HStack(spacing: 12) {
      Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
      Text("ou")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.white.opacity(0.3))
      Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
    }
  }
}

// MARK: - Loading overlay

struct PILoadingOverlay: View {
  var body: some View {
    ZStack {
      Color.black.opacity(0.5).ignoresSafeArea()
      ProgressView()
        .tint(Color.appYellow)
        .scaleEffect(1.5)
    }
  }
}

// MARK: - Error row

struct PIErrorRow: View {
  let message: String

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: "exclamationmark.circle.fill")
        .font(.system(size: 13))
      Text(message)
        .font(.system(size: 13, weight: .medium))
    }
    .foregroundStyle(Color(red: 1.0, green: 0.42, blue: 0.42))
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
