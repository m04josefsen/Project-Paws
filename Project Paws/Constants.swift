//
//  Constants.swift
//  Project Paws
//
//  Created by Marco Josefsen on 28/05/2025.
//

import Foundation
import CoreGraphics

let PET_WINDOW_SIZE = CGSize(width: 40, height: 40) // Your working value

// Position of pet window
let VERTICAL_OFFSET_FROM_SCREEN_TOP: CGFloat = -7 // Your working value
let HORIZONTAL_OFFSET_FOR_PET_CENTER: CGFloat = -130 // Your working value

// Walking parameters
let PET_WALK_DISTANCE_X: CGFloat = 15 // How far (in points) the pet walks left or right from its window's center
let PET_WALK_SPEED: CGFloat = 0.5      // Points to move per animation step during walk
let PET_WALK_STEP_INTERVAL: TimeInterval = 0.05 // How often position updates during walk (e.g., 20fps)

// Timer for deciding when to walk
let MIN_TIME_UNTIL_NEXT_WALK_DECISION: TimeInterval = 8.0  // Min seconds to wait before considering a walk
let MAX_TIME_UNTIL_NEXT_WALK_DECISION: TimeInterval = 20.0 //
