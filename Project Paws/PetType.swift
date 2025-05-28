//
//  PetType.swift
//  Project Paws
//
//  Created by Marco Josefsen on 28/05/2025.
//

enum PetType: String, CaseIterable, Identifiable {
    case cat = "cat"
    case dog = "dog"
    case bunny = "bunny"

    var id: String { self.rawValue }

    var friendlyName: String {
        switch self {
        case .cat: return "Cat"
        case .dog: return "Dog"
        case .bunny: return "Bunny"
        }
    }
}
