//
//  ClientQRCodeView.swift
//  Play'In
//
//  Created by Thibault Serdet on 22/04/2026.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

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
        Circle()
          .fill(Color(white: 0.12))
          .frame(width: 56, height: 56)
          .overlay(
            Circle().strokeBorder(accent, lineWidth: 2)
          )
          .shadow(color: .black.opacity(0.35), radius: 10, y: 4)

        qrMiniPreview
          .frame(width: 26, height: 26)
          .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
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

  @ViewBuilder
  private var qrMiniPreview: some View {
    if let userId = SupabaseService.shared.currentUserId(),
       let img = QRCodeGenerator.generate(from: "playin:client:\(userId.uuidString)", size: 100) {
      Image(uiImage: img)
        .interpolation(.none)
        .resizable()
        .scaledToFit()
        .colorInvert()
        .colorMultiply(accent)
    } else {
      Image(systemName: "qrcode")
        .font(.system(size: 22, weight: .medium))
        .foregroundStyle(accent)
    }
  }
}

// MARK: - QR Code Sheet

struct ClientQRCodeSheetView: View {
  let usablePromosCount: Int

  private let accent = Color.appYellow

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

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

        Spacer()
      }
    }
  }
}
