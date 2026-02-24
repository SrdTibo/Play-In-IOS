//
//  UserRole.swift
//  Play'In
//
//  Created by Thibault Serdet on 22/02/2026.
//

import Foundation

enum UserRole: Int, Codable {
    case gerant = 1
    case client = 2
    case other = -1

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(Int.self)
        self = UserRole(rawValue: value) ?? .other
    }
}
