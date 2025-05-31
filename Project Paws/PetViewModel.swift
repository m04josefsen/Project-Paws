//
//  PetViewModel.swift
//  Project Paws
//
//  Created by Marco Josefsen on 28/05/2025.
//

import Foundation
import Combine
import CoreGraphics

class PetViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var currentPetType: PetType = .cat
    @Published var currentState: PetState = .idleNeutral
    @Published var positionOffset: CGPoint = .zero
    @Published var currentXScale: CGFloat = 1.0
    @Published var happinessScore: Int = 50

    // MARK: - Private Properties
    private var lastInteractionTime: Date = Date()

    // Timers
    private var inactivityTimer: Timer?
    private var temporaryStateTimer: Timer?
    private var walkDecisionTimer: Timer?
    private var walkStepTimer: Timer?

    // Walking state
    private var isWalkingCurrently: Bool = false
    private var isPetAtLeftExtreme: Bool = true // Tracks if pet is at its leftmost patrol point. True = at left, next walk is right.
    private var internalWalkTargetX: CGFloat = 0
    private var internalWalkDirection: CGFloat = 1.0

    // MARK: - Initialization
    init() {
        NSLog("PetViewModel: init")
        self.isPetAtLeftExtreme = true
        self.positionOffset = CGPoint(x: -PATROL_MAX_X_OFFSET, y: 0) // Start at the left patrol point
        self.currentXScale = 1.0
        
        startCoreTimers()
        scheduleNextWalkDecision()
    }

    // MARK: - Public Methods
    func changePet(to type: PetType) {
        if currentPetType == type { return }
        let oldType = currentPetType
        
        resetPetState() // Resets walking and other states
        
        currentPetType = type
        NSLog("PetViewModel: currentPetType changed from \(oldType.friendlyName) to \(currentPetType.friendlyName)")
    }

    func petInteracted() {
        lastInteractionTime = Date()
        happinessScore = min(100, happinessScore + 20)
        
        enterTemporaryState(.sitting, duration: 1.5)
        resetInactivityTimer()
    }

    // MARK: - State Management Helpers
    private func determineBaseStateFromHappiness() -> PetState {
        if happinessScore > 70 { return .idleHappy }
        if happinessScore > 30 { return .idleNeutral }
        return .idleSad
    }
    
    private func enterTemporaryState(_ state: PetState, duration: TimeInterval) {
        temporaryStateTimer?.invalidate()
        stopCurrentWalkAnimation() // Stop any ongoing walk before entering a temporary state
        currentState = state
        
        NSLog("PetViewModel: Entering temporary state '\(state.rawValue)' for \(duration)s")
        
        temporaryStateTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            guard let self = self else { return }

            if self.currentState == state { // Revert only if still in the same temp state
                NSLog("PetViewModel: Temporary state '\(state.rawValue)' ended. Reverting to base state.")
                self.currentState = self.determineBaseStateFromHappiness()
            } else {
                NSLog("PetViewModel: Temp state timer for '\(state.rawValue)' fired, but state is now '\(self.currentState.rawValue)'. No reversion.")
            }
            self.scheduleNextWalkDecision() // Plan next walk after temporary state
        }
    }

    private func startCoreTimers() {
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

        // Degrade happiness
        if timeSinceLastInteraction > 15.0 {
            let previousHappiness = happinessScore
            happinessScore = max(0, happinessScore - 2)
            if happinessScore != previousHappiness {
                NSLog("PetViewModel: handleInactivity - Happiness degraded to \(happinessScore).")
            }
        }

        // Change state (sleep/idle) only if not currently walking
        if !isWalkingCurrently {
            if timeSinceLastInteraction > 75.0 && currentState.isIdleVariant { // Go to sleep
                if currentState != .sleeping {
                    NSLog("PetViewModel: handleInactivity - Pet going to sleep.")
                    currentState = .sleeping
                }
            } else if currentState.isIdleVariant { // Update idle animation
                let newIdealIdleState = determineBaseStateFromHappiness()
                if currentState != newIdealIdleState {
                    NSLog("PetViewModel: handleInactivity - Updating idle state to \(newIdealIdleState.rawValue).")
                    currentState = newIdealIdleState
                }
            }
        } else {
            NSLog("PetViewModel: handleInactivity - Pet is walking. Happiness checked.")
        }
    }
    
    // MARK: - Walking Logic
    private func scheduleNextWalkDecision() {
        walkDecisionTimer?.invalidate()
        let randomInterval = TimeInterval.random(in: MIN_TIME_UNTIL_NEXT_WALK_DECISION...MAX_TIME_UNTIL_NEXT_WALK_DECISION)
        NSLog("PetViewModel: Scheduling next walk decision in \(String(format: "%.1f", randomInterval))s")
        walkDecisionTimer = Timer.scheduledTimer(withTimeInterval: randomInterval, repeats: false) { [weak self] _ in
            self?.decideToWalk()
        }
    }

    // Can be made private after testing
    func decideToWalk() {
        guard !isWalkingCurrently, currentState.isIdleVariant else {
            if !currentState.isIdleVariant {
                 NSLog("PetViewModel: decideToWalk - Cannot walk, not idle. State: \(currentState.rawValue)")
            }
            scheduleNextWalkDecision() // Reschedule if conditions not met
            return
        }

        if Bool.random() { // 50% chance to start a walk
            NSLog("PetViewModel: Decided to walk. Currently at left extreme: \(isPetAtLeftExtreme)")
            isWalkingCurrently = true
            currentState = .running
            
            if isPetAtLeftExtreme { // Determine direction and target based on current patrol extreme
                internalWalkDirection = 1.0
                currentXScale = 1.0 // Face right
                internalWalkTargetX = PATROL_MAX_X_OFFSET
            } else {
                internalWalkDirection = -1.0
                currentXScale = -1.0 // Face left
                internalWalkTargetX = -PATROL_MAX_X_OFFSET
            }
            NSLog("PetViewModel: Walking from x=\(String(format: "%.1f", positionOffset.x)) towards x=\(internalWalkTargetX)")
            startWalkAnimation()
        } else {
            NSLog("PetViewModel: Decided to stay idle at x=\(String(format: "%.1f", positionOffset.x)).")
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
            stopCurrentWalkAnimation()
            return
        }

        var newX = positionOffset.x + (internalWalkDirection * PET_WALK_SPEED)

        let reachedTarget: Bool
        if internalWalkDirection > 0 { // Moving right
            reachedTarget = newX >= internalWalkTargetX
        } else { // Moving left
            reachedTarget = newX <= internalWalkTargetX
        }

        if reachedTarget {
            positionOffset.x = internalWalkTargetX  // Snap to target
            isPetAtLeftExtreme.toggle()             // Now at the other extreme
            NSLog("PetViewModel: Reached target x=\(String(format: "%.1f", positionOffset.x)). isPetAtLeftExtreme: \(isPetAtLeftExtreme)")
            stopCurrentWalkAnimationAndGoIdle()     // Walk segment finished
        } else {
            positionOffset.x = newX
        }
    }

    // Stops the current walk animation and sets pet to idle, then schedules next decision
    private func stopCurrentWalkAnimationAndGoIdle() {
        walkStepTimer?.invalidate()
        walkStepTimer = nil
        
        if isWalkingCurrently {
            NSLog("PetViewModel: Walk segment finished at x=\(String(format: "%.1f", positionOffset.x)). Reverting to idle.")
            currentState = determineBaseStateFromHappiness()
        }
        isWalkingCurrently = false
        // Consider if currentXScale should reset to a default idle direction, e.g., self.currentXScale = 1.0
        
        scheduleNextWalkDecision()
    }
    
    // General method to stop all walking behavior and timers.
    // Used by temporary states or full pet resets.
    private func stopCurrentWalkAnimation(andResetPositionToPatrolStart: Bool = false) {
        walkStepTimer?.invalidate()
        walkStepTimer = nil
        // Note: walkDecisionTimer is not invalidated here, as a temporary state might want
        // to resume walk decisions after it finishes. If a hard stop is needed, invalidate it separately.

        if isWalkingCurrently { // If it was walking, transition to idle
             NSLog("PetViewModel: stopCurrentWalkAnimation called. Current state \(currentState.rawValue) -> to idle.")
             currentState = determineBaseStateFromHappiness()
        }
        isWalkingCurrently = false

        if andResetPositionToPatrolStart {
            isPetAtLeftExtreme = true // Default to left extreme
            positionOffset.x = -PATROL_MAX_X_OFFSET
            currentXScale = 1.0 // Default facing
            NSLog("PetViewModel: stopCurrentWalkAnimation - position reset to patrol start (left).")
        }
    }

    // MARK: - General State Reset
    func resetPetState() {
        NSLog("PetViewModel: resetPetState called.")
        happinessScore = 50
        lastInteractionTime = Date()
        
        // Stop all timers and reset walking state completely
        walkDecisionTimer?.invalidate()
        walkStepTimer?.invalidate()
        isWalkingCurrently = false
        
        isPetAtLeftExtreme = true // Reset to start on the left for patrol
        positionOffset = CGPoint(x: -PATROL_MAX_X_OFFSET, y: 0)
        currentXScale = 1.0
        currentState = .idleNeutral
        
        temporaryStateTimer?.invalidate()
        startCoreTimers()           // Restart inactivity timer
        scheduleNextWalkDecision()  // Schedule the first walk decision
    }

    // MARK: - Cleanup
    public func performCleanup() {
        inactivityTimer?.invalidate()
        temporaryStateTimer?.invalidate()
        walkDecisionTimer?.invalidate()
        walkStepTimer?.invalidate()
        NSLog("PetViewModel: performCleanup - All timers invalidated.")
    }

    deinit {
        performCleanup()
    }
}
