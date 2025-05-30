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
    let sheetName: String      // Asset name of the sprite sheet
    let frameSize: CGSize      // Dimensions of a single frame
    let frameCount: Int        // Number of frames in this animation
    let speed: TimeInterval    // Duration of each frame
}

// Responsible for drawing pet and visual effects
class PetView: NSView {
    private var viewModel: PetViewModel
    private var cancellables = Set<AnyCancellable>()
    
    private var animationTimer: Timer?
    private var currentFrameIndex: Int = 0
    private var currentSpriteSheet: NSImage?
    private var currentFrameSize: CGSize = .zero
    private var currentFrameCount: Int = 1
    private var currentAnimationSpeed: TimeInterval = 0.2

    private var particleTimer: Timer?
    private var particles: [(point: CGPoint, symbol: String, color: NSColor, alpha: CGFloat, dy: CGFloat)] = []

    // Animation Configuration Dictionary
    private static let baseFrameDuration: Double = 0.25  // Each frame shows for 0.25 seconds
    private static let animationConfigurations: [String: AnimationConfig] = [
        // Cat
        "cat_idleNeutral_sheet": AnimationConfig(sheetName: "cat_idleNeutral_sheet", frameSize: CGSize(width: 32, height: 32), frameCount: 14, speed: baseFrameDuration),
        "cat_idleHappy_sheet": AnimationConfig(sheetName: "cat_idleHappy_sheet", frameSize: CGSize(width: 32, height: 32), frameCount: 18, speed: baseFrameDuration),
        "cat_idleSad_sheet": AnimationConfig(sheetName: "cat_idleSad_sheet", frameSize: CGSize(width: 32, height: 32), frameCount: 3, speed: baseFrameDuration),
        "cat_sleeping_sheet": AnimationConfig(sheetName: "cat_sleeping_sheet", frameSize: CGSize(width: 32, height: 32), frameCount: 3, speed: baseFrameDuration),
        "cat_sitting_sheet": AnimationConfig(sheetName: "cat_sitting_sheet", frameSize: CGSize(width: 32, height: 32), frameCount: 3, speed: baseFrameDuration),
        "cat_running_sheet": AnimationConfig(sheetName: "cat_running_sheet", frameSize: CGSize(width: 32, height: 32), frameCount: 7, speed: baseFrameDuration),
        "cat_jumping_sheet": AnimationConfig(sheetName: "cat_jumping_sheet", frameSize: CGSize(width: 32, height: 32), frameCount: 13, speed: baseFrameDuration),

        // Bunny
        "bunny_idleNeutral_sheet": AnimationConfig(sheetName: "bunny_idleNeutral_sheet", frameSize: CGSize(width: 32, height: 32), frameCount: 12, speed: baseFrameDuration),
        "bunny_idleHappy_sheet": AnimationConfig(sheetName: "bunny_idleHappy_sheet", frameSize: CGSize(width: 32, height: 32), frameCount: 5, speed: baseFrameDuration),
        "bunny_idleSad_sheet": AnimationConfig(sheetName: "bunny_idleSad_sheet", frameSize: CGSize(width: 32, height: 32), frameCount: 3, speed: baseFrameDuration),
        "bunny_sleeping_sheet": AnimationConfig(sheetName: "bunny_sleeping_sheet", frameSize: CGSize(width: 32, height: 32), frameCount: 6, speed: baseFrameDuration),
        "bunny_sitting_sheet": AnimationConfig(sheetName: "bunny_sitting_sheet", frameSize: CGSize(width: 32, height: 32), frameCount: 1, speed: baseFrameDuration),
        "bunny_running_sheet": AnimationConfig(sheetName: "bunny_running_sheet", frameSize: CGSize(width: 32, height: 32), frameCount: 8, speed: baseFrameDuration),
        "bunny_jumping_sheet": AnimationConfig(sheetName: "bunny_jumping_sheet", frameSize: CGSize(width: 32, height: 32), frameCount: 11, speed: baseFrameDuration)
    ]

