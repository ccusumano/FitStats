//
//  HomeView.swift
//  WorkoutTracker
//
//  Created by Carl on 12/30/25.
//
// v7

import SwiftUI
import CoreData

struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \WorkoutEntity.date, ascending: false)],
        animation: .default)
    private var workouts: FetchedResults<WorkoutEntity>
    
    @State private var showConfetti = false
    @Binding var selectedTab: Int
    @Binding var selectedVisualization: Int
    @Binding var selectedMonth: Int
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Today's Status
                    todayCard
                    
                    // Current Streak
                    streakCard
                    
                    // Quick Stats
                    statsGrid
                    
                    // Achievement Animations
                    if showConfetti {
                        ConfettiView()
                    }
                }
                .padding()
            }
            .navigationTitle("TODAY")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemBackground))
            .onAppear {
                checkAchievements()
            }
        }
    }
    
    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TODAY'S WORKOUT")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.secondary)
            
            if hasWorkedOutToday {
                HStack(alignment: .top) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(AppColors.secondaryGreen)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Great Job!")
                            .font(.system(size: 24, weight: .heavy))
                            .foregroundColor(.primary)
                        Text("You completed your workout today")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        // Show today's workouts
                        ForEach(todaysWorkouts, id: \.id) { workout in
                            HStack {
                                Text(workout.type ?? "Workout")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(colorForWorkoutType(workout.type ?? ""))
                                Text("â€¢")
                                    .foregroundColor(.secondary)
                                Text("\(Int(workout.duration)) min")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    Spacer()
                }
            } else {
                HStack {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 40))
                        .foregroundColor(AppColors.primaryOrange)
                    
                    VStack(alignment: .leading) {
                        Text("Let's Move!")
                            .font(.system(size: 24, weight: .heavy))
                            .foregroundColor(.primary)
                        Text("No workout logged yet today")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .padding()
        .background(cardBackground)
        .cornerRadius(16)
    }
    
    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CURRENT STREAK")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.secondary)
            
            HStack {
                Image(systemName: "flame.fill")
                    .font(.system(size: 50))
                    .foregroundColor(AppColors.motivationalPink)
                
                VStack(alignment: .leading) {
                    Text("\(currentStreak)")
                        .font(.system(size: 48, weight: .heavy))
                        .foregroundColor(AppColors.motivationalPink)
                    Text(currentStreak == 1 ? "Day" : "Days")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .padding()
        .background(cardBackground)
        .cornerRadius(16)
    }
    
    private var statsGrid: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                StatCard(
                    title: "THIS YEAR",
                    value: "\(workoutsThisYear)",
                    subtitle: "Workouts",
                    color: AppColors.calmingTeal,
                    action: { selectedTab = 2; selectedVisualization = 0 }
                )
                
                StatCard(
                    title: "COMPLETION",
                    value: "\(Int(yearCompletionPercentage))%",
                    subtitle: "Of days",
                    color: AppColors.secondaryGreen,
                    action: nil
                )
            }
            
            HStack(spacing: 16) {
                StatCard(
                    title: "THIS MONTH",
                    value: "\(workoutsThisMonth)",
                    subtitle: "Workouts",
                    color: AppColors.primaryOrange,
                    action: {
                        selectedVisualization = 0
                        selectedMonth = Calendar.current.component(.month, from: Date())
                        selectedTab = 2
                    }
                )
                
                StatCard(
                    title: "THIS WEEK",
                    value: "\(workoutsThisWeek)",
                    subtitle: "Workouts",
                    color: AppColors.motivationalPink,
                    action: nil
                )
            }
        }
    }
    
    @Environment(\.colorScheme) var colorScheme
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(white: 0.15) : AppColors.lightGray
    }
    
    // MARK: - Computed Properties
    
    private var todaysWorkouts: [WorkoutEntity] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return workouts.filter { workout in
            guard let date = workout.date else { return false }
            return calendar.isDate(date, inSameDayAs: today)
        }
    }
    
    private var hasWorkedOutToday: Bool {
        !todaysWorkouts.isEmpty
    }
    
    private func colorForWorkoutType(_ type: String) -> Color {
        switch type.lowercased() {
        case "cardio": return AppColors.cardioColor
        case "walking": return AppColors.walkingColor
        case "strength": return AppColors.strengthColor
        case "cycling": return AppColors.cyclingColor
        case "flexibility": return AppColors.flexibilityColor
        case "volleyball": return AppColors.volleyballColor
        case "sports": return AppColors.sportsColor
        case "hiit": return AppColors.hiitColor
        case "yoga": return AppColors.yogaColor
        case "golf": return AppColors.golfColor
        default: return AppColors.primaryOrange
        }
    }
    
    private var currentStreak: Int {
        guard !workouts.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var currentDate = today
        var restDayUsed = false
        
        while true {
            let hasWorkout = workouts.contains { workout in
                guard let date = workout.date else { return false }
                return calendar.isDate(date, inSameDayAs: currentDate)
            }
            
            if hasWorkout {
                streak += 1
                restDayUsed = false
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
            } else if !restDayUsed {
                // Allow one rest day
                restDayUsed = true
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
            } else {
                break
            }
        }
        
        return streak
    }
    
    private var workoutsThisYear: Int {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        return workouts.filter { workout in
            guard let date = workout.date else { return false }
            return calendar.component(.year, from: date) == year
        }.count
    }
    
    private var workoutsThisMonth: Int {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: Date())
        let year = calendar.component(.year, from: Date())
        return workouts.filter { workout in
            guard let date = workout.date else { return false }
            return calendar.component(.month, from: date) == month &&
                   calendar.component(.year, from: date) == year
        }.count
    }
    
    private var workoutsThisWeek: Int {
        let calendar = Calendar.current
        let weekOfYear = calendar.component(.weekOfYear, from: Date())
        let year = calendar.component(.year, from: Date())
        return workouts.filter { workout in
            guard let date = workout.date else { return false }
            return calendar.component(.weekOfYear, from: date) == weekOfYear &&
                   calendar.component(.year, from: date) == year
        }.count
    }
    
    private var yearCompletionPercentage: Double {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        let daysSinceStart = calendar.dateComponents([.day], from: startOfYear, to: Date()).day ?? 0
        
        guard daysSinceStart > 0 else { return 0 }
        return (Double(workoutsThisYear) / Double(daysSinceStart + 1)) * 100
    }
    
    private func checkAchievements() {
        // Check for 7-day week
        if workoutsThisWeek >= 7 {
            showConfetti = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showConfetti = false
            }
        }
        
        // Check for >50% month completion
        let calendar = Calendar.current
        let daysInMonth = calendar.range(of: .day, in: .month, for: Date())?.count ?? 30
        if Double(workoutsThisMonth) / Double(daysInMonth) > 0.5 {
            showConfetti = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showConfetti = false
            }
        }
        
        // Check for >50% year completion
        if yearCompletionPercentage > 50 {
            showConfetti = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showConfetti = false
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let action: (() -> Void)?
    
    @Environment(\.colorScheme) var colorScheme
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(white: 0.15) : AppColors.lightGray
    }
    
    var body: some View {
        Button(action: {
            action?()
        }) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundColor(color)
                
                Text(subtitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(cardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(action == nil)
    }
}

struct ConfettiView: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            ForEach(0..<50, id: \.self) { _ in
                Circle()
                    .fill([AppColors.primaryOrange, AppColors.secondaryGreen, AppColors.motivationalPink, AppColors.calmingTeal].randomElement() ?? .orange)
                    .frame(width: CGFloat.random(in: 5...15))
                    .position(
                        x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                        y: animate ? UIScreen.main.bounds.height + 100 : -100
                    )
                    .animation(
                        Animation.linear(duration: Double.random(in: 2...4))
                            .repeatCount(1, autoreverses: false),
                        value: animate
                    )
            }
        }
        .onAppear {
            animate = true
        }
    }
}
