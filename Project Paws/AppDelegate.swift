//
//  AppDelegate.swift
//  Project Paws
//
//  Created by Marco Josefsen on 28/05/2025.
//

import Cocoa
import Combine

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var petWindow: PetWindow?
    private var petViewModel = PetViewModel()
    private var selectPetSubmenuForDelegate: NSMenu?
    
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
        NSLog("AppDelegate: updateStatusMenu called. ViewModel's currentPetType: \(petViewModel.currentPetType.friendlyName)")
        let menu = NSMenu() // This is the main menu for the status item

        // Pet selection submenu
        let selectPetMenu = NSMenu(title: "Select Pet")
        selectPetMenu.delegate = self
        self.selectPetSubmenuForDelegate = selectPetMenu // Store the reference

        for petType in PetType.allCases {
            let menuItem = NSMenuItem(title: petType.friendlyName, action: #selector(selectPet(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = petType
            selectPetMenu.addItem(menuItem)
        }
        let selectPetParentItem = NSMenuItem(title: "Select Pet", action: nil, keyEquivalent: "")
        selectPetParentItem.submenu = selectPetMenu
        menu.addItem(selectPetParentItem)

        // menu.addItem(NSMenuItem(title: "Feed Pet", action: #selector(feedPet), keyEquivalent: "f"))
        // TODO: For debugging
        menu.addItem(NSMenuItem(title: "Make pet walk", action: #selector(makePetWalk), keyEquivalent: "j"))
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
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === self.selectPetSubmenuForDelegate else {
            return
        }

        NSLog("AppDelegate: menuNeedsUpdate for '\(menu.title)'. Current ViewModel pet: \(petViewModel.currentPetType.friendlyName)")
        
        for item in menu.items {
            if let petType = item.representedObject as? PetType {
                // Now 'item' is the NSMenuItem, and 'petType' is the unwrapped PetType
                if petViewModel.currentPetType == petType {
                    item.state = .on // Use 'item' directly
                    NSLog("AppDelegate: menuNeedsUpdate - Checkmarking \(petType.friendlyName)")
                } else {
                    item.state = .off
                }
            }
        }
    }

    @objc func selectPet(_ sender: NSMenuItem) {
        if let petType = sender.representedObject as? PetType {
            petViewModel.changePet(to: petType)
            // The menu will be updated via the Combine sink observing currentPetType
        }
    }

    // Commented out due to buttion removed
    /*
    @objc func feedPet() {
        petViewModel.feedPet()
    }
     */
    
    // TODO: For debugging
    @objc func makePetWalk() {
        petViewModel.decideToWalk()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        petViewModel.performCleanup()
    }
}
