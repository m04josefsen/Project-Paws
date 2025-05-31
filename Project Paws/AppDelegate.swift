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
    private var selectPetSubmenuForDelegate: NSMenu? // Used in menuNeedsUpdate
    private var cancellables = Set<AnyCancellable>()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupStatusItem()
        setupPetWindow()
        
        petViewModel.$currentPetType.sink { [weak self] _ in
            self?.updateStatusMenu() // Rebuild menu structure if pet type affects it
        }.store(in: &cancellables)
        
        petViewModel.$happinessScore.sink { [weak self] newHappinessScore in
                   NSLog("AppDelegate: $happinessScore changed to \(newHappinessScore), updating menu.")
                   self?.updateStatusMenu()
               }.store(in: &cancellables)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "pawprint.circle.fill", accessibilityDescription: "Project Paws") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "🐾"
            }
        }
        updateStatusMenu() // Initial menu setup
    }
    
    private func updateStatusMenu() {
        NSLog("AppDelegate: updateStatusMenu. ViewModel pet: \(petViewModel.currentPetType.friendlyName)")
        let menu = NSMenu()

        let selectPetMenu = NSMenu(title: "Select Pet")
        selectPetMenu.delegate = self // For dynamic checkmark updates
        self.selectPetSubmenuForDelegate = selectPetMenu

        for petType in PetType.allCases {
            let menuItem = NSMenuItem(title: petType.friendlyName, action: #selector(selectPet(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = petType
            selectPetMenu.addItem(menuItem)
        }
        let selectPetParentItem = NSMenuItem(title: "Select Pet", action: nil, keyEquivalent: "")
        selectPetParentItem.submenu = selectPetMenu
        menu.addItem(selectPetParentItem)

        // Debug menu item for walking
        menu.addItem(NSMenuItem(title: "Make Pet Walk", action: #selector(makePetWalk), keyEquivalent: "j"))
        menu.addItem(NSMenuItem.separator())
        
        let happinessLevel = petViewModel.happinessScore
        let happinessItemTitle = "Happiness: \(happinessLevel)/100"
        let happinessItem = NSMenuItem(title: happinessItemTitle, action: nil, keyEquivalent: "")
        happinessItem.isEnabled = false // Make it non-interactive, just for display
        menu.addItem(happinessItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Project Paws", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }

    private func setupPetWindow() {
        NSLog("AppDelegate: setupPetWindow - STARTING")
        
        guard let mainScreen = NSScreen.main else {
            NSLog("Error: Could not find main screen.")
            return
        }
        
        let screenFrame = mainScreen.frame

        let screenCenterX = screenFrame.origin.x + (screenFrame.width / 2)
        let petDesiredCenterX = screenCenterX + HORIZONTAL_OFFSET_FOR_PET_CENTER
        let windowX = petDesiredCenterX - (PET_WINDOW_SIZE.width / 2)

        let petWindowTopY = (screenFrame.origin.y + screenFrame.height) - VERTICAL_OFFSET_FROM_SCREEN_TOP
        let windowY = petWindowTopY - PET_WINDOW_SIZE.height
        
        let petWindowRect = NSRect(x: windowX, y: windowY, width: PET_WINDOW_SIZE.width, height: PET_WINDOW_SIZE.height)
        
        NSLog("AppDelegate: mainScreen.frame = \(screenFrame)")
        NSLog("AppDelegate: Calculated petWindowRect = \(petWindowRect)")
        
        petWindow = PetWindow(contentRect: petWindowRect, backing: .buffered, defer: false)
        
        let petView = PetView(viewModel: petViewModel)
        petWindow?.contentView = petView
        petWindow?.makeKeyAndOrderFront(nil)
        
        NSLog("AppDelegate: setupPetWindow - FINISHED")
    }
    
    // NSMenuDelegate method to update checkmarks just before menu is shown
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === self.selectPetSubmenuForDelegate else { return }

        NSLog("AppDelegate: menuNeedsUpdate for '\(menu.title)'. Current pet: \(petViewModel.currentPetType.friendlyName)")
        
        for item in menu.items {
            if let petType = item.representedObject as? PetType {
                item.state = (petViewModel.currentPetType == petType) ? .on : .off
                if item.state == .on {
                     NSLog("AppDelegate: menuNeedsUpdate - Checkmarking \(petType.friendlyName)")
                }
            }
        }
    }

    @objc func selectPet(_ sender: NSMenuItem) {
        if let petType = sender.representedObject as? PetType {
            petViewModel.changePet(to: petType)
        }
    }
    
    // Debug action
    @objc func makePetWalk() {
        petViewModel.decideToWalk()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        petViewModel.performCleanup()
    }
}
