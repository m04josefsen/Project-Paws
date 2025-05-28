//
//  PetType.swift
//  Project Paws
//
//  Created by Marco Josefsen on 28/05/2025.
//

enum PetType: String, CaseIterable, Identifiable {
    case tortoise = "tortoise.fill"
    case bird = "bird.fill"
    case fish = "fish.fill"

    var id: String { self.rawValue }

    var friendlyName: String {
        switch self {
        case .tortoise: return "Tortoise"
        case .bird: return "Bird"
        case .fish: return "Fish"
        }
    }
}
