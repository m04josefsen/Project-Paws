//
//  PetState.swift
//  Project Paws
//
//  Created by Marco Josefsen on 28/05/2025.
//

import Foundation

// Defines the different states a pet can be in
enum PetState: String, CaseIterable {
    // Base idle states reflecting general disposition
    case idleNeutral
    case idleHappy
    case idleSad
    
    // Active states
    case sleeping
    case sitting
    case running
    case jumping
    
    // A helper to determine if the state is an "idle" variant
    var isIdleVariant: Bool {
        switch self {
        case .idleNeutral, .idleHappy, .idleSad:
            return true
        default:
            return false
        }
    }
}
