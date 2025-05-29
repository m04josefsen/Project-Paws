//
//  AppDelegate.swift
//  Project Paws
//
//  Created by Marco Josefsen on 28/05/2025.
//

import Cocoa
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var petWindow: PetWindow?
    private var petViewModel = PetViewModel()
    
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
        NSLog("AppDelegate (Adaptor): setupPetWindow - STARTING")
        
        guard let mainScreen = NSScreen.main else {
            NSLog("Error: Could not find main screen.")
            return
        }
        
        let screenFrame = mainScreen.frame

        // Calculate X-coordinate for the pet window's origin (left edge):
        // 1. Find the desired center X-point for your pet:
        let screenCenterX = screenFrame.origin.x + (screenFrame.width / 2)
        let petDesiredCenterX = screenCenterX + HORIZONTAL_OFFSET_FOR_PET_CENTER
        // 2. Calculate the window's origin X based on its desired center:
        let windowX = petDesiredCenterX - (PET_WINDOW_SIZE.width / 2)

        let petWindowTopY = (screenFrame.origin.y + screenFrame.height) - VERTICAL_OFFSET_FROM_SCREEN_TOP
        let windowY = petWindowTopY - PET_WINDOW_SIZE.height 
        
        let petWindowRect = NSRect(x: windowX, y: windowY, width: PET_WINDOW_SIZE.width, height: PET_WINDOW_SIZE.height)
        
        NSLog("AppDelegate (Adaptor): mainScreen.frame = \(screenFrame)")
        NSLog("AppDelegate (Adaptor): Calculated petWindowRect = \(petWindowRect)")
        
        petWindow = PetWindow(contentRect: petWindowRect, backing: .buffered, defer: false)
        
        let petView = PetView(viewModel: petViewModel)
        petWindow?.contentView = petView
        petWindow?.makeKeyAndOrderFront(nil)
        
        NSLog("AppDelegate (Adaptor): setupPetWindow - FINISHED")
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
        petViewModel.performCleanup()
    }
}
