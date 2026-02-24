//
//  Profile.swift
//  Play'In
//
//  Created by Thibault Serdet on 22/02/2026.
//

import Foundation

struct Profile: Codable, Identifiable {
    let id: UUID
    let role: Int
    let createdAt: Date?
    let firstName: String?
    let lastName: String?
    let phone: String?
    let complexId: UUID?
    let roleVerified: Bool?
    let isAdmin: Bool?
    let onboardingCompleted: Bool?

    var userRole: UserRole {
        UserRole(rawValue: role) ?? .other
    }

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case createdAt = "created_at"
        case firstName = "first_name"
        case lastName = "last_name"
        case phone
        case complexId = "complex_id"
        case roleVerified = "role_verified"
        case isAdmin = "is_admin"
        case onboardingCompleted = "onboarding_completed"
    }
}

struct ProfileInsert: Codable {
    let id: UUID
    let role: Int
    let onboardingCompleted: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case onboardingCompleted = "onboarding_completed"
    }
}
