//
//  PetViewModel.swift
//  Project Paws
//
//  Created by Marco Josefsen on 28/05/2025.
//

import Foundation
import Combine
import CoreGraphics

// The "brain" for your pet, holds the pet's current state, manages its logic, and handles interactions
class PetViewModel: ObservableObject {
    @Published var currentPetType: PetType = .cat
    @Published var currentState: PetState = .idleNeutral
    @Published var positionOffset: CGPoint = .zero
    @Published var currentXScale: CGFloat = 1.0   // For flipping sprite: 1.0 = normal, -1.0 = flipped

    var happinessScore: Int = 50
    private var lastInteractionTime: Date = Date()

    private var inactivityTimer: Timer?
    private var temporaryStateTimer: Timer?

    private var walkDecisionTimer: Timer?
    private var walkStepTimer: Timer?
    private var isWalkingCurrently: Bool = false
    private var walkTargetOffsetX: CGFloat = 0
    private var currentWalkDirection: CGFloat = 1.0

    init() {
        NSLog("DEBUG-NSLog: PetViewModel init - STARTING")
        startTimers()
        scheduleNextWalkDecision()
        NSLog("DEBUG-NSLog: PetViewModel init - FINISHED")
    }

    func changePet(to type: PetType) {
        if currentPetType == type { return }
        let oldType = currentPetType
        stopWalking()
        currentPetType = type
        NSLog("PetViewModel: currentPetType changed from \(oldType.friendlyName) to \(currentPetType.friendlyName)")
        resetPetState()
    }

    private func determineBaseStateFromHappiness() -> PetState {
        if happinessScore > 70 {
            return .idleHappy
        } else if happinessScore > 30 {
            return .idleNeutral
        } else {
            return .idleSad
        }
    }
    
    // TODO: Change hapiness score
    func petInteracted() {
        lastInteractionTime = Date()
        happinessScore = min(100, happinessScore + 20)
        
        // TODO: change temporar state?
        enterTemporaryState(.sitting, duration: 1.5) // Example: pet sits happily
        // Alternatively: enterTemporaryState(determineBaseStateFromHappiness(), duration: 1.5)
        resetInactivityTimer()
        scheduleNextWalkDecision()
        objectWillChange.send() // Ensure UI updates if state changes
    }

    // Called from AppDelegate menu, commented out due to buttion removed
    /*
    func feedPet() {
        stopWalking()
        lastInteractionTime = Date()
        happinessScore = min(100, happinessScore + 30)

        enterTemporaryState(.idleHappy, duration: 2.0)
        resetInactivityTimer()
        scheduleNextWalkDecision()
        objectWillChange.send()
    }
     */
    
