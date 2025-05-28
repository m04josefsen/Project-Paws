//
//  PetViewModel.swift
//  Project Paws
//
//  Created by Marco Josefsen on 28/05/2025.
//

import Combine
import Foundation

class PetViewModel: ObservableObject {
    @Published var currentPetType: PetType = .tortoise
    @Published var mood: PetMood = .neutral
    @Published var actionState: PetActionState = .idle
    @Published var positionOffset: CGPoint = .zero // For peeking animations

    private var happinessScore: Int = 50 // 0-100
    private var lastInteractionTime: Date = Date()

    private var moodTimer: Timer?
    private var sleepTimer: Timer?
    private var peekTimer: Timer?
    private var animationTimer: Timer? // For timed visual effects like hearts

    init() {
        startTimers()
    }

    func changePet(to type: PetType) {
        currentPetType = type
        resetPetState()
    }

    func petInteracted() {
        lastInteractionTime = Date()
        happinessScore = min(100, happinessScore + 20)
        updateMood()
        
        if mood == .happy {
            actionState = .showingLove
            // Reset action state after a short duration
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if self.actionState == .showingLove { // ensure it wasn't changed by another state
                     self.actionState = .idle
                }
            }
        } else if mood == .neutral && actionState == .sleeping {
             actionState = .idle // Wake up
        }
        
        resetSleepTimer()
    }

    func feedPet() {
        lastInteractionTime = Date()
        happinessScore = min(100, happinessScore + 30)
        updateMood()
        actionState = .showingLove
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if self.actionState == .showingLove {
                 self.actionState = .idle
            }
        }
        resetSleepTimer()
    }

    private func startTimers() {
        moodTimer?.invalidate()
        moodTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            self?.degradeMood()
        }

        resetSleepTimer() // Also starts it

        peekTimer?.invalidate()
        peekTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval.random(in: 20...40), repeats: true) { [weak self] _ in
            self?.tryPeek()
        }
    }
    
    private func resetSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: false) { [weak self] _ in // Longer interval for sleep
            self?.trySleep()
        }
    }

    private func degradeMood() {
        happinessScore = max(0, happinessScore - 10)
        updateMood()
    }

    private func updateMood() {
        if happinessScore > 70 {
            mood = .happy
        } else if happinessScore > 30 {
            mood = .neutral
        } else {
            mood = .sad
            if actionState != .sleeping { // Don't show sadness if asleep
                actionState = .showingSadness
                 DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    if self.actionState == .showingSadness {
                         self.actionState = .idle
                    }
                }
            }
        }
        objectWillChange.send() // Notify view of changes
    }

    private func trySleep() {
        // Only sleep if not interacted with for a while and not already peeking or in an emotional state
        if Date().timeIntervalSince(lastInteractionTime) > 55 && actionState == .idle { // 55 to be less than sleepTimer
            mood = .sleeping
            actionState = .sleeping
            objectWillChange.send()
        } else {
            resetSleepTimer() // If sleep was interrupted or conditions not met, reset timer
        }
    }

    private func tryPeek() {
        guard actionState == .idle || actionState == .sleeping else { return } // Don't peek if busy or already peeking
        
        let peekDirection = Bool.random() ? PetActionState.peekingLeft : PetActionState.peekingRight
        actionState = peekDirection
        
        let peekAmount: CGFloat = PET_WINDOW_SIZE.width / 3
        self.positionOffset.x = (peekDirection == .peekingLeft) ? -peekAmount : peekAmount
        
        // Animate back
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.positionOffset.x = 0 // Center
            // Animate further out then back to idle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let hideOffset: CGFloat = PET_WINDOW_SIZE.width * 0.7
                self.positionOffset.x = (peekDirection == .peekingLeft) ? -hideOffset : hideOffset
                 // Then fully hide (animating upwards slightly)
                self.positionOffset.y = -PET_WINDOW_SIZE.height / 3

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.positionOffset = .zero // Reset position
                    if self.mood != .sleeping { // If not sleeping, go back to idle
                        self.actionState = .idle
                    } else {
                        self.actionState = .sleeping // Remain sleeping
                    }
                }
            }
        }
        objectWillChange.send()
    }
    
    func resetPetState() {
        happinessScore = 50
        lastInteractionTime = Date()
        mood = .neutral
        actionState = .idle
        positionOffset = .zero
        startTimers() // Restart timers with new pet
        objectWillChange.send()
    }

    public func performCleanup() { // Or name it invalidateTimers(), prepareForTermination(), etc.
        print("PetViewModel performing cleanup: invalidating timers.")
        moodTimer?.invalidate()
        sleepTimer?.invalidate()
        peekTimer?.invalidate()
        animationTimer?.invalidate()
        // Invalidate any other resources if needed
    }
    
    deinit {
        performCleanup()
        print("PetViewModel deinitialized.")
    }
}
