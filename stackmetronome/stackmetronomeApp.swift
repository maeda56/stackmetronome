//
//  stackmetronomeApp.swift
//  stackmetronome
//
//  Created by 前田哲徳 on 2025/03/06.
//

import SwiftUI

@main
struct StackMetronomeApp: App {
    @StateObject private var stackStore = StackStore()
    @StateObject private var metronomeEngine = MetronomeEngine()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(stackStore)
                .environmentObject(metronomeEngine)
                .preferredColorScheme(.light)
        }
    }
}