    private func enterTemporaryState(_ state: PetState, duration: TimeInterval) {
        temporaryStateTimer?.invalidate()
        stopWalking(andResetPosition: false)
        currentState = state
        
        NSLog("PetViewModel: Entering temporary state '\(state.rawValue)' for \(duration)s")
        
        temporaryStateTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            guard let self = self else { return }

            if self.currentState == state {
                NSLog("PetViewModel: Temporary state '\(state.rawValue)' ended. Reverting to base state.")
                self.currentState = self.determineBaseStateFromHappiness()
            } else {
                NSLog("PetViewModel: Temporary state timer fired for '\(state.rawValue)', but current state is now '\(self.currentState.rawValue)'. No reversion.")
            }
            self.scheduleNextWalkDecision()
        }
    }

    private func startTimers() {
        resetInactivityTimer()
    }
    
    private func resetInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            self?.handleInactivity()
        }
    }

    private func handleInactivity() {
        if temporaryStateTimer?.isValid ?? false {
            NSLog("PetViewModel: handleInactivity - bailing due to active temporaryStateTimer.")
            return
        }

        if currentState == .sleeping {
            NSLog("PetViewModel: handleInactivity - pet is already sleeping.")
            return
        }

        let timeSinceLastInteraction = Date().timeIntervalSince(lastInteractionTime)

        if timeSinceLastInteraction > 15.0 {
            let previousHappiness = happinessScore
            happinessScore = max(0, happinessScore - 2)
            if happinessScore != previousHappiness {
                NSLog("PetViewModel: handleInactivity - Happiness degraded to \(happinessScore) due to user inactivity.")
            }
        }

        if !isWalkingCurrently {
            if timeSinceLastInteraction > 75.0 && currentState.isIdleVariant {
                if currentState != .sleeping {
                    NSLog("PetViewModel: handleInactivity - Pet going to sleep due to long user inactivity (current state: \(currentState.rawValue)).")
                    currentState = .sleeping
                }
            }
            else if currentState.isIdleVariant {
                let newIdealIdleState = determineBaseStateFromHappiness()
                if currentState != newIdealIdleState {
                    NSLog("PetViewModel: handleInactivity - Updating idle state from \(currentState.rawValue) to \(newIdealIdleState.rawValue) based on happiness \(happinessScore).")
                    currentState = newIdealIdleState
                }
            }
        } else {
            NSLog("PetViewModel: handleInactivity - Pet is currently walking (state: \(currentState.rawValue)). Happiness check done; no state change from inactivity.")
        }
    }
    

    // --- Walking Logic Implementation ---

    private func scheduleNextWalkDecision() {
        walkDecisionTimer?.invalidate() // Invalidate existing timer
        let randomInterval = TimeInterval.random(in: MIN_TIME_UNTIL_NEXT_WALK_DECISION...MAX_TIME_UNTIL_NEXT_WALK_DECISION)
        NSLog("PetViewModel: Scheduling next walk decision in \(String(format: "%.1f", randomInterval))s")
        walkDecisionTimer = Timer.scheduledTimer(withTimeInterval: randomInterval, repeats: false) { [weak self] _ in
            self?.decideToWalk()
        }
    }

    // TODO: make private, public for testing purposes
    func decideToWalk() {
        guard !isWalkingCurrently, currentState.isIdleVariant else {
            scheduleNextWalkDecision()
            return
        }

        if Bool.random() {
            NSLog("PetViewModel: Decided to walk.")
            if positionOffset.x >= PET_WALK_DISTANCE_X - 1 {
                currentWalkDirection = -1.0
            } else if positionOffset.x <= -PET_WALK_DISTANCE_X + 1 {
                currentWalkDirection = 1.0
            } else {
                currentWalkDirection = Bool.random() ? 1.0 : -1.0
            }
            
            walkTargetOffsetX = currentWalkDirection * PET_WALK_DISTANCE_X
            
            // Start walking
            isWalkingCurrently = true
            currentState = .running
            currentXScale = currentWalkDirection
            startWalkAnimation()
        } else {
            NSLog("PetViewModel: Decided to stay idle.")
            scheduleNextWalkDecision()
        }
    }

    private func startWalkAnimation() {
        walkStepTimer?.invalidate()
        walkStepTimer = Timer.scheduledTimer(withTimeInterval: PET_WALK_STEP_INTERVAL, repeats: true) { [weak self] _ in
            self?.performWalkStep()
        }
    }

    private func performWalkStep() {
        guard isWalkingCurrently else {
            stopWalking()
            return
        }

        var newX = positionOffset.x + (currentWalkDirection * PET_WALK_SPEED)

        // Check if target is reached or passed
        let reachedTarget: Bool
        if currentWalkDirection > 0 { // Moving right
            reachedTarget = newX >= walkTargetOffsetX
        } else { // Moving left
            reachedTarget = newX <= walkTargetOffsetX
        }

        if reachedTarget {
            newX = walkTargetOffsetX // Snap to target
            positionOffset.x = newX
            stopWalking()
        } else {
            positionOffset.x = newX
        }
        // @Published positionOffset will trigger view update
    }

    private func stopWalking(andResetPosition: Bool = false) {
        walkStepTimer?.invalidate()
        walkStepTimer = nil
        if isWalkingCurrently { // Only change state if it was actually walking
            currentState = determineBaseStateFromHappiness()
        }
        isWalkingCurrently = false
        // currentXScale remains as is, will be set by next walk
        
        if andResetPosition {
             positionOffset.x = 0 // Optionally reset to center after a walk segment
        }
        
        // Schedule the next decision to walk or stay idle
        scheduleNextWalkDecision()
    }

    // --- End Walking Logic ---

    func resetPetState() {
        happinessScore = 50
        lastInteractionTime = Date()
        stopWalking(andResetPosition: true)
        currentState = .idleNeutral
        positionOffset = .zero
        currentXScale = 1.0
        temporaryStateTimer?.invalidate()
        startTimers()
        scheduleNextWalkDecision()
        objectWillChange.send()
    }

    public func performCleanup() {
        inactivityTimer?.invalidate()
        temporaryStateTimer?.invalidate()
        walkDecisionTimer?.invalidate()
        walkStepTimer?.invalidate()
    }

    deinit {
        performCleanup()
    }
}
