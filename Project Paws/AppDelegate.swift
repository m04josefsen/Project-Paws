//
//  AppDelegate.swift
//  Project Paws
//
//  Created by Marco Josefsen on 28/05/2025.
//

import Cocoa
import Combine

import Foundation // For NSLog

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var petWindow: PetWindow?
    private var petViewModel = PetViewModel()
    
    override init() { // Override init to test even earlier logging
        super.init()
        NSLog("DEBUG-NSLog: AppDelegate init CALLED")
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupStatusItem()
        setupPetWindow()

        
        // Observe pet type changes to update menu potentially
        petViewModel.$currentPetType.sink { [weak self] _ in
            self?.updateStatusMenu() // Rebuild menu if pet type affects it (e.g. checkmark)
        }.store(in: &cancellables) // Need a place to store cancellables in AppDelegate
    }
    
    private var cancellables = Set<AnyCancellable>()

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            // Use a generic pet icon for the menu bar
            if let image = NSImage(systemSymbolName: "pawprint.circle.fill", accessibilityDescription: "Project Paws") {
                 image.isTemplate = true
                 button.image = image
            } else {
                button.title = "🐾"
            }
        }
        updateStatusMenu()
    }
    
    private func updateStatusMenu() {
        let menu = NSMenu()

        // Pet selection submenu
        let selectPetMenu = NSMenu(title: "Select Pet")
        for petType in PetType.allCases {
            let menuItem = NSMenuItem(title: petType.friendlyName, action: #selector(selectPet(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = petType
            if petViewModel.currentPetType == petType {
                menuItem.state = .on // Checkmark current pet
            }
            selectPetMenu.addItem(menuItem)
        }
        let selectPetParentItem = NSMenuItem(title: "Select Pet", action: nil, keyEquivalent: "")
        selectPetParentItem.submenu = selectPetMenu
        menu.addItem(selectPetParentItem)

        menu.addItem(NSMenuItem(title: "Feed Pet", action: #selector(feedPet), keyEquivalent: "f"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Project Paws", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func setupPetWindow() {
         guard let mainScreen = NSScreen.main else {
            print("Error: Could not find main screen.")
            return
        }
        
        let screenRect = mainScreen.frame
        // Position at top-center. Adjust Y if you want it lower than the absolute top edge.
        // Consider the menu bar height. visibleFrame might be better.
        let visibleFrame = mainScreen.visibleFrame
        let windowX = visibleFrame.origin.x + (visibleFrame.width - PET_WINDOW_SIZE.width) / 2
        // Position it at the very top of the visible frame, then offset slightly if needed by NOTCH_AREA_OFFSET
        let windowY = visibleFrame.origin.y + visibleFrame.height - PET_WINDOW_SIZE.height - NOTCH_AREA_OFFSET
        
        let petWindowRect = NSRect(x: windowX, y: windowY, width: PET_WINDOW_SIZE.width, height: PET_WINDOW_SIZE.height)
    
        petWindow = PetWindow(contentRect: petWindowRect, backing: .buffered, defer: false)
        
        let petView = PetView(viewModel: petViewModel)
        petWindow?.contentView = petView
        petWindow?.makeKeyAndOrderFront(nil)
        // petWindow?.orderFrontRegardless() // Ensure it's visible
    }

    @objc func selectPet(_ sender: NSMenuItem) {
        if let petType = sender.representedObject as? PetType {
            petViewModel.changePet(to: petType)
            // The menu will be updated via the Combine sink observing currentPetType
        }
    }

    @objc func feedPet() {
        petViewModel.feedPet()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up timers or other resources if necessary
        petViewModel.performCleanup()
    }
}
