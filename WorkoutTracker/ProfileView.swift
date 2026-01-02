//
//  ProfileView.swift
//  WorkoutTracker
//
//  Created by Carl on 12/30/25.
//
// v10

import SwiftUI
import LocalAuthentication
import CoreData

struct ProfileView: View {
    @AppStorage("userHeight") private var height: String = ""
    @AppStorage("userWeight") private var weight: String = ""
    @AppStorage("userAge") private var age: String = ""
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    
    @State private var showingExportOptions = false
    @State private var showingDeleteAlert = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case height, weight, age
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Form {
                    Section(header: Text("PERSONAL INFORMATION")) {
                        HStack {
                            Text("Height (cm)")
                            Spacer()
                            TextField("170", text: $height)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                                .focused($focusedField, equals: .height)
                        }
                        
                        HStack {
                            Text("Weight (kg)")
                            Spacer()
                            TextField("70", text: $weight)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                                .focused($focusedField, equals: .weight)
                        }
                        
                        HStack {
                            Text("Age")
                            Spacer()
                            TextField("30", text: $age)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                                .focused($focusedField, equals: .age)
                        }
                    }
                    .font(.system(size: 16))
                    
                    Section(header: Text("PREFERENCES"), footer: Text("Get reminded to stay active if you haven't worked out in 3 days.")) {
                        Toggle("Daily Reminders", isOn: $notificationsEnabled)
                            .font(.system(size: 16, weight: .semibold))
                            .tint(AppColors.primaryOrange)
                            .onChange(of: notificationsEnabled) { _, newValue in
                                if newValue {
                                    requestNotificationPermission()
                                }
                            }
                    }
                    
                    Section(header: Text("DATA")) {
                        Button(action: { showingExportOptions = true }) {
                            HStack {
                                Image(systemName: "arrow.down.doc")
                                    .foregroundColor(AppColors.calmingTeal)
                                Text("Export Data")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Button(action: { showingDeleteAlert = true }) {
                            HStack {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                Text("Delete Account")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    Section(header: Text("ABOUT")) {
                        NavigationLink(destination: AboutView()) {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(AppColors.primaryOrange)
                                Text("About & Help")
                            }
                        }
                        
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Invisible tap area to dismiss keyboard
                if focusedField != nil {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            focusedField = nil
                        }
                }
            }
            .navigationTitle("PROFILE")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
            .confirmationDialog("Export Data", isPresented: $showingExportOptions) {
                Button("Export as JSON") {
                    exportData(format: .json)
                }
                Button("Export as CSV") {
                    exportData(format: .csv)
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Delete Account", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("This will permanently delete your account and all workout data. This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                scheduleNotifications()
            }
        }
    }
    
    private func scheduleNotifications() {
        let content = UNMutableNotificationContent()
        content.title = "Time to Move!"
        content.body = "You haven't worked out in a while. Let's get active today!"
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = 9
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "dailyReminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private enum ExportFormat {
        case json, csv
    }
    
    private func exportData(format: ExportFormat) {
        // This would export the data - simplified for now
        print("Exporting data as \(format)")
        // In a real app, you'd generate the file and use UIActivityViewController to share it
    }
    
    private func deleteAccount() {
        // Clear all user data
        height = ""
        weight = ""
        age = ""
        notificationsEnabled = false
        
        // Delete Core Data
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest1: NSFetchRequest<NSFetchRequestResult> = WorkoutEntity.fetchRequest()
        let deleteRequest1 = NSBatchDeleteRequest(fetchRequest: fetchRequest1)
        
        let fetchRequest2: NSFetchRequest<NSFetchRequestResult> = WorkoutPlanEntity.fetchRequest()
        let deleteRequest2 = NSBatchDeleteRequest(fetchRequest: fetchRequest2)
        
        do {
            try context.execute(deleteRequest1)
            try context.execute(deleteRequest2)
            try context.save()
        } catch {
            print("Error deleting data: \(error)")
        }
    }
}

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("ABOUT WORKOUT TRACKER")
                        .font(.system(size: 20, weight: .heavy))
                    
                    Text("Your personal fitness companion for tracking workouts and achieving your health goals. All your data stays private and secure on your device.")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("FEATURES")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Track Progress", description: "Visualize your workout history with heat maps and charts")
                    FeatureRow(icon: "heart.circle", title: "Health Integration", description: "Automatically sync with Apple Health and Apple Watch")
                    FeatureRow(icon: "lock.shield", title: "Privacy First", description: "All data encrypted and stored locally on your device")
                    FeatureRow(icon: "flame", title: "Streak Tracking", description: "Build consistency with daily workout streaks")
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("NEED HELP?")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    Text("If you have questions or need support, please reach out to us at support@workouttracker.app")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("About & Help")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(AppColors.primaryOrange)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
    }
}
