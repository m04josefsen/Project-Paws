//
//  PetView.swift
//  Project Paws
//
//  Created by Marco Josefsen on 28/05/2025.
//

import Cocoa
import Combine

// Configuration for a single animation sequence from a sprite sheet
struct AnimationConfig {
    let sheetName: String
    let frameSize: CGSize
    let frameCount: Int
    let speed: TimeInterval
}

// Responsible for drawing pet and visual effects
class PetView: NSView {
    private var viewModel: PetViewModel
    private var cancellables = Set<AnyCancellable>()
    
    // Sprite Animation Properties
    private var animationTimer: Timer?
    private var currentFrameIndex: Int = 0
    private var currentSpriteSheet: NSImage?
    private var currentFrameSize: CGSize = .zero
    private var currentFrameCount: Int = 1
    private var currentAnimationSpeed: TimeInterval = 0.2

    // Particle Effect Properties
    private var particleTimer: Timer?
    private var particles: [(point: CGPoint, symbol: String, color: NSColor, alpha: CGFloat, dy: CGFloat)] = []

    // Animation Configurations (ensure these match your assets)
    private static let baseFrameDuration: Double = 0.25
    private static let animationConfigurations: [String: AnimationConfig] = [
        // Cat
        "cat_idleNeutral_sheet": AnimationConfig(sheetName: "cat_idleNeutral_sheet", frameSize: CGSize(width: 32, height: 32), frameCount: 14, speed: baseFrameDuration),
        "cat_idleHappy_sheet": AnimationConfig(sheetName: "cat_idleHappy_sheet", frameSize: CGSize(width: 32, height: 32), frameCount: 18, speed: baseFrameDuration),
        "cat_idleSad_sheet": AnimationConfig(sheetName: "cat_idleSad_sheet", frameSize: CGSize(width: 32, height: 32), frameCount: 3, speed: baseFrameDuration),
        "cat_sleeping_sheet": AnimationConfig(sheetName: "cat_sleeping_sheet", frameSize: CGSize(width: 32, height: 32), frameCount: 3, speed: baseFrameDuration),
        "cat_sitting_sheet": AnimationConfig(sheetName: "cat_sitting_sheet", frameSize: CGSize(width: 32, height: 32), frameCount: 3, speed: baseFrameDuration),
        "cat_running_sheet": AnimationConfig(sheetName: "cat_running_sheet", frameSize: CGSize(width: 32, height: 32), frameCount: 7, speed: baseFrameDuration / 2.0), // Faster speed for running
        "cat_jumping_sheet": AnimationConfig(sheetName: "cat_jumping_sheet", frameSize: CGSize(width: 32, height: 32), frameCount: 13, speed: baseFrameDuration / 1.5), // Faster for jumping

        // Bunny
        "bunny_idleNeutral_sheet": AnimationConfig(sheetName: "bunny_idleNeutral_sheet", frameSize: CGSize(width: 32, height: 32), frameCount: 12, speed: baseFrameDuration),
        "bunny_idleHappy_sheet": AnimationConfig(sheetName: "bunny_idleHappy_sheet", frameSize: CGSize(width: 32, height: 32), frameCount: 5, speed: baseFrameDuration),
        "bunny_idleSad_sheet": AnimationConfig(sheetName: "bunny_idleSad_sheet", frameSize: CGSize(width: 32, height: 32), frameCount: 3, speed: baseFrameDuration),
        "bunny_sleeping_sheet": AnimationConfig(sheetName: "bunny_sleeping_sheet", frameSize: CGSize(width: 32, height: 32), frameCount: 6, speed: baseFrameDuration),
        "bunny_sitting_sheet": AnimationConfig(sheetName: "bunny_sitting_sheet", frameSize: CGSize(width: 32, height: 32), frameCount: 1, speed: baseFrameDuration),
        "bunny_running_sheet": AnimationConfig(sheetName: "bunny_running_sheet", frameSize: CGSize(width: 32, height: 32), frameCount: 8, speed: baseFrameDuration / 2.0),
        "bunny_jumping_sheet": AnimationConfig(sheetName: "bunny_jumping_sheet", frameSize: CGSize(width: 32, height: 32), frameCount: 11, speed: baseFrameDuration / 1.5)
        // Add other pet types (dog, tortoise, fish) and their states here
    ]

