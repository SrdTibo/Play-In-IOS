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
  let dateOfBirth: String
  let onboardingCompleted: Bool

  enum CodingKeys: String, CodingKey {
    case firstName        = "first_name"
    case lastName         = "last_name"
    case phone            = "phone"
    case dateOfBirth      = "date_of_birth"
    case onboardingCompleted = "onboarding_completed"
  }
}

struct OnboardingView: View {
  @EnvironmentObject var authViewModel: AuthViewModel

  @State private var firstName: String = ""
  @State private var lastName: String  = ""

  @State private var dateOfBirth: Date = Calendar.current.date(
    byAdding: .year, value: -18, to: Date()
  ) ?? Date()

  @State private var selectedCountryId: String = "FR"
  @State private var phone: String = ""

  @State private var isSubmitting: Bool    = false
  @State private var localErrorMessage: String?
  @State private var acceptedTerms: Bool   = false

  private let countries: [PhoneCountry] = [
    PhoneCountry(id: "FR", name: "France",       dialCode: "+33",  example: "06 12 34 56 78",    nationalMinDigits: 9,  nationalMaxDigits: 10),
    PhoneCountry(id: "BE", name: "Belgique",      dialCode: "+32",  example: "0470 12 34 56",      nationalMinDigits: 8,  nationalMaxDigits: 10),
    PhoneCountry(id: "CH", name: "Suisse",        dialCode: "+41",  example: "079 123 45 67",      nationalMinDigits: 9,  nationalMaxDigits: 10),
    PhoneCountry(id: "LU", name: "Luxembourg",    dialCode: "+352", example: "621 123 456",        nationalMinDigits: 8,  nationalMaxDigits: 11),
    PhoneCountry(id: "GB", name: "Royaume-Uni",   dialCode: "+44",  example: "07 1234 56789",      nationalMinDigits: 9,  nationalMaxDigits: 11),
    PhoneCountry(id: "US", name: "États-Unis",    dialCode: "+1",   example: "(201) 555-0123",     nationalMinDigits: 10, nationalMaxDigits: 10),
    PhoneCountry(id: "CA", name: "Canada",        dialCode: "+1",   example: "(416) 555-0123",     nationalMinDigits: 10, nationalMaxDigits: 10),
    PhoneCountry(id: "ES", name: "Espagne",       dialCode: "+34",  example: "612 34 56 78",       nationalMinDigits: 9,  nationalMaxDigits: 9),
    PhoneCountry(id: "IT", name: "Italie",        dialCode: "+39",  example: "312 345 6789",       nationalMinDigits: 9,  nationalMaxDigits: 11),
    PhoneCountry(id: "DE", name: "Allemagne",     dialCode: "+49",  example: "0151 23456789",      nationalMinDigits: 10, nationalMaxDigits: 13),
    PhoneCountry(id: "NL", name: "Pays-Bas",      dialCode: "+31",  example: "06 12345678",        nationalMinDigits: 9,  nationalMaxDigits: 10),
    PhoneCountry(id: "PT", name: "Portugal",      dialCode: "+351", example: "912 345 678",        nationalMinDigits: 9,  nationalMaxDigits: 9),
  ]

  // ── Body ──────────────────────────────────────────────────────────────────

