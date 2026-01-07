//
//  ContentView.swift
//  WorkoutTracker
//
//  Created by Carl on 12/30/25.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var selectedVisualization = 0
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab, selectedVisualization: $selectedVisualization, selectedMonth: $selectedMonth)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            ChatView()
                .tabItem {
                    Label("AI Chat", systemImage: "message.fill")
                }
                .tag(1)
            
            HistoryView(selectedVisualization: $selectedVisualization, selectedMonth: $selectedMonth)
                .tabItem {
                    Label("History", systemImage: "chart.bar.fill")
                }
                .tag(2)
            
            SavedWorkoutsView()
                .tabItem {
                    Label("Workouts", systemImage: "list.bullet.clipboard.fill")
                }
                .tag(3)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(4)
        }
        .accentColor(AppColors.primaryOrange)
    }
}

// App Color Scheme
struct AppColors {
    static let primaryOrange = Color(hex: "#F3BA60")
    static let secondaryGreen = Color(hex: "#A8E6A1")
    static let motivationalPink = Color(hex: "#FF6B6B")
    static let darkGray = Color(hex: "#202022")
    static let lightGray = Color(hex: "#F6F6F6")
    static let calmingTeal = Color(hex: "#025D93")
    
    // Workout type colors
    static let cardioColor = Color(hex: "#00BCD4") // sky blue
    static let walkingColor = Color(hex: "#4CAF50") // green
    static let strengthColor = Color(hex: "#025D93") // dark blue
    static let cyclingColor = Color(hex: "#C08CA7") // light purple
    static let flexibilityColor = Color(hex: "#A8E6A1")
    static let volleyballColor = Color(hex: "#F0DE1F") //yellow-ish
    static let sportsColor = Color(hex: "#FF6B6B")
    static let hiitColor = Color(hex: "#FF60FF") //magenta
    static let yogaColor = Color(hex: "#F3BA60")
    static let golfColor = Color(hex: "#8BC34A")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
