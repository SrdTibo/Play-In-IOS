//
//  ClientAccountPageView.swift
//  Play'In
//
//  Created by Thibault Serdet on 23/02/2026.
//

import SwiftUI
import Supabase
import PostgREST

struct ClientAccountProfileRow: Decodable {
  let firstName: String?
  let lastName: String?
  let phone: String?

  enum CodingKeys: String, CodingKey {
    case firstName = "first_name"
    case lastName = "last_name"
    case phone = "phone"
  }
}

struct ClientAccountProfileUpdate: Encodable {
  let firstName: String
  let lastName: String
  let phone: String?

  enum CodingKeys: String, CodingKey {
    case firstName = "first_name"
    case lastName = "last_name"
    case phone = "phone"
  }
}

struct ClientAccountPageView: View {
  @EnvironmentObject var authViewModel: AuthViewModel

  @State private var firstName: String = ""
  @State private var lastName: String = ""
  @State private var phone: String = ""
  @State private var email: String = ""

  @State private var isLoading: Bool = false
  @State private var isSaving: Bool = false
  @State private var errorMessage: String?

  var body: some View {
    NavigationStack {
      Form {
        Section("Profil") {
          TextField("Prénom", text: $firstName)
            .textContentType(.givenName)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()

          TextField("Nom", text: $lastName)
            .textContentType(.familyName)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()

          TextField("Téléphone", text: $phone)
            .keyboardType(.phonePad)
            .textContentType(.telephoneNumber)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

          TextField("Email", text: .constant(email))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .disabled(true)
        }

        if let message = errorMessage, !message.isEmpty {
          Section {
            Text(message)
              .foregroundStyle(.red)
              .font(.footnote)
          }
        }

        Section {
          Button("Enregistrer") {
            Task { await save() }
          }
          .disabled(isSaving || isLoading || firstNameTrimmed.isEmpty || lastNameTrimmed.isEmpty)

          Button("Se déconnecter") {
            authViewModel.signOut()
          }
          .foregroundStyle(.red)
        }
      }
      .navigationTitle("Compte")
      .disabled(isLoading)
      .overlay {
        if isLoading || isSaving {
          ProgressView()
        }
      }
      .task {
        await load()
      }
    }
  }

  private var firstNameTrimmed: String {
    firstName.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var lastNameTrimmed: String {
    lastName.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var phoneTrimmedOrNil: String? {
    let value = phone.trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? nil : value
  }

  @MainActor
  private func load() async {
    errorMessage = nil

    guard let userId = SupabaseService.shared.currentUserId() else {
      return
    }

    isLoading = true
    defer { isLoading = false }

    email = SupabaseService.shared.client.auth.currentSession?.user.email ?? ""

    do {
      let row: ClientAccountProfileRow = try await SupabaseService.shared.client
        .from("profiles")
        .select()
        .eq("id", value: userId)
        .single()
        .execute()
        .value

      firstName = row.firstName ?? ""
      lastName = row.lastName ?? ""
      phone = row.phone ?? ""
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  @MainActor
  private func save() async {
    errorMessage = nil

    if firstNameTrimmed.isEmpty || lastNameTrimmed.isEmpty {
      errorMessage = "Prénom et nom sont obligatoires."
      return
    }

    guard let userId = SupabaseService.shared.currentUserId() else {
      errorMessage = "Session expirée. Merci de vous reconnecter."
      return
    }

    isSaving = true
    defer { isSaving = false }

    do {
      _ = try await SupabaseService.shared.client
        .from("profiles")
        .update(
          ClientAccountProfileUpdate(
            firstName: firstNameTrimmed,
            lastName: lastNameTrimmed,
            phone: phoneTrimmedOrNil
          )
        )
        .eq("id", value: userId)
        .execute()

      await authViewModel.refresh()
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