    init(viewModel: PetViewModel) {
        self.viewModel = viewModel
        super.init(frame: NSRect(origin: .zero, size: PET_WINDOW_SIZE))
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor

        viewModel.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateAnimationState()
                self?.updateParticleEffect()
            }
        }.store(in: &cancellables)
        
        updateAnimationState()
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

        if let config = PetView.animationConfigurations[sheetAssetName] {
            return config
        } else {
            print("No animation config found in dictionary for sheet: \(sheetAssetName)")
            let fallbackAssetName = "\(petBaseName)_idleNeutral_sheet" // Fallback to neutral idle of the same pet
            if let fallbackConfig = PetView.animationConfigurations[fallbackAssetName] {
                 print("INFO: Using fallback animation (neutral idle) for \(sheetAssetName): \(fallbackAssetName)")
                 return fallbackConfig
            }
            print("No fallback (neutral idle) animation found either for \(petBaseName).")
            return nil
        }
    }

    private func updateAnimationState() {
        animationTimer?.invalidate()
        animationTimer = nil
        
        var imageLoaded = false

        if let config = getAnimationConfig(for: viewModel.currentPetType, state: viewModel.currentState) {
            if let sheet = NSImage(named: config.sheetName) {
                currentSpriteSheet = sheet
                currentFrameSize = config.frameSize
                currentFrameCount = config.frameCount
                currentAnimationSpeed = config.speed
                currentFrameIndex = 0
                imageLoaded = true

                if currentFrameCount > 1 {
                    animationTimer = Timer.scheduledTimer(withTimeInterval: currentAnimationSpeed, repeats: true) { [weak self] _ in
                        guard let self = self else { return }
                        self.currentFrameIndex = (self.currentFrameIndex + 1) % self.currentFrameCount
                        self.needsDisplay = true
                    }
                }
            } else {
                NSLog("Sprite sheet named '\(config.sheetName)' not found in Assets.xcassets")
            }
        }

        if !imageLoaded {
            let petBaseName = viewModel.currentPetType.rawValue
            let staticImageName = "\(petBaseName)_\(viewModel.currentState.rawValue)"
            
            if let staticImage = NSImage(named: staticImageName) {
                currentSpriteSheet = staticImage
                currentFrameSize = staticImage.size
                currentFrameCount = 1
                currentFrameIndex = 0
                imageLoaded = true
                NSLog("INFO: Loaded static fallback image: \(staticImageName)")
            } else {
                NSLog("Static fallback image named '\(staticImageName)' also not found. Trying default idle for \(petBaseName).")
                let defaultIdleImageName = "\(petBaseName)_idleNeutral"
                if let defaultImage = NSImage(named: defaultIdleImageName) {
                    currentSpriteSheet = defaultImage
                    currentFrameSize = defaultImage.size
                    currentFrameCount = 1
                    currentFrameIndex = 0
                    imageLoaded = true
                    NSLog("INFO: Loaded default static image: \(defaultIdleImageName)")
                } else {
                    NSLog("Default static image '\(defaultIdleImageName)' also not found. No image will be displayed for this state.")
                    currentSpriteSheet = nil
                }
            }
        }
        self.needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if let imageToDraw = currentSpriteSheet, currentFrameSize.width > 0, currentFrameSize.height > 0 {
            let sourceRectX = CGFloat(currentFrameIndex) * currentFrameSize.width
            let sourceRectY: CGFloat = 0
            let sourceRect = NSRect(x: sourceRectX, y: sourceRectY, width: currentFrameSize.width, height: currentFrameSize.height)

            let viewAspectRatio = bounds.width / bounds.height
            let petImageAspectRatio = currentFrameSize.width / currentFrameSize.height
            
            var drawWidth = bounds.width
            var drawHeight = bounds.height

            if viewAspectRatio > petImageAspectRatio {
                drawWidth = drawHeight * petImageAspectRatio
            } else {
                drawHeight = drawWidth / petImageAspectRatio
            }
            
            let maxDisplaySizeFactor: CGFloat = 0.95 // Allow pet to take up to 95% of the smaller dimension of PET_WINDOW_SIZE
            let maxAllowedWidth = PET_WINDOW_SIZE.width * maxDisplaySizeFactor
            let maxAllowedHeight = PET_WINDOW_SIZE.height * maxDisplaySizeFactor

            if drawWidth > maxAllowedWidth || drawHeight > maxAllowedHeight {
                let widthScale = maxAllowedWidth / drawWidth
                let heightScale = maxAllowedHeight / drawHeight
                let scale = min(widthScale, heightScale) // Use the smaller scale to fit both dimensions
                drawWidth *= scale
                drawHeight *= scale
            }

            let petOriginX = (bounds.width - drawWidth) / 2 + viewModel.positionOffset.x
            let petOriginY = (bounds.height - drawHeight) / 2 + viewModel.positionOffset.y
            let destinationRect = NSRect(x: petOriginX, y: petOriginY, width: drawWidth, height: drawHeight)

            imageToDraw.draw(in: destinationRect, from: sourceRect, operation: .sourceOver, fraction: 1.0)
        } else {
            NSColor.systemPurple.withAlphaComponent(0.5).setFill()
            let fallbackRect = bounds.insetBy(dx: bounds.width * 0.25, dy: bounds.height * 0.25)
            let path = NSBezierPath(ovalIn: fallbackRect)
            path.fill()
            ("🐾?" as NSString).draw(at: NSPoint(x: fallbackRect.midX - 10, y: fallbackRect.midY - 8), withAttributes: [.font: NSFont.systemFont(ofSize: 12)])
        }
        
        for particle in particles {
            let particleDisplaySize = PET_WINDOW_SIZE.width * 0.25
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

        // TODO: change this
        switch viewModel.currentState {
        case .idleHappy:
             if currentHappiness > 60 {
                symbol = "heart.fill"
                color = .systemRed
                shouldAnimateParticles = true
            }
        case .sitting:
            // If the pet is sitting and happy, it's likely due to a recent positive interaction.
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
            for _ in 0..<3 {
                let xPos = CGFloat.random(in: bounds.width * 0.4 ... bounds.width * 0.6)
                let yPos = bounds.height * 0.65 + CGFloat.random(in: -5...5)
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
        
        // Use the last calculated drawWidth/Height if available, or approximate
        // For simplicity, we continue approximation. More accurate would be to store the drawn pet rect.
        let petVisualWidth = PET_WINDOW_SIZE.width * 0.8
        let petVisualHeight = PET_WINDOW_SIZE.height * 0.8

        let petClickableRect = NSRect(
            x: (bounds.width - petVisualWidth) / 2 + viewModel.positionOffset.x,
            y: (bounds.height - petVisualHeight) / 2 + viewModel.positionOffset.y,
            width: petVisualWidth,
            height: petVisualHeight
        )

        if petClickableRect.contains(clickLocation) {
            viewModel.petInteracted()
        }
    }
    
    override var acceptsFirstResponder: Bool { return true }
}
