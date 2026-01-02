//
//  WorkoutTrackerApp.swift
//  WorkoutTracker
//
//  Created by Carl on 12/30/25.
//

import SwiftUI
import CoreData

@main
struct WorkoutTrackerApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var healthKitManager = HealthKitManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(healthKitManager)
                .onAppear {
                    healthKitManager.requestAuthorization()
                }
        }
    }
}
