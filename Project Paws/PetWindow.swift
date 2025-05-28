//
//  PetWindow.swift
//  Project Paws
//
//  Created by Marco Josefsen on 28/05/2025.
//

import Cocoa

class PetWindow: NSWindow {
    init(contentRect: NSRect, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: .borderless, backing: backing, defer: flag)
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating // Keep on top of other windows
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary] // Show on all spaces
        self.hasShadow = false
        self.ignoresMouseEvents = false // Let PetView handle mouse events
    }
}
