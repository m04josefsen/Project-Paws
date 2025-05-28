//
//  PetView.swift
//  Project Paws
//
//  Created by Marco Josefsen on 28/05/2025.
//

import Cocoa
import Combine

class PetView: NSView {
    private var viewModel: PetViewModel
    private var cancellables = Set<AnyCancellable>()

    // For particle effects
    private var particleTimer: Timer?
    private var particles: [(point: CGPoint, symbol: String, color: NSColor, alpha: CGFloat, dy: CGFloat)] = []


    init(viewModel: PetViewModel) {
        self.viewModel = viewModel
        super.init(frame: NSRect(origin: .zero, size: PET_WINDOW_SIZE))
        self.wantsLayer = true // Important for performance and some drawing aspects
        self.layer?.backgroundColor = NSColor.clear.cgColor

        // Subscribe to ViewModel changes
        viewModel.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { // Ensure UI updates are on the main thread
                 self?.needsDisplay = true
                 self?.updateParticleEffect()
            }
        }.store(in: &cancellables)
        
        updateParticleEffect() // Initial setup
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Clear background (already transparent due to window settings)
        // NSColor.clear.set()
        // dirtyRect.fill()

        let petImageName = viewModel.currentPetType.rawValue
        let petSize = min(bounds.width, bounds.height) * 0.6
        let petOriginX = (bounds.width - petSize) / 2 + viewModel.positionOffset.x
        let petOriginY = (bounds.height - petSize) / 2 + viewModel.positionOffset.y // Allow vertical movement for peeking from top

        // Draw Pet
        if let petSymbolImage = NSImage(systemSymbolName: petImageName, accessibilityDescription: viewModel.currentPetType.friendlyName) {
            var symbolConfig = NSImage.SymbolConfiguration(pointSize: petSize, weight: .regular)
            if viewModel.actionState == .sleeping {
                 // Could use a different symbol or tint for sleeping
            }
            
            // Tint based on mood (subtle)
            var tintColor = NSColor.labelColor
            if viewModel.mood == .sad {
                tintColor = NSColor.systemGray
            } else if viewModel.mood == .happy {
                tintColor = NSColor.systemGreen // Or a more vibrant color
            }
            
            if #available(macOS 11.0, *) { // NSImage.SymbolConfiguration is available from macOS 11
                symbolConfig = symbolConfig.applying(.init(paletteColors: [tintColor]))
                if let tintedImage = petSymbolImage.withSymbolConfiguration(symbolConfig) {
                     tintedImage.draw(in: NSRect(x: petOriginX, y: petOriginY, width: petSize, height: petSize))
                } else {
                    petSymbolImage.draw(in: NSRect(x: petOriginX, y: petOriginY, width: petSize, height: petSize))
                }
            } else {
                 petSymbolImage.draw(in: NSRect(x: petOriginX, y: petOriginY, width: petSize, height: petSize))
            }
        } else { // Fallback drawing
            NSColor.gray.setFill()
            let fallbackRect = NSRect(x: petOriginX, y: petOriginY, width: petSize, height: petSize)
            context.fill(fallbackRect)
            let attrs = [NSAttributedString.Key.font: NSFont.systemFont(ofSize: 10), NSAttributedString.Key.foregroundColor: NSColor.black]
            ("Pet" as NSString).draw(at: CGPoint(x: petOriginX + 5, y: petOriginY + 5), withAttributes: attrs)
        }
        
        // Draw particles (hearts, zzz, broken hearts)
        for particle in particles {
            let particleSize = petSize * 0.3
            if let particleSymbol = NSImage(systemSymbolName: particle.symbol, accessibilityDescription: particle.symbol) {
                let symbolConfig = NSImage.SymbolConfiguration(pointSize: particleSize, weight: .regular)
                                    .applying(.init(paletteColors: [particle.color.withAlphaComponent(particle.alpha)]))
                if let tintedImage = particleSymbol.withSymbolConfiguration(symbolConfig) {
                    tintedImage.draw(at: particle.point, from: .zero, operation: .sourceOver, fraction: particle.alpha)
                }
            }
        }


        // Draw Eyes if sleeping (simple lines)
        if viewModel.actionState == .sleeping {
            NSColor.labelColor.setStroke()
            let eyeY = petOriginY + petSize * 0.6
            let eyePathLeft = NSBezierPath()
            eyePathLeft.move(to: CGPoint(x: petOriginX + petSize * 0.25, y: eyeY))
            eyePathLeft.line(to: CGPoint(x: petOriginX + petSize * 0.4, y: eyeY))
            eyePathLeft.lineWidth = 2.0
            eyePathLeft.stroke()

            let eyePathRight = NSBezierPath()
            eyePathRight.move(to: CGPoint(x: petOriginX + petSize * 0.6, y: eyeY))
            eyePathRight.line(to: CGPoint(x: petOriginX + petSize * 0.75, y: eyeY))
            eyePathRight.lineWidth = 2.0
            eyePathRight.stroke()
        }
    }
    
    private func updateParticleEffect() {
        particleTimer?.invalidate()
        particles.removeAll()

        var symbol = ""
        var color = NSColor.red
        var shouldAnimate = false

        switch viewModel.actionState {
        case .showingLove:
            symbol = "heart.fill"
            color = .systemRed
            shouldAnimate = true
        case .showingSadness:
            symbol = "heart.slash.fill" // Or "exclamationmark.triangle.fill"
            color = .systemGray
            shouldAnimate = true
        case .sleeping:
            symbol = "zzz"
            color = .systemBlue
            shouldAnimate = true
        default:
            break
        }

        if shouldAnimate && !symbol.isEmpty {
            // Add initial particles
            for _ in 0..<3 {
                let xPos = CGFloat.random(in: bounds.width * 0.2 ... bounds.width * 0.8)
                let yPos = bounds.height * 0.7 // Start above pet
                particles.append((CGPoint(x: xPos, y: yPos), symbol, color, 1.0, CGFloat.random(in: 0.5...1.5)))
            }
            
            particleTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                var newParticles: [(CGPoint, String, NSColor, CGFloat, CGFloat)] = []
                for var particle in self.particles {
                    particle.point.y += particle.dy // Move up or down based on dy
                    particle.alpha -= 0.05 // Fade out
                    if particle.alpha > 0.1 { // Keep if visible
                        newParticles.append(particle)
                    }
                }
                self.particles = newParticles
                if self.particles.isEmpty {
                    self.particleTimer?.invalidate()
                }
                self.needsDisplay = true
            }
        }
        needsDisplay = true
    }


    override func mouseDown(with event: NSEvent) {
        // Check if click is on the pet area (approximate)
        let clickLocation = convert(event.locationInWindow, from: nil)
        let petRect = NSRect(x: (bounds.width - PET_WINDOW_SIZE.width*0.6) / 2 + viewModel.positionOffset.x,
                             y: (bounds.height - PET_WINDOW_SIZE.height*0.6) / 2 + viewModel.positionOffset.y,
                             width: PET_WINDOW_SIZE.width*0.6,
                             height: PET_WINDOW_SIZE.height*0.6)

        if petRect.contains(clickLocation) {
            viewModel.petInteracted()
        }
    }
    
    override var acceptsFirstResponder: Bool { return true } // To handle mouse down
}
