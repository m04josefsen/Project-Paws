//
//  PetViewModel.swift
//  Project Paws
//
//  Created by Marco Josefsen on 28/05/2025.
//

import Foundation
import Combine

class PetViewModel: ObservableObject {
    @Published var currentPetType: PetType = .cat
    @Published var currentState: PetState = .idleNeutral
    @Published var positionOffset: CGPoint = .zero // Kept for potential future use with running/jumping

    var happinessScore: Int = 50 // 0-100 (Made internal)
    private var lastInteractionTime: Date = Date()

    private var inactivityTimer: Timer? // For mood degradation and sleep checks
    // private var peekTimer: Timer? // Removed as peeking states are gone
    private var temporaryStateTimer: Timer? // For states like eating, beingPetted

    init() {
        NSLog("DEBUG-NSLog: PetViewModel init - STARTING")
        // self.startTimers() // Keep this commented for now if it was
        NSLog("DEBUG-NSLog: PetViewModel init - FINISHED")
    }

    func changePet(to type: PetType) {
        currentPetType = type
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

    func petInteracted() {
        lastInteractionTime = Date()
        happinessScore = min(100, happinessScore + 20)
        
        // Since .beingPetted state is removed, transition to a happy idle or sitting state briefly.
        // You can customize this behavior.
        enterTemporaryState(.sitting, duration: 1.5) // Example: pet sits happily
        // Alternatively: enterTemporaryState(determineBaseStateFromHappiness(), duration: 1.5)
        resetInactivityTimer()
        objectWillChange.send() // Ensure UI updates if state changes
    }

    func feedPet() {
        lastInteractionTime = Date()
        happinessScore = min(100, happinessScore + 30)

        // Since .eating state is removed, transition to a happy idle or sitting state briefly.
        // You can customize this behavior.
        enterTemporaryState(.idleHappy, duration: 2.0) // Example: pet is happy after eating
        resetInactivityTimer()
        objectWillChange.send() // Ensure UI updates
    }
    
    private func enterTemporaryState(_ state: PetState, duration: TimeInterval) {
        temporaryStateTimer?.invalidate()
        currentState = state
        // positionOffset = .zero // Reset offset if the temporary state shouldn't have one

        temporaryStateTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            // Revert to base state determined by happiness, unless another action took over
            if self.currentState == state { // Ensure we only revert if still in that temp state
                self.currentState = self.determineBaseStateFromHappiness()
                // self.positionOffset = .zero // Ensure offset is reset when reverting
                self.objectWillChange.send()
            }
        }
        objectWillChange.send()
    }

    private func startTimers() {
        resetInactivityTimer()

        // peekTimer?.invalidate() // Removed
        // peekTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval.random(in: 20...40), repeats: true) { [weak self] _ in
        //     self?.tryPeek() // tryPeek was removed
        // }
    }
    
    private func resetInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            self?.handleInactivity()
        }
    }

    private func handleInactivity() {
        // Removed: guard let self = self else { return } // No longer needed here

        // Don't degrade mood or try to sleep if in an active temporary state or already sleeping.
        // Adjust based on new states if needed.
        if currentState == .running || currentState == .jumping || currentState == .sleeping {
             // Or if temporaryStateTimer is active and currentState is one of those temp states.
            if temporaryStateTimer?.isValid ?? false && (currentState == .sitting /* if used as temp state */ || currentState == .idleHappy /* if used as temp state */) {
                 // Allow temp state to finish
            } else {
                return
            }
        }


        let timeSinceLastInteraction = Date().timeIntervalSince(lastInteractionTime)

        if timeSinceLastInteraction > 10 {
            happinessScore = max(0, happinessScore - 5)
        }

        if timeSinceLastInteraction > 60 && currentState.isIdleVariant {
            currentState = .sleeping
        } else if currentState.isIdleVariant {
            currentState = determineBaseStateFromHappiness()
        }
        objectWillChange.send()
    }

    // private func tryPeek() { ... } // Removed as peeking states are gone.
    // If you want a similar behavior, you might implement a short "running" sequence.
    
    func resetPetState() {
        happinessScore = 50
        lastInteractionTime = Date()
        currentState = .idleNeutral
        positionOffset = .zero
        temporaryStateTimer?.invalidate()
        startTimers()
        objectWillChange.send()
    }

    public func performCleanup() {
        inactivityTimer?.invalidate()
        // peekTimer?.invalidate() // Removed
        temporaryStateTimer?.invalidate()
    }

    deinit {
        performCleanup()
    }
}