    init(viewModel: PetViewModel) {
        self.viewModel = viewModel
        super.init(frame: NSRect(origin: .zero, size: PET_WINDOW_SIZE)) // PET_WINDOW_SIZE from Constants
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor

        viewModel.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateAnimationState()
                self?.updateParticleEffect()
            }
        }.store(in: &cancellables)
        
        updateAnimationState() // Initial setup
        updateParticleEffect()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        animationTimer?.invalidate()
        particleTimer?.invalidate()
    }

    private func getAnimationConfig(for petType: PetType, state: PetState) -> AnimationConfig? {
        let petBaseName = petType.rawValue
        let animationStyleKey = state.rawValue
        let sheetAssetName = "\(petBaseName)_\(animationStyleKey)_sheet"
        
        NSLog("PetView: getAnimationConfig - Requesting: \(sheetAssetName)")
        if let config = PetView.animationConfigurations[sheetAssetName] {
            NSLog("PetView: getAnimationConfig - Found: \(sheetAssetName)")
            return config
        } else {
            NSLog("PetView: getAnimationConfig - ⚠️ Not found in dictionary: \(sheetAssetName)")
            let fallbackAssetName = "\(petBaseName)_idleNeutral_sheet"
            if let fallbackConfig = PetView.animationConfigurations[fallbackAssetName] {
                NSLog("PetView: getAnimationConfig - Using fallback (idleNeutral) for \(sheetAssetName): \(fallbackAssetName)")
                return fallbackConfig
            }
            NSLog("PetView: getAnimationConfig - ⚠️ No fallback (idleNeutral) found for \(petBaseName).")
            return nil
        }
    }

    private func updateAnimationState() {
        animationTimer?.invalidate()
        animationTimer = nil
        
        NSLog("PetView: updateAnimationState - ViewModel state: \(viewModel.currentState), pet: \(viewModel.currentPetType.rawValue)")
        var imageLoaded = false

        if let config = getAnimationConfig(for: viewModel.currentPetType, state: viewModel.currentState) {
            if let sheet = NSImage(named: config.sheetName) {
                currentSpriteSheet = sheet
                currentFrameSize = config.frameSize
                currentFrameCount = config.frameCount
                currentAnimationSpeed = config.speed
                currentFrameIndex = 0 // Reset for new animation
                imageLoaded = true
                NSLog("PetView: updateAnimationState - Loaded sheet: \(config.sheetName), Frames: \(config.frameCount)")

                if currentFrameCount > 1 {
                    animationTimer = Timer.scheduledTimer(withTimeInterval: currentAnimationSpeed, repeats: true) { [weak self] _ in
                        guard let self = self else { return }
                        self.currentFrameIndex = (self.currentFrameIndex + 1) % self.currentFrameCount
                        self.needsDisplay = true
                    }
                }
            } else {
                NSLog("PetView: updateAnimationState - ⚠️ SPRITE SHEET NAMED '\(config.sheetName)' NOT FOUND in Assets.xcassets.")
            }
        } else {
             NSLog("PetView: updateAnimationState - ⚠️ No animation config from getAnimationConfig.")
        }

        if !imageLoaded { // Fallback to static images if animation config or sheet fails
            let petBaseName = viewModel.currentPetType.rawValue
            let staticImageName = "\(petBaseName)_\(viewModel.currentState.rawValue)" // e.g., cat_running
            
            if let staticImage = NSImage(named: staticImageName) {
                currentSpriteSheet = staticImage
                currentFrameSize = staticImage.size
                currentFrameCount = 1
                currentFrameIndex = 0
                NSLog("PetView: updateAnimationState - Loaded static fallback: \(staticImageName)")
            } else {
                NSLog("PetView: updateAnimationState - Static fallback '\(staticImageName)' not found. Trying default idle.")
                let defaultIdleImageName = "\(petBaseName)_idleNeutral" // Default non-sheeted idle image
                if let defaultImage = NSImage(named: defaultIdleImageName) {
                    currentSpriteSheet = defaultImage
                    currentFrameSize = defaultImage.size
                    currentFrameCount = 1
                    currentFrameIndex = 0
                    NSLog("PetView: updateAnimationState - Loaded default static idle: \(defaultIdleImageName)")
                } else {
                    NSLog("PetView: updateAnimationState - ⚠️ Default static idle '\(defaultIdleImageName)' also not found. No image.")
                    currentSpriteSheet = nil
                }
            }
        }
        self.needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let imageToDraw = currentSpriteSheet, currentFrameSize.width > 0, currentFrameSize.height > 0 else {
            // Fallback drawing if no image is available
            NSColor.systemGray.withAlphaComponent(0.3).setFill()
            let fallbackPath = NSBezierPath(ovalIn: bounds.insetBy(dx: bounds.width * 0.3, dy: bounds.height * 0.3))
            fallbackPath.fill()
            return
        }

        // Calculate sprite draw size, respecting aspect ratio and fitting within bounds with a margin
        let viewWidth = bounds.width
        let viewHeight = bounds.height
        var drawWidth = currentFrameSize.width
        var drawHeight = currentFrameSize.height

        // Apply a scaling factor to make the pet smaller within its window, allowing room to walk
        // 1.0, standard
        let displaySizeFactor: CGFloat = 1.0
        
        let scaledTargetWidth = currentFrameSize.width * displaySizeFactor
        let scaledTargetHeight = currentFrameSize.height * displaySizeFactor

        let widthRatio = viewWidth / scaledTargetWidth
        let heightRatio = viewHeight / scaledTargetHeight
        let fitScale = min(widthRatio, heightRatio) // Ensure it fits if window is smaller than scaled target

        // Final draw dimensions based on original frame size and display factor
        drawWidth = scaledTargetWidth * (fitScale < 1.0 ? fitScale : 1.0) // Don't scale up if window is huge
        drawHeight = scaledTargetHeight * (fitScale < 1.0 ? fitScale : 1.0)


        let petOriginXBase = (viewWidth - drawWidth) / 2
        let petOriginYBase = (viewHeight - drawHeight) / 2
        
        let finalPetOriginX = petOriginXBase + viewModel.positionOffset.x
        let finalPetOriginY = petOriginYBase + viewModel.positionOffset.y

        let destinationRect = NSRect(x: finalPetOriginX, y: finalPetOriginY, width: drawWidth, height: drawHeight)
        let sourceRect = NSRect(x: CGFloat(currentFrameIndex) * currentFrameSize.width, y: 0, width: currentFrameSize.width, height: currentFrameSize.height)

        // Apply Flipping Transform for walking direction
        NSGraphicsContext.current?.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: destinationRect.midX, yBy: destinationRect.midY) // Move pivot to center of destination
        transform.scaleX(by: viewModel.currentXScale, yBy: 1.0)                   // Scale (flip if -1)
        transform.translateX(by: -destinationRect.midX, yBy: -destinationRect.midY)// Move pivot back
        transform.concat() // Apply

        imageToDraw.draw(in: destinationRect, from: sourceRect, operation: .sourceOver, fraction: 1.0)
        
        NSGraphicsContext.current?.restoreGraphicsState()
        
        // Particle drawing
        for particle in particles {
            // Using a fixed size for particles relative to original pet window design (smaller part of it)
            let particleReferenceSize = min(PET_WINDOW_SIZE.width, PET_WINDOW_SIZE.height) // Original square window assumption
            let particleDisplaySize = particleReferenceSize * 0.25
            if let particleSymbolImage = NSImage(systemSymbolName: particle.symbol, accessibilityDescription: particle.symbol) {
                let symbolConfig = NSImage.SymbolConfiguration(pointSize: particleDisplaySize, weight: .regular)
                                        .applying(.init(paletteColors: [particle.color.withAlphaComponent(particle.alpha)]))
                if let tintedImage = particleSymbolImage.withSymbolConfiguration(symbolConfig) {
                    tintedImage.draw(at: particle.point, from: .zero, operation: .sourceOver, fraction: particle.alpha)
                }
            }
        }
    }

    private func updateParticleEffect() {
        particleTimer?.invalidate()
        particles.removeAll()

        var symbol = ""
        var color = NSColor.red
        var shouldAnimateParticles = false
        let currentHappiness = viewModel.happinessScore

        switch viewModel.currentState {
        case .idleHappy:
             if currentHappiness > 60 {
                symbol = "heart.fill"
                color = .systemRed
                shouldAnimateParticles = true
            }
        case .sitting: // Often a temporary happy state from interaction
            if currentHappiness > 60 {
                symbol = "heart.fill"
                color = .systemPink
                shouldAnimateParticles = true
            }
        case .idleSad:
            if currentHappiness < 40 {
                symbol = "heart.slash.fill"
                color = .systemGray
                shouldAnimateParticles = true
            }
        case .sleeping:
            symbol = "zzz"
            color = .systemBlue
            shouldAnimateParticles = true
        default:
            break
        }

        if shouldAnimateParticles && !symbol.isEmpty {
            // Position particles relative to the center of the view's bounds
            let centerX = bounds.midX
            let particleYStart = bounds.height * 0.65

            for _ in 0..<3 {
                let xPos = centerX + CGFloat.random(in: -bounds.width * 0.1 ... bounds.width * 0.1)
                let yPos = particleYStart + CGFloat.random(in: -5...5)
                particles.append((CGPoint(x: xPos, y: yPos), symbol, color, 1.0, CGFloat.random(in: 0.6...1.2) * (symbol == "zzz" ? 0.5 : 1.0)))
            }
            
            particleTimer = Timer.scheduledTimer(withTimeInterval: 0.07, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                var newParticles: [(CGPoint, String, NSColor, CGFloat, CGFloat)] = []
                for var particle in self.particles {
                    particle.point.y += particle.dy
                    particle.alpha -= 0.04
                    if particle.alpha > 0.05 { newParticles.append(particle) }
                }
                self.particles = newParticles
                if self.particles.isEmpty {
                    self.particleTimer?.invalidate()
                    self.particleTimer = nil
                }
                self.needsDisplay = true
            }
        }
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let clickLocation = convert(event.locationInWindow, from: nil)
        
        // Clickable area should roughly match the drawn pet.
        // Based on finalPetOriginX, finalPetOriginY, drawWidth, drawHeight from draw()
        // This requires draw() to save these values or recalculate.
        // For a simpler approximation:
        let drawnPetWidth = currentFrameSize.width * 0.8 // Based on displaySizeFactor in draw()
        let drawnPetHeight = currentFrameSize.height * 0.8

        let petClickableRect = NSRect(
            x: (bounds.width - drawnPetWidth) / 2 + viewModel.positionOffset.x,
            y: (bounds.height - drawnPetHeight) / 2 + viewModel.positionOffset.y,
            width: drawnPetWidth,
            height: drawnPetHeight
        )

        if petClickableRect.contains(clickLocation) {
            viewModel.petInteracted()
        }
    }
    
    override var acceptsFirstResponder: Bool { return true }
}
