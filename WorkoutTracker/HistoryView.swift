//
//  HistoryView.swift
//  WorkoutTracker
//
//  Created by Carl on 12/30/25.
//
// v21

import SwiftUI
import CoreData

struct HistoryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \WorkoutEntity.date, ascending: false)],
        animation: .default)
    private var workouts: FetchedResults<WorkoutEntity>
    
    @Binding var selectedVisualization: Int
    @Binding var selectedMonth: Int
    @State private var selectedWorkoutType = "All"
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedWorkouts: [WorkoutEntity]?
    @State private var showingWorkoutDetail = false
    
    let visualizations = ["Heat Map", "Stats", "Progress"]
    let workoutTypes = ["All", "Cardio", "Walking", "Strength", "Cycling", "Flexibility", "Volleyball", "Sports", "HIIT", "Yoga", "Golf"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filters Row - Workout Type and Year
                HStack(spacing: 12) {
                    // Filter by Type (Dropdown)
                    Menu {
                        ForEach(workoutTypes, id: \.self) { type in
                            Button(type) {
                                selectedWorkoutType = type
                            }
                        }
                    } label: {
                        HStack {
                            Text("Type: \(selectedWorkoutType)")
                                .font(.system(size: 14, weight: .semibold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppColors.primaryOrange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    
                    // Year Selector
                    Menu {
                        ForEach(availableYears, id: \.self) { year in
                            Button(String(year)) {
                                selectedYear = year
                            }
                        }
                    } label: {
                        HStack {
                            Text("Year: \(String(selectedYear))")
                                .font(.system(size: 14, weight: .semibold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppColors.calmingTeal)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 5)
                
                // Visualization Selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<visualizations.count, id: \.self) { index in
                            Button(action: { selectedVisualization = index }) {
                                Text(visualizations[index])
                                    .font(.system(size: 14, weight: .bold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedVisualization == index ? AppColors.calmingTeal : Color.clear)
                                    .foregroundColor(selectedVisualization == index ? .white : AppColors.calmingTeal)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(AppColors.calmingTeal, lineWidth: 2)
                                    )
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                
                Divider()
                
                // Content
                ScrollView {
                    switch selectedVisualization {
                    case 0:
                        YearHeatMapView(workouts: filteredWorkouts, onDayTapped: handleDayTapped, scrollToMonth: selectedMonth, year: selectedYear)
                    case 1:
                        StatsView(workouts: filteredWorkouts, year: selectedYear)
                    case 2:
                        ProgressChartView(workouts: filteredWorkouts, year: selectedYear)
                    default:
                        EmptyView()
                    }
                }
            }
            .navigationTitle("HISTORY")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingWorkoutDetail) {
                if let workouts = selectedWorkouts {
                    if workouts.count == 1 {
                        WorkoutDetailSheet(workout: workouts.first!)
                    } else {
                        MultiWorkoutSheet(workouts: workouts)
                    }
                }
            }
        }
    }
    
    var filteredWorkouts: [WorkoutEntity] {
        var filtered = Array(workouts)
        
        let calendar = Calendar.current
        
        // Filter by year
        filtered = filtered.filter { workout in
            guard let date = workout.date else { return false }
            return calendar.component(.year, from: date) == selectedYear
        }
        
        // Filter by type (including tags)
        if selectedWorkoutType != "All" {
            filtered = filtered.filter { workout in
                let matchesType = workout.type?.lowercased() == selectedWorkoutType.lowercased()
                let matchesTags = workout.tagArray.contains { $0.lowercased() == selectedWorkoutType.lowercased() }
                return matchesType || matchesTags
            }
        }
        
        return filtered
    }
    
    var availableYears: [Int] {
        let calendar = Calendar.current
        let years = Set(workouts.compactMap { workout -> Int? in
            guard let date = workout.date else { return nil }
            return calendar.component(.year, from: date)
        })
        return years.sorted(by: >)  // Most recent first
    }
    
    private func handleDayTapped(_ workouts: [WorkoutEntity]) {
        selectedWorkouts = workouts
        showingWorkoutDetail = true
    }
}

// MARK: - Year Heat Map (12 Mini Calendars)
struct YearHeatMapView: View {
    let workouts: [WorkoutEntity]
    let onDayTapped: ([WorkoutEntity]) -> Void
    let scrollToMonth: Int
    let year: Int
    
    @State private var scrollViewProxy: ScrollViewProxy? = nil
    
    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 20) {
                /*
                 Text("HEAT MAP")
                    .font(.system(size: 20, weight: .heavy))
                    .padding(.horizontal)
                */
                ForEach(1...12, id: \.self) { month in
                    MiniMonthCalendar(month: month, year: year, workouts: workouts, onDayTapped: onDayTapped)
                        .padding(.horizontal)
                        .id(month)
                }
                
                // Legend
                WorkoutLegend()
                    .padding()
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    proxy.scrollTo(scrollToMonth, anchor: .top)
                }
            }
        }
    }
}

