//
//  Constants.swift
//  Project Paws
//
//  Created by Marco Josefsen on 28/05/2025.
//

import Foundation
import CoreGraphics

// TODO: prev 40 width
let PET_WINDOW_SIZE = CGSize(width: 250, height: 40)

let VERTICAL_OFFSET_FROM_SCREEN_TOP: CGFloat = -7
// TODO: prev was -130
let HORIZONTAL_OFFSET_FOR_PET_CENTER: CGFloat = 0

// Walking parameters for patrol
// This is the distance from the PetWindow's center (positionOffset.x = 0) to the patrol points.
// Pet will walk between -PATROL_MAX_X_OFFSET and +PATROL_MAX_X_OFFSET.
// With window width 250, and pet sprite width ~30-38 (if using maxDisplayFactor ~0.7-0.8 on a 40px original sprite height),
// an offset of around 100 gives good travel distance within the window.
// (250/2) - (sprite_width/2) = 125 - (approx 15 to 19) = ~106 to ~110. So 100 is safe.
let PATROL_MAX_X_OFFSET: CGFloat = 100.0
let PET_WALK_SPEED: CGFloat = 0.5
let PET_WALK_STEP_INTERVAL: TimeInterval = 0.05

// TODO: change these, short for debugging
// Timer for deciding when to walk
let MIN_TIME_UNTIL_NEXT_WALK_DECISION: TimeInterval = 8.0
let MAX_TIME_UNTIL_NEXT_WALK_DECISION: TimeInterval = 20.0
