//
//  Project_PawsApp.swift
//  Project Paws
//
//  Created by Marco Josefsen on 25/05/2025.
//

import SwiftUI

@main
struct Project_PawsApp: App {
    // This line connects your existing AppDelegate
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
            }
        }
}