// MARK: - Workout Legend (Reusable)
struct WorkoutLegend: View {
    let items: [(String, Color)] = [
        ("Cardio", AppColors.cardioColor),
        ("Walking", AppColors.walkingColor),
        ("Strength", AppColors.strengthColor),
        ("Cycling", AppColors.cyclingColor),
        ("Flexibility", AppColors.flexibilityColor),
        ("Volleyball", AppColors.volleyballColor),
        ("Sports", AppColors.sportsColor),
        ("HIIT", AppColors.hiitColor),
        ("Yoga", AppColors.yogaColor),
        ("Golf", AppColors.golfColor)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LEGEND")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(items, id: \.0) { item in
                    LegendItem(color: item.1, label: item.0)
                }
                
                HStack {
                    SmallCheckerboardIcon()
                    Text("Multiple")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Mini Month Calendar
struct MiniMonthCalendar: View {
    let month: Int
    let year: Int
    let workouts: [WorkoutEntity]
    let onDayTapped: ([WorkoutEntity]) -> Void
    
    private var monthName: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM"
        let date = Calendar.current.date(from: DateComponents(year: year, month: month, day: 1))!
        return dateFormatter.string(from: date)
    }
    
    private var daysInMonth: Int {
        let date = Calendar.current.date(from: DateComponents(year: year, month: month, day: 1))!
        return Calendar.current.range(of: .day, in: .month, for: date)?.count ?? 30
    }
    
    private var firstWeekday: Int {
        let date = Calendar.current.date(from: DateComponents(year: year, month: month, day: 1))!
        return Calendar.current.component(.weekday, from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(monthName.uppercased())
                .font(.system(size: 16, weight: .bold))
            
            // Weekday headers
            HStack(spacing: 4) {
                ForEach(Calendar.current.shortWeekdaySymbols, id: \.self) { day in
                    Text(String(day.prefix(1)))
                        .font(.system(size: 10, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.secondary)
                }
            }
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(0..<(firstWeekday - 1), id: \.self) { index in
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 32)
                        .id("empty-\(month)-\(index)")
                }
                
                ForEach(1...daysInMonth, id: \.self) { day in
                    let date = Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
                    let dayWorkouts = workoutsForDate(date)
                    
                    ZStack {
                        if dayWorkouts.count > 1 {
                            CheckerboardPattern(size: 32)
                        } else {
                            Rectangle()
                                .fill(colorForDate(date, dayWorkouts))
                        }
                        
                        Text("\(day)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(dayWorkouts.isEmpty ? .primary : .white)
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 32, maxHeight: 32)
                    .cornerRadius(4)
                    .onTapGesture {
                        if !dayWorkouts.isEmpty {
                            onDayTapped(dayWorkouts)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func workoutsForDate(_ date: Date) -> [WorkoutEntity] {
        let calendar = Calendar.current
        return workouts.filter { workout in
            guard let workoutDate = workout.date else { return false }
            return calendar.isDate(workoutDate, inSameDayAs: date)
        }
    }
    
    private func colorForDate(_ date: Date, _ dayWorkouts: [WorkoutEntity]) -> Color {
        if date > Date() { return Color.gray.opacity(0.1) }
        
        guard let workout = dayWorkouts.first else {
            return Color.gray.opacity(0.2)
        }
        
        return colorForWorkoutType(workout.type ?? "")
    }
}

// MARK: - Checkerboard Pattern
struct CheckerboardPattern: View {
    let size: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, canvasSize in
                let width = canvasSize.width
                let height = canvasSize.height
                guard width > 0 && height > 0 else { return }
                
                let squareSize = min(width, height) / 4
                for row in 0..<4 {
                    for col in 0..<4 {
                        if (row + col) % 2 == 0 {
                            let rect = CGRect(
                                x: CGFloat(col) * squareSize,
                                y: CGFloat(row) * squareSize,
                                width: squareSize,
                                height: squareSize
                            )
                            context.fill(Path(rect), with: .color(.gray.opacity(0.3)))
                        }
                    }
                }
            }
            .background(Color.white.opacity(0.8))
        }
    }
}

// MARK: - Small Checkerboard Icon (for Legend)
struct SmallCheckerboardIcon: View {
    var body: some View {
        Canvas { context, size in
            // Background
            context.fill(
                Path(CGRect(x: 0, y: 0, width: size.width, height: size.height)),
                with: .color(Color.white.opacity(0.8))
            )
            
            // 4x4 checkerboard pattern (matches calendar appearance)
            let squareSize = size.width / 4
            for row in 0..<4 {
                for col in 0..<4 {
                    if (row + col) % 2 == 0 {
                        let rect = CGRect(
                            x: CGFloat(col) * squareSize,
                            y: CGFloat(row) * squareSize,
                            width: squareSize,
                            height: squareSize
                        )
                        context.fill(Path(rect), with: .color(.gray.opacity(0.3)))
                    }
                }
            }
        }
        .frame(width: 12, height: 12)
        .cornerRadius(2)
    }
}

// MARK: - Stats View
struct StatsView: View {
    let workouts: [WorkoutEntity]
    let year: Int
    
    init(workouts: [WorkoutEntity], year: Int? = nil) {
        self.workouts = workouts
        self.year = year ?? Calendar.current.component(.year, from: Date())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("STATISTICS")
                .font(.system(size: 20, weight: .heavy))
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                StatRow(title: "Days Worked Out This Year", value: "\(daysWorkedOutThisYear)")
                StatRow(title: "Completion Percentage", value: "\(Int(completionPercentage))%")
                StatRow(title: "Total Workouts This Year", value: "\(workoutsThisYear)")
                StatRow(title: "Current Streak", value: "\(currentStreak) days")
                StatRow(title: "Average Per Week", value: String(format: "%.1f", averagePerWeek))
            }
            .padding()
            
            // Workout Frequency Histogram
            VStack(alignment: .leading, spacing: 16) {
                Text("WORKOUT FREQUENCY")
                    .font(.system(size: 20, weight: .heavy))
                    .padding(.horizontal)
                
                Text("Number of days by workout count")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                let frequencyData = calculateWorkoutFrequencyHistogram()
                let maxDays = frequencyData.values.max() ?? 1
                
                VStack(spacing: 12) {
                    ForEach(frequencyData.sorted(by: { $0.key < $1.key }), id: \.key) { count, days in
                        HStack(spacing: 8) {
                            Text(count == 0 ? "0" : count == 1 ? "1" : "2+")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(width: 40, alignment: .trailing)
                            
                            GeometryReader { geometry in
                                HStack(spacing: 0) {
                                    Rectangle()
                                        .fill(AppColors.calmingTeal)
                                        .frame(width: max(CGFloat(days) / CGFloat(maxDays) * (geometry.size.width - 50), 20))
                                        .cornerRadius(4)
                                    
                                    Text("\(days) days")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.primary)
                                        .padding(.leading, 8)
                                    
                                    Spacer()
                                }
                            }
                            .frame(height: 30)
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
            
            // Workout Type Histogram
            VStack(alignment: .leading, spacing: 16) {
                Text("WORKOUTS BY TYPE")
                    .font(.system(size: 20, weight: .heavy))
                    .padding(.horizontal)
                
                let workoutCounts = calculateWorkoutTypeHistogram()
                
                VStack(spacing: 12) {
                    ForEach(workoutCounts.sorted(by: { $0.value > $1.value }), id: \.key) { type, count in
                        HStack {
                            Text(type)
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 100, alignment: .leading)
                            
                            GeometryReader { geometry in
                                HStack(spacing: 0) {
                                    Rectangle()
                                        .fill(colorForWorkoutType(type))
                                        .frame(width: max(CGFloat(count) / CGFloat(workoutsThisYear) * (geometry.size.width - 40), 20))
                                    
                                    Text("\(count)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.primary)
                                        .padding(.leading, 8)
                                    
                                    Spacer()
                                }
                            }
                            .frame(height: 24)
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
    }
    
    private var workoutsThisYear: Int {
        return workouts.count
    }
    
    private var daysWorkedOutThisYear: Int {
        let calendar = Calendar.current
        
        let uniqueDays = Set(workouts.compactMap { w -> Date? in
            guard let date = w.date else { return nil }
            return calendar.startOfDay(for: date)
        })
        
        return uniqueDays.count
    }
    
    private var completionPercentage: Double {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        
        let endDate: Date
        if year == currentYear {
            // For current year, calculate up to today
            endDate = Date()
        } else {
            // For past years, calculate for the full year
            endDate = calendar.date(from: DateComponents(year: year, month: 12, day: 31))!
        }
        
        let daysSinceStart = calendar.dateComponents([.day], from: startOfYear, to: endDate).day ?? 0
        
        guard daysSinceStart > 0 else { return 0 }
        return (Double(daysWorkedOutThisYear) / Double(daysSinceStart + 1)) * 100
    }
    
    private func calculateWorkoutTypeHistogram() -> [String: Int] {
        var counts: [String: Int] = [:]
        for workout in workouts {
            let type = workout.type ?? "Unknown"
            counts[type, default: 0] += 1
        }
        
        return counts
    }
    
    private func calculateWorkoutFrequencyHistogram() -> [Int: Int] {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        
        // Group workouts by day
        var workoutsPerDay: [Date: Int] = [:]
        for workout in workouts {
            guard let date = workout.date else { continue }
            let day = calendar.startOfDay(for: date)
            workoutsPerDay[day, default: 0] += 1
        }
        
        // Count how many days had 0, 1, 2+ workouts
        var frequency: [Int: Int] = [0: 0, 1: 0, 2: 0]
        
        // Get all days in the year
        let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        let endDate: Date
        if year == currentYear {
            // For current year, count up to today
            endDate = calendar.startOfDay(for: Date())
        } else {
            // For past years, count the full year
            endDate = calendar.date(from: DateComponents(year: year, month: 12, day: 31))!
        }
        
        var currentDay = startOfYear
        
        while currentDay <= endDate {
            let count = workoutsPerDay[currentDay] ?? 0
            if count == 0 {
                frequency[0, default: 0] += 1
            } else if count == 1 {
                frequency[1, default: 0] += 1
            } else {
                frequency[2, default: 0] += 1
            }
            currentDay = calendar.date(byAdding: .day, value: 1, to: currentDay)!
        }
        
        return frequency
    }
    
    private var currentStreak: Int {
        guard !workouts.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var currentDate = today
        var restDayUsed = false
        
        while true {
            let hasWorkout = workouts.contains { w in
                guard let date = w.date else { return false }
                return calendar.isDate(date, inSameDayAs: currentDate)
            }
            
            if hasWorkout {
                streak += 1
                restDayUsed = false
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
            } else if !restDayUsed {
                restDayUsed = true
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
            } else {
                break
            }
        }
        
        return streak
    }
    
    private var averagePerWeek: Double {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        
        let endDate: Date
        if year == currentYear {
            endDate = Date()
        } else {
            endDate = calendar.date(from: DateComponents(year: year, month: 12, day: 31))!
        }
        
        let weeksSinceStart = calendar.dateComponents([.weekOfYear], from: startOfYear, to: endDate).weekOfYear ?? 1
        
        guard weeksSinceStart > 0 else { return 0 }
        return Double(workoutsThisYear) / Double(weeksSinceStart)
    }
}

// MARK: - Progress Chart
struct ProgressChartView: View {
    let workouts: [WorkoutEntity]
    let year: Int
    
    init(workouts: [WorkoutEntity], year: Int? = nil) {
        self.workouts = workouts
        self.year = year ?? Calendar.current.component(.year, from: Date())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("MONTHLY PROGRESS")
                .font(.system(size: 20, weight: .heavy))
                .padding(.horizontal)
            
            Text("Workouts Per Month in \(String(year))")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            let monthlyData = calculateMonthlyWorkouts()
            let maxWorkouts = monthlyData.max() ?? 1
            
            GeometryReader { geometry in
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(monthlyData.indices, id: \.self) { index in
                        VStack(spacing: 4) {
                            Text("\(monthlyData[index])")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(AppColors.primaryOrange)
                            
                            Rectangle()
                                .fill(AppColors.primaryOrange)
                                .frame(width: (geometry.size.width / 12) - 2, height: max(CGFloat(monthlyData[index]) / CGFloat(maxWorkouts) * 120, 5))
                                .cornerRadius(3)
                            
                            Text(monthName(for: index + 1))
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .frame(width: (geometry.size.width / 12) - 2)
                    }
                }
            }
            .frame(height: 180)
            .padding(.horizontal)
        }
    }
    
    private func calculateMonthlyWorkouts() -> [Int] {
        let calendar = Calendar.current
        var monthlyData = [Int](repeating: 0, count: 12)
        
        for workout in workouts {
            guard let date = workout.date else { continue }
            let month = calendar.component(.month, from: date)
            monthlyData[month - 1] += 1
        }
        
        return monthlyData
    }
    
    private func monthName(for month: Int) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM"
        let date = Calendar.current.date(from: DateComponents(year: year, month: month, day: 1))!
        return dateFormatter.string(from: date)
    }
}

// MARK: - Supporting Views
struct StatRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .font(.system(size: 20, weight: .heavy))
                .foregroundColor(AppColors.calmingTeal)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
            Spacer()
        }
    }
}

// MARK: - Multi Workout Sheet
struct MultiWorkoutSheet: View {
    let workouts: [WorkoutEntity]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List(workouts, id: \.id) { workout in
                NavigationLink(destination: WorkoutDetailSheet(workout: workout)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(workout.type?.uppercased() ?? "WORKOUT")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(colorForWorkoutType(workout.type ?? ""))
                        
                        if let date = workout.date {
                            Text(date, style: .time)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        if workout.duration > 0 {
                            Text("\(Int(workout.duration)) min")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Multiple Workouts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Workout Detail Sheet
struct WorkoutDetailSheet: View {
    let workout: WorkoutEntity
    @Environment(\.dismiss) var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingTagEditor = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(workout.type?.uppercased() ?? "WORKOUT")
                            .font(.system(size: 24, weight: .heavy))
                            .foregroundColor(colorForWorkoutType(workout.type ?? ""))
                        
                        if let date = workout.date {
                            Text(date, style: .date)
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        
                        // Display tags
                        if !workout.tagArray.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(workout.tagArray, id: \.self) { tag in
                                        Text(tag)
                                            .font(.system(size: 12, weight: .semibold))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(colorForWorkoutType(tag).opacity(0.2))
                                            .foregroundColor(colorForWorkoutType(tag))
                                            .cornerRadius(12)
                                    }
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    if workout.duration > 0 {
                        DetailRow(label: "Duration", value: "\(Int(workout.duration)) min")
                    }
                    
                    if workout.calories > 0 {
                        DetailRow(label: "Calories", value: "\(Int(workout.calories)) kcal")
                    }
                    
                    if workout.heartRate > 0 {
                        DetailRow(label: "Avg Heart Rate", value: "\(Int(workout.heartRate)) bpm")
                    }
                    
                    if let notes = workout.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NOTES")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary)
                            Text(notes)
                                .font(.system(size: 16))
                        }
                    }
                    
                    Button(action: { showingTagEditor = true }) {
                        HStack {
                            Image(systemName: "tag")
                            Text("Edit Tags")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.calmingTeal)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Workout Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingTagEditor) {
                TagEditorView(workout: workout)
            }
        }
    }
}

// MARK: - Tag Editor View
struct TagEditorView: View {
    let workout: WorkoutEntity
    @Environment(\.dismiss) var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @State private var tags: [String]
    @State private var newTag = ""
    
    init(workout: WorkoutEntity) {
        self.workout = workout
        _tags = State(initialValue: workout.tagArray)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("CURRENT TAGS")) {
                    if tags.isEmpty {
                        Text("No tags yet")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(tags, id: \.self) { tag in
                            HStack {
                                Text(tag)
                                Spacer()
                                Button(action: {
                                    tags.removeAll { $0 == tag }
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("ADD NEW TAG")) {
                    HStack {
                        TextField("Enter tag name", text: $newTag)
                        Button(action: addTag) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(AppColors.primaryOrange)
                        }
                        .disabled(newTag.isEmpty)
                    }
                }
            }
            .navigationTitle("Edit Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTags()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
    
    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        tags.append(trimmed)
        newTag = ""
    }
    
    private func saveTags() {
        workout.tagArray = tags
        try? viewContext.save()
        dismiss()
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .heavy))
                .foregroundColor(AppColors.calmingTeal)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Global Helper Function
func colorForWorkoutType(_ type: String) -> Color {
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