  var body: some View {
    ZStack {
      AuthBackground()

      VStack(spacing: 0) {

        // ── Header ──────────────────────────────────────────────────────
        VStack(spacing: 6) {
          Text("Crée ton profil")
            .font(.system(size: 28, weight: .black))
            .foregroundStyle(.white)
          Text("Quelques infos pour personnaliser\nton expérience Play'In")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white.opacity(0.45))
            .multilineTextAlignment(.center)
        }
        .padding(.top, 64)
        .padding(.horizontal, 24)

        // ── Formulaire ──────────────────────────────────────────────────
        ScrollView(showsIndicators: false) {
          VStack(spacing: 14) {

            // Prénom + Nom côte à côte
            HStack(spacing: 10) {
              TextField("Prénom", text: $firstName)
                .textContentType(.givenName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .piInputStyle()

              TextField("Nom", text: $lastName)
                .textContentType(.familyName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .piInputStyle()
            }

            // Date de naissance
            VStack(alignment: .leading, spacing: 6) {
              Text("Date de naissance")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))

              DatePicker(
                "",
                selection: $dateOfBirth,
                in: ...Calendar.current.date(byAdding: .year, value: -5, to: Date())!,
                displayedComponents: .date
              )
              .labelsHidden()
              .datePickerStyle(.compact)
              .environment(\.locale, Locale(identifier: "fr_FR"))
              .tint(Color.appYellow)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.horizontal, 14)
              .padding(.vertical, 13)
              .background(Color.white.opacity(0.07))
              .clipShape(RoundedRectangle(cornerRadius: 12))
              .overlay(
                RoundedRectangle(cornerRadius: 12)
                  .stroke(Color.white.opacity(0.12), lineWidth: 1)
              )
            }

            // Téléphone
            VStack(alignment: .leading, spacing: 6) {
              Text("Téléphone (optionnel)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))

              HStack(spacing: 8) {
                // Sélecteur de pays
                Menu {
                  ForEach(countries) { country in
                    Button { selectedCountryId = country.id } label: {
                      Text("\(country.name) \(country.dialCode)")
                    }
                  }
                } label: {
                  HStack(spacing: 6) {
                    Text(selectedCountry.dialCode)
                      .font(.system(size: 15, weight: .semibold))
                      .foregroundStyle(.white)
                    Image(systemName: "chevron.down")
                      .font(.system(size: 11, weight: .semibold))
                      .foregroundStyle(.white.opacity(0.45))
                  }
                  .padding(.horizontal, 12)
                  .padding(.vertical, 15)
                  .background(Color.white.opacity(0.07))
                  .clipShape(RoundedRectangle(cornerRadius: 12))
                  .overlay(
                    RoundedRectangle(cornerRadius: 12)
                      .stroke(Color.white.opacity(0.12), lineWidth: 1)
                  )
                }

                TextField("Numéro", text: $phone)
                  .keyboardType(.phonePad)
                  .textContentType(.telephoneNumber)
                  .textInputAutocapitalization(.never)
                  .autocorrectionDisabled()
                  .piInputStyle()
              }

              // Hint / erreur téléphone
              if let phoneError = phoneValidationError, !phoneError.isEmpty {
                PIErrorRow(message: phoneError)
              } else {
                Text("Exemple : \(selectedCountry.example)")
                  .font(.system(size: 12, weight: .medium))
                  .foregroundStyle(.white.opacity(0.3))
              }
            }

            // Erreur globale
            if let message = localErrorMessage, !message.isEmpty {
              PIErrorRow(message: message)
            }

            // Acceptation des CGU
            Button {
              acceptedTerms.toggle()
            } label: {
              HStack(alignment: .top, spacing: 10) {
                ZStack {
                  RoundedRectangle(cornerRadius: 6)
                    .stroke(acceptedTerms ? Color.appYellow : Color.white.opacity(0.25), lineWidth: 1.5)
                    .frame(width: 20, height: 20)
                  if acceptedTerms {
                    RoundedRectangle(cornerRadius: 6)
                      .fill(Color.appYellow)
                      .frame(width: 20, height: 20)
                    Image(systemName: "checkmark")
                      .font(.system(size: 11, weight: .black))
                      .foregroundStyle(Color.appDark)
                  }
                }
                .padding(.top, 1)

                Group {
                  Text("J'accepte les ")
                    .foregroundStyle(.white.opacity(0.6))
                  + Text("Conditions d'utilisation")
                    .foregroundStyle(Color.appYellow)
                    .underline()
                  + Text(" et la ")
                    .foregroundStyle(.white.opacity(0.6))
                  + Text("Politique de confidentialité")
                    .foregroundStyle(Color.appYellow)
                    .underline()
                  + Text(" de Play'In.")
                    .foregroundStyle(.white.opacity(0.6))
                }
                .font(.system(size: 13, weight: .medium))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
              }
            }
            .buttonStyle(.plain)
          }
          .padding(.horizontal, 24)
          .padding(.top, 28)
          .padding(.bottom, 20)
        }

        // ── Boutons fixes ────────────────────────────────────────────────
        VStack(spacing: 10) {
          PIActionButton(
            title: isSubmitting ? "Enregistrement…" : "Terminer",
            style: .primary,
            disabled: isSubmitting || firstNameTrimmed.isEmpty || lastNameTrimmed.isEmpty || phoneValidationError != nil || !acceptedTerms
          ) {
            Task { await submit() }
          }

          Button { authViewModel.signOut() } label: {
            Text("Se déconnecter")
              .font(.system(size: 14, weight: .semibold))
              .foregroundStyle(.white.opacity(0.35))
          }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 44)
      }

      if isSubmitting {
        PILoadingOverlay()
      }
    }
    .preferredColorScheme(.dark)
  }

  // ── Computed ──────────────────────────────────────────────────────────────

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
    if raw.contains("+") { return normalizeToE164FromE164Input(raw) }
    let nationalDigits = digitsOnly(raw)
    if nationalDigits.isEmpty { return nil }
    let normalizedNational = dropLeadingZeroIfNeeded(nationalDigits)
    return selectedCountry.dialCode + normalizedNational
  }

  private var phoneValidationError: String? {
    let raw = phoneTrimmed
    if raw.isEmpty { return nil }

    if raw.contains("+") {
      if normalizeToE164FromE164Input(raw) == nil {
        return "Numéro invalide. Exemple : \(selectedCountry.dialCode)..."
      }
      return nil
    }

    let nationalDigits = digitsOnly(raw)
    if nationalDigits.isEmpty { return "Numéro invalide." }

    let normalizedNational = dropLeadingZeroIfNeeded(nationalDigits)
    if normalizedNational.count < selectedCountry.nationalMinDigits ||
       normalizedNational.count > selectedCountry.nationalMaxDigits {
      return "Format invalide pour \(selectedCountry.name). Exemple : \(selectedCountry.example)"
    }

    let e164 = selectedCountry.dialCode + normalizedNational
    if !isValidE164(e164) { return "Numéro invalide. Exemple : \(selectedCountry.dialCode)..." }
    return nil
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  private func digitsOnly(_ value: String) -> String {
    value.filter { $0.isNumber }
  }

  private func dropLeadingZeroIfNeeded(_ digits: String) -> String {
    digits.hasPrefix("0") && digits.count > 1 ? String(digits.dropFirst()) : digits
  }

  private func normalizeToE164FromE164Input(_ raw: String) -> String? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.hasPrefix("+") else { return nil }
    let e164 = "+" + digitsOnly(trimmed)
    return isValidE164(e164) ? e164 : nil
  }

  private func isValidE164(_ value: String) -> Bool {
    guard value.hasPrefix("+") else { return false }
    let digits = digitsOnly(value)
    return digits.count >= 8 && digits.count <= 15
  }

  // ── Submit ────────────────────────────────────────────────────────────────

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

    let isoFormatter = DateFormatter()
    isoFormatter.dateFormat = "yyyy-MM-dd"
    let dobString = isoFormatter.string(from: dateOfBirth)

    do {
      _ = try await SupabaseService.shared.client
        .from("profiles")
        .update(
          OnboardingProfileUpdate(
            firstName: firstNameTrimmed,
            lastName: lastNameTrimmed,
            phone: phoneE164OrNil,
            dateOfBirth: dobString,
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
