//
//  OnboardingView.swift
//  Play'In
//
//  Created by Thibault Serdet on 22/02/2026.
//

import SwiftUI
import Supabase
import PostgREST

struct PhoneCountry: Identifiable, Hashable {
  let id: String
  let name: String
  let dialCode: String
  let example: String
  let nationalMinDigits: Int
  let nationalMaxDigits: Int
}

struct OnboardingProfileUpdate: Encodable {
  let firstName: String
  let lastName: String
  let phone: String?
  let onboardingCompleted: Bool

  enum CodingKeys: String, CodingKey {
    case firstName = "first_name"
    case lastName = "last_name"
    case phone = "phone"
    case onboardingCompleted = "onboarding_completed"
  }
}

struct OnboardingView: View {
  @EnvironmentObject var authViewModel: AuthViewModel

  @State private var firstName: String = ""
  @State private var lastName: String = ""

  @State private var selectedCountryId: String = "FR"
  @State private var phone: String = ""

  @State private var isSubmitting: Bool = false
  @State private var localErrorMessage: String?

  private let countries: [PhoneCountry] = [
    PhoneCountry(id: "FR", name: "France", dialCode: "+33", example: "06 12 34 56 78", nationalMinDigits: 9, nationalMaxDigits: 10),
    PhoneCountry(id: "BE", name: "Belgique", dialCode: "+32", example: "0470 12 34 56", nationalMinDigits: 8, nationalMaxDigits: 10),
    PhoneCountry(id: "CH", name: "Suisse", dialCode: "+41", example: "079 123 45 67", nationalMinDigits: 9, nationalMaxDigits: 10),
    PhoneCountry(id: "LU", name: "Luxembourg", dialCode: "+352", example: "621 123 456", nationalMinDigits: 8, nationalMaxDigits: 11),
    PhoneCountry(id: "GB", name: "Royaume-Uni", dialCode: "+44", example: "07 1234 56789", nationalMinDigits: 9, nationalMaxDigits: 11),
    PhoneCountry(id: "US", name: "États-Unis", dialCode: "+1", example: "(201) 555-0123", nationalMinDigits: 10, nationalMaxDigits: 10),
    PhoneCountry(id: "CA", name: "Canada", dialCode: "+1", example: "(416) 555-0123", nationalMinDigits: 10, nationalMaxDigits: 10),
    PhoneCountry(id: "ES", name: "Espagne", dialCode: "+34", example: "612 34 56 78", nationalMinDigits: 9, nationalMaxDigits: 9),
    PhoneCountry(id: "IT", name: "Italie", dialCode: "+39", example: "312 345 6789", nationalMinDigits: 9, nationalMaxDigits: 11),
    PhoneCountry(id: "DE", name: "Allemagne", dialCode: "+49", example: "0151 23456789", nationalMinDigits: 10, nationalMaxDigits: 13),
    PhoneCountry(id: "NL", name: "Pays-Bas", dialCode: "+31", example: "06 12345678", nationalMinDigits: 9, nationalMaxDigits: 10),
    PhoneCountry(id: "PT", name: "Portugal", dialCode: "+351", example: "912 345 678", nationalMinDigits: 9, nationalMaxDigits: 9)
  ]

