//
//  Constants.swift
//  Project Paws
//
//  Created by Marco Josefsen on 28/05/2025.
//

import Foundation
import CoreGraphics

// TODO: prev 40 width
let PET_WINDOW_SIZE = CGSize(width: 275, height: 40)

let VERTICAL_OFFSET_FROM_SCREEN_TOP: CGFloat = -7
// TODO: prev was -130
let HORIZONTAL_OFFSET_FOR_PET_CENTER: CGFloat = 0

// Walking parameters for patrol
let PATROL_MAX_X_OFFSET: CGFloat = 115.0
let PET_WALK_SPEED: CGFloat = 0.5
let PET_WALK_STEP_INTERVAL: TimeInterval = 0.01

// TODO: change these, short for debugging
// Timer for deciding when to walk
let MIN_TIME_UNTIL_NEXT_WALK_DECISION: TimeInterval = 8.0
let MAX_TIME_UNTIL_NEXT_WALK_DECISION: TimeInterval = 20.0
