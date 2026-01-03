//
//  ai_glassesApp.swift
//  ai-glasses
//
//  Created by Kirill Markin on 03/01/2026.
//

import SwiftUI
import MWDATCore

@main
struct ai_glassesApp: App {
    
    init() {
        do {
            try Wearables.configure()
        } catch {
            fatalError("Failed to configure Wearables SDK: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