  var body: some View {
    ZStack {
      VStack(spacing: 16) {
        Spacer()

        Text("Onboarding")
          .font(.title2)
          .fontWeight(.semibold)

        VStack(spacing: 12) {
          TextField("Prénom", text: $firstName)
            .textContentType(.givenName)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .padding(12)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

          TextField("Nom", text: $lastName)
            .textContentType(.familyName)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .padding(12)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

          VStack(spacing: 8) {
            HStack(spacing: 12) {
              Picker("Pays", selection: $selectedCountryId) {
                ForEach(countries) { country in
                  Text("\(country.name) \(country.dialCode)").tag(country.id)
                }
              }
              .pickerStyle(.menu)

              TextField("Téléphone", text: $phone)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Text("Exemple : \(selectedCountry.example)")
              .font(.footnote)
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)

            if let phoneError = phoneValidationError, !phoneError.isEmpty {
              Text(phoneError)
                .font(.footnote)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
          }

          if let message = localErrorMessage, !message.isEmpty {
            Text(message)
              .font(.footnote)
              .foregroundStyle(.red)
              .frame(maxWidth: .infinity, alignment: .leading)
          }

          Button {
            Task { await submit() }
          } label: {
            Text("Terminer")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .disabled(isSubmitting || firstNameTrimmed.isEmpty || lastNameTrimmed.isEmpty || phoneValidationError != nil)

          Button {
            authViewModel.signOut()
          } label: {
            Text("Se déconnecter")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
        }

        Spacer()
      }
      .padding()

      if isSubmitting {
        Color.black.opacity(0.2)
          .ignoresSafeArea()
        ProgressView()
      }
    }
  }

  private var selectedCountry: PhoneCountry {
    countries.first(where: { $0.id == selectedCountryId }) ?? countries[0]
  }

  private var firstNameTrimmed: String {
    firstName.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var lastNameTrimmed: String {
    lastName.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var phoneTrimmed: String {
    phone.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var phoneE164OrNil: String? {
    let raw = phoneTrimmed
    if raw.isEmpty { return nil }

    if raw.contains("+") {
      let e164 = normalizeToE164FromE164Input(raw)
      return e164
    }

    let nationalDigits = digitsOnly(raw)
    if nationalDigits.isEmpty { return nil }

    let normalizedNational = dropLeadingZeroIfNeeded(nationalDigits)
    return selectedCountry.dialCode + normalizedNational
  }

  private var phoneValidationError: String? {
    let raw = phoneTrimmed
    if raw.isEmpty { return nil }

    if raw.contains("+") {
      let e164 = normalizeToE164FromE164Input(raw)
      if e164 == nil { return "Numéro invalide. Exemple : \(selectedCountry.dialCode)..." }
      return nil
    }

    let nationalDigits = digitsOnly(raw)
    if nationalDigits.isEmpty { return "Numéro invalide." }

    let normalizedNational = dropLeadingZeroIfNeeded(nationalDigits)
    if normalizedNational.count < selectedCountry.nationalMinDigits || normalizedNational.count > selectedCountry.nationalMaxDigits {
      return "Format invalide pour \(selectedCountry.name). Exemple : \(selectedCountry.example)"
    }

    let e164 = selectedCountry.dialCode + normalizedNational
    if !isValidE164(e164) { return "Numéro invalide. Exemple : \(selectedCountry.dialCode)..." }
    return nil
  }

  private func digitsOnly(_ value: String) -> String {
    value.filter { $0.isNumber }
  }

  private func dropLeadingZeroIfNeeded(_ digits: String) -> String {
    if digits.hasPrefix("0"), digits.count > 1 {
      return String(digits.dropFirst())
    }
    return digits
  }

  private func normalizeToE164FromE164Input(_ raw: String) -> String? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.hasPrefix("+") { return nil }
    let digits = digitsOnly(trimmed)
    let e164 = "+" + digits
    return isValidE164(e164) ? e164 : nil
  }

  private func isValidE164(_ value: String) -> Bool {
    guard value.hasPrefix("+") else { return false }
    let digits = digitsOnly(value)
    if digits.count < 8 || digits.count > 15 { return false }
    return true
  }

  @MainActor
  private func submit() async {
    localErrorMessage = nil

    if firstNameTrimmed.isEmpty || lastNameTrimmed.isEmpty {
      localErrorMessage = "Prénom et nom sont obligatoires."
      return
    }

    if phoneValidationError != nil {
      localErrorMessage = "Merci de corriger le numéro de téléphone."
      return
    }

    guard let userId = SupabaseService.shared.currentUserId() else {
      localErrorMessage = "Session expirée. Merci de vous reconnecter."
      return
    }

    isSubmitting = true
    defer { isSubmitting = false }

    do {
      _ = try await SupabaseService.shared.client
        .from("profiles")
        .update(
          OnboardingProfileUpdate(
            firstName: firstNameTrimmed,
            lastName: lastNameTrimmed,
            phone: phoneE164OrNil,
            onboardingCompleted: true
          )
        )
        .eq("id", value: userId)
        .execute()

      await authViewModel.refresh()
    } catch {
      localErrorMessage = error.localizedDescription
    }
  }
}
