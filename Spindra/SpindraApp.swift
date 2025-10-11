//
//  SpindraApp.swift
//  Spindra
//
//  Created by Pawel Kowalewski on 11/10/2025.
//

import SwiftUI

@main
struct SpindraApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            HomeScreenView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - App State
class AppState: ObservableObject {
    @Published var currentScreen: Screen = .home
    
    enum Screen {
        case home
        case training
        case challenge
    }
}
