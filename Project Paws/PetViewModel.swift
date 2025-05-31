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
    @Published var currentXScale: CGFloat = 1.0   // For sprite flipping
    @Published var happinessScore: Int = 50

    private var lastInteractionTime: Date = Date()

    // Timers
    private var inactivityTimer: Timer?
    private var temporaryStateTimer: Timer?
    private var walkDecisionTimer: Timer?
    private var walkStepTimer: Timer?

    // Walking state
    private var isWalkingCurrently: Bool = false
    private var isPetAtLeftExtreme: Bool = true // True if pet is at/headed from left patrol point
    private var internalWalkTargetX: CGFloat = 0
    private var internalWalkDirection: CGFloat = 1.0

    init() {
        NSLog("PetViewModel: init")
        self.isPetAtLeftExtreme = true
        self.positionOffset = CGPoint(x: -PATROL_MAX_X_OFFSET, y: 0) // Start at the left patrol point
        self.currentXScale = 1.0
        
        startCoreTimers()
        scheduleNextWalkDecision()
    }

    func changePet(to type: PetType) {
        if currentPetType == type { return }
        let oldType = currentPetType
        resetPetState()
        currentPetType = type
        NSLog("PetViewModel: currentPetType changed from \(oldType.friendlyName) to \(currentPetType.friendlyName)")
    }

    func petInteracted() {
        lastInteractionTime = Date()
        happinessScore = min(100, happinessScore + 20)
        enterTemporaryState(.sitting, duration: 1.5)
        resetInactivityTimer()
    }

    private func determineBaseStateFromHappiness() -> PetState {
        if happinessScore > 70 { return .idleHappy }
        if happinessScore > 30 { return .idleNeutral }
        return .idleSad
    }
    
    private func enterTemporaryState(_ state: PetState, duration: TimeInterval) {
        temporaryStateTimer?.invalidate()
        haltOngoingWalkActivity() // Interrupt current walk
        currentState = state
        
        NSLog("PetViewModel: Entering temporary state '\(state.rawValue)' for \(duration)s")
        
        temporaryStateTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.currentState == state {
                NSLog("PetViewModel: Temporary state '\(state.rawValue)' ended. Reverting to base state.")
                self.currentState = self.determineBaseStateFromHappiness()
            } else {
                NSLog("PetViewModel: Temp state timer for '\(state.rawValue)' ended, but state is now '\(self.currentState.rawValue)'. No reversion.")
            }
            self.scheduleNextWalkDecision()
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
        if temporaryStateTimer?.isValid ?? false { return }
        if currentState == .sleeping { return }

        let timeSinceLastInteraction = Date().timeIntervalSince(lastInteractionTime)

        if timeSinceLastInteraction > 15.0 {
            let oldHappiness = happinessScore
            happinessScore = max(0, happinessScore - 2)
            if oldHappiness != happinessScore { NSLog("PetViewModel: Happiness degraded to \(happinessScore).") }
        }

        if !isWalkingCurrently {
            if timeSinceLastInteraction > 75.0 && currentState.isIdleVariant {
                if currentState != .sleeping {
                    currentState = .sleeping
                    NSLog("PetViewModel: Pet going to sleep.")
                }
            } else if currentState.isIdleVariant {
                let newIdleState = determineBaseStateFromHappiness()
                if currentState != newIdleState {
                    currentState = newIdleState
                    NSLog("PetViewModel: Updating idle state to \(newIdleState.rawValue).")
                }
            }
        }
    }
    
    // MARK: - Walking Logic
    private func scheduleNextWalkDecision() {
        walkDecisionTimer?.invalidate()
        let interval = TimeInterval.random(in: MIN_TIME_UNTIL_NEXT_WALK_DECISION...MAX_TIME_UNTIL_NEXT_WALK_DECISION)
        NSLog("PetViewModel: Scheduling next walk decision in \(String(format: "%.1f", interval))s")
        walkDecisionTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.decideToWalk()
        }
    }

    // Public for your debugging menu item, can be private later
    func decideToWalk() {
        guard !isWalkingCurrently, currentState.isIdleVariant else {
            if !currentState.isIdleVariant { NSLog("PetViewModel: DecideToWalk - Not walking, pet not idle (State: \(currentState.rawValue)).") }
            scheduleNextWalkDecision()
            return
        }

        if Bool.random() { // 50% chance to walk
            isWalkingCurrently = true
            currentState = .running
            
            if isPetAtLeftExtreme { // Determine walk direction and target
                internalWalkDirection = 1.0
                currentXScale = 1.0 // Face right
                internalWalkTargetX = PATROL_MAX_X_OFFSET
            } else {
                internalWalkDirection = -1.0
                currentXScale = -1.0 // Face left
                internalWalkTargetX = -PATROL_MAX_X_OFFSET
            }
            NSLog("PetViewModel: Starting walk. AtLeft: \(isPetAtLeftExtreme). TargetX: \(internalWalkTargetX). CurrentX: \(String(format: "%.1f", positionOffset.x))")
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
            completeCurrentWalkSegment() // Safeguard
            return
        }

        var newX = positionOffset.x + (internalWalkDirection * PET_WALK_SPEED)
        let reachedTarget = (internalWalkDirection > 0) ? (newX >= internalWalkTargetX) : (newX <= internalWalkTargetX)

        if reachedTarget {
            positionOffset.x = internalWalkTargetX
            isPetAtLeftExtreme.toggle()
            NSLog("PetViewModel: Reached target x=\(String(format: "%.1f", positionOffset.x)). isPetAtLeftExtreme: \(isPetAtLeftExtreme)")
            completeCurrentWalkSegment()
        } else {
            positionOffset.x = newX
        }
    }

    private func completeCurrentWalkSegment() {
        walkStepTimer?.invalidate()
        walkStepTimer = nil
        
        if isWalkingCurrently {
            NSLog("PetViewModel: Walk segment completed. Setting to idle.")
            currentState = determineBaseStateFromHappiness()
        }
        isWalkingCurrently = false
        scheduleNextWalkDecision()
    }
    
    private func haltOngoingWalkActivity(resetPositionToPatrolStart: Bool = false) {
        walkStepTimer?.invalidate()
        walkStepTimer = nil
        // walkDecisionTimer is not stopped here; active interruption might want decisions to resume soon.
        
        if isWalkingCurrently {
             NSLog("PetViewModel: haltOngoingWalkActivity - Forcibly stopping walk.")
             currentState = determineBaseStateFromHappiness()
        }
        isWalkingCurrently = false

        if resetPositionToPatrolStart { // Typically for full resets
            isPetAtLeftExtreme = true
            positionOffset.x = -PATROL_MAX_X_OFFSET
            currentXScale = 1.0
            NSLog("PetViewModel: haltOngoingWalkActivity - Position reset to patrol start (left).")
        }
    }

    func resetPetState() {
        NSLog("PetViewModel: resetPetState called.")
        happinessScore = 50
        lastInteractionTime = Date()
        
        walkDecisionTimer?.invalidate() // Stop future walk decisions
        haltOngoingWalkActivity(resetPositionToPatrolStart: true) // Stop current walk & reset pos
        
        currentState = .idleNeutral
        // positionOffset and currentXScale are set by haltOngoingWalkActivity
        
        temporaryStateTimer?.invalidate()
        startCoreTimers()
        scheduleNextWalkDecision()
    }

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
