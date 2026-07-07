//
//  ClientQRCodeView.swift
//  Play'In
//
//  Created by Thibault Serdet on 22/04/2026.
//

import SwiftUI
import CoreImage.CIFilterBuiltins
import PassKit
import Supabase
import Functions

// MARK: - QR Code Generator

struct QRCodeGenerator {
  static func generate(from string: String, size: CGFloat = 300) -> UIImage? {
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()

    guard let data = string.data(using: .utf8) else { return nil }
    filter.setValue(data, forKey: "inputMessage")
    filter.setValue("M", forKey: "inputCorrectionLevel")

    guard let outputImage = filter.outputImage else { return nil }

    let scale = size / outputImage.extent.size.width
    let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

    guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
    return UIImage(cgImage: cgImage)
  }
}

// MARK: - Floating QR Button

struct ClientQRFloatingButton: View {
  @State private var showQRSheet = false
  let usablePromosCount: Int

  private let accent = Color.appYellow

  var body: some View {
    Button {
      showQRSheet = true
    } label: {
      ZStack {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(Color(white: 0.12))
          .frame(width: 52, height: 52)
          .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .strokeBorder(accent, lineWidth: 2)
          )
          .shadow(color: .black.opacity(0.35), radius: 10, y: 4)

        Image(systemName: "qrcode")
          .font(.system(size: 24, weight: .medium))
          .foregroundStyle(accent)
      }
    }
    .buttonStyle(.plain)
    .sheet(isPresented: $showQRSheet) {
      ClientQRCodeSheetView(usablePromosCount: usablePromosCount)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }
  }
}

// MARK: - QR Code Sheet

struct ClientQRCodeSheetView: View {
  let usablePromosCount: Int

  private let accent = Color.appYellow

  // Apple Wallet
  @State private var walletPass: PKPass?
  @State private var showAddPasses = false
  @State private var isLoadingPass = false
  @State private var walletError: String?

  var body: some View {
    ZStack {
      Color.appBackground.ignoresSafeArea()

      VStack(spacing: 24) {
        Spacer().frame(height: 8)

        VStack(spacing: 8) {
          Text("Scannez le QR code et\nprofitez des avantages")
            .font(.system(size: 22, weight: .heavy))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)

          Text("Faites scanner ce QR code par un complexe\npour profiter de vos promotions")
            .font(.system(size: 14))
            .foregroundStyle(.white.opacity(0.5))
            .multilineTextAlignment(.center)
        }

        // QR Code
        if let userId = SupabaseService.shared.currentUserId(),
           let img = QRCodeGenerator.generate(from: "playin:client:\(userId.uuidString)", size: 600) {
          Image(uiImage: img)
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .padding(20)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 40)
        } else {
          RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(white: 0.15))
            .frame(height: 280)
            .overlay {
              Text("QR indisponible")
                .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 40)
        }

        // Pill promos
        if usablePromosCount > 0 {
          Text("\(usablePromosCount) promotion\(usablePromosCount > 1 ? "s" : "") disponible\(usablePromosCount > 1 ? "s" : "")")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.black)
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(accent)
            .clipShape(Capsule())
        }

        // Apple Wallet
        if PKAddPassesViewController.canAddPasses() {
          ZStack {
            AddPassButtonView {
              Task { await loadWalletPass() }
            }
            .frame(width: 240, height: 48)
            .opacity(isLoadingPass ? 0.4 : 1)

            if isLoadingPass {
              ProgressView().tint(.white)
            }
          }
        }

        if let err = walletError {
          Text(err)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.red)
        }

        Spacer()
      }
    }
    .sheet(isPresented: $showAddPasses) {
      if let pass = walletPass {
        AddPassesControllerView(pass: pass)
          .ignoresSafeArea()
      }
    }
  }

  @MainActor
  private func loadWalletPass() async {
    guard !isLoadingPass else { return }
    isLoadingPass = true
    walletError = nil
    defer { isLoadingPass = false }
    do {
      let data: Data = try await SupabaseService.shared.client.functions
        .invoke("wallet-pass") { data, _ in data }
      walletPass = try PKPass(data: data)
      showAddPasses = true
    } catch {
      walletError = "Impossible de générer la carte Wallet."
    }
  }
}

// MARK: - PassKit wrappers

/// Bouton natif "Ajouter à Apple Wallet" (design officiel Apple).
private struct AddPassButtonView: UIViewRepresentable {
  let action: () -> Void

  func makeUIView(context: Context) -> PKAddPassButton {
    let button = PKAddPassButton(addPassButtonStyle: .black)
    button.addTarget(context.coordinator, action: #selector(Coordinator.tap), for: .touchUpInside)
    return button
  }

  func updateUIView(_ uiView: PKAddPassButton, context: Context) {}

  func makeCoordinator() -> Coordinator { Coordinator(action: action) }

  final class Coordinator: NSObject {
    let action: () -> Void
    init(action: @escaping () -> Void) { self.action = action }
    @objc func tap() { action() }
  }
}

/// Présente la feuille système d'ajout du pass à Wallet.
private struct AddPassesControllerView: UIViewControllerRepresentable {
  let pass: PKPass

  func makeUIViewController(context: Context) -> UIViewController {
    PKAddPassesViewController(pass: pass) ?? UIViewController()
  }

  func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
