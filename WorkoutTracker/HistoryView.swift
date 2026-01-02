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
    @State private var searchText = ""
    @State private var selectedWorkoutType = "All"
    @State private var selectedWorkouts: [WorkoutEntity]?
    @State private var showingWorkoutDetail = false
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())
    
    let visualizations = ["Year Heat Map", "Month Heat Map", "Stats", "Progress"]
    let workoutTypes = ["All", "Cardio", "Strength", "Cycling", "Flexibility", "Volleyball", "Sports", "HIIT", "Yoga", "Golf"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search workouts...", text: $searchText)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 10)
                
                // Filter by Type
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(workoutTypes, id: \.self) { type in
                            Button(action: { selectedWorkoutType = type }) {
                                Text(type)
                                    .font(.system(size: 14, weight: .semibold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedWorkoutType == type ? AppColors.primaryOrange : Color(.systemGray6))
                                    .foregroundColor(selectedWorkoutType == type ? .white : .primary)
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                
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
                        YearHeatMapView(workouts: filteredWorkouts, onDayTapped: handleDayTapped)
                    case 1:
                        MonthHeatMapView(workouts: filteredWorkouts, selectedMonth: $selectedMonth, onDayTapped: handleDayTapped)
                    case 2:
                        StatsView(workouts: filteredWorkouts)
                    case 3:
                        ProgressChartView(workouts: filteredWorkouts)
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
        
        // Filter by type (including tags)
        if selectedWorkoutType != "All" {
            filtered = filtered.filter { workout in
                let matchesType = workout.type?.lowercased() == selectedWorkoutType.lowercased()
                let matchesTags = workout.tagArray.contains { $0.lowercased() == selectedWorkoutType.lowercased() }
                return matchesType || matchesTags
            }
        }
        
        // Filter by search
        if !searchText.isEmpty {
            filtered = filtered.filter { workout in
                (workout.type?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (workout.notes?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                workout.tagArray.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        return filtered
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("YEAR HEAT MAP")
                .font(.system(size: 20, weight: .heavy))
                .padding(.horizontal)
            
            ForEach(1...12, id: \.self) { month in
                MiniMonthCalendar(month: month, year: Calendar.current.component(.year, from: Date()), workouts: workouts, onDayTapped: onDayTapped)
                    .padding(.horizontal)
            }
            
            // Legend
            WorkoutLegend()
                .padding()
        }
    }
}

// MARK: - Month Heat Map with Picker
struct MonthHeatMapView: View {
    let workouts: [WorkoutEntity]
    @Binding var selectedMonth: Int
    let onDayTapped: ([WorkoutEntity]) -> Void
    
    private var currentMonth: Int {
        Calendar.current.component(.month, from: Date())
    }
    
    private var monthOptions: [Int] {
        Array(1...currentMonth)
    }
    
    private var monthName: String {
        monthName(for: selectedMonth)
    }
    
    private func monthName(for month: Int) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM"
        let date = Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: month, day: 1))!
        return dateFormatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("MONTH HEAT MAP")
                    .font(.system(size: 20, weight: .heavy))
                Spacer()
                
                Menu {
                    ForEach(monthOptions, id: \.self) { month in
                        Button(monthName(for: month)) {
                            selectedMonth = month
                        }
                    }
                } label: {
                    HStack {
                        Text(monthName)
                            .font(.system(size: 16, weight: .semibold))
                        Image(systemName: "chevron.down")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppColors.calmingTeal)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            
            let calendar = Calendar.current
            let year = calendar.component(.year, from: Date())
            let daysInMonth = calendar.range(of: .day, in: .month, for: calendar.date(from: DateComponents(year: year, month: selectedMonth))!)?.count ?? 30
            let firstDayOfMonth = calendar.date(from: DateComponents(year: year, month: selectedMonth, day: 1))!
            let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
            
            VStack(alignment: .leading, spacing: 8) {
                // Weekday headers
                HStack(spacing: 4) {
                    ForEach(Calendar.current.shortWeekdaySymbols, id: \.self) { day in
                        Text(day)
                            .font(.system(size: 12, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Calendar grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                    ForEach(0..<(firstWeekday - 1), id: \.self) { index in
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 40)
                            .id("empty-\(index)")
                    }
                    
                    ForEach(1...daysInMonth, id: \.self) { day in
                        let date = calendar.date(from: DateComponents(year: year, month: selectedMonth, day: day))!
                        let dayWorkouts = workoutsForDate(date)
                        
                        ZStack {
                            if dayWorkouts.count > 1 {
                                CheckerboardPattern(size: 40)
                            } else {
                                Rectangle()
                                    .fill(colorForDate(date, dayWorkouts))
                            }
                            
                            Text("\(day)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(dayWorkouts.isEmpty ? .primary : .white)
                        }
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 40, maxHeight: 40)
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
            
            // Legend
            WorkoutLegend()
                .padding(.horizontal)
        }
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
            return Color(.systemGray6)
        }
        
        return colorForWorkoutType(workout.type ?? "")
    }
}

// MARK: - Workout Legend (Reusable)
struct WorkoutLegend: View {
    let items: [(String, Color)] = [
        ("Cardio", AppColors.cardioColor),
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
                    CheckerboardPattern(size: 12)
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

// MARK: - Stats View
struct StatsView: View {
    let workouts: [WorkoutEntity]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("STATISTICS")
                .font(.system(size: 20, weight: .heavy))
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                StatRow(title: "Total Workouts This Year", value: "\(workoutsThisYear)")
                StatRow(title: "Completion Percentage", value: "\(Int(completionPercentage))%")
                StatRow(title: "Current Streak", value: "\(currentStreak) days")
                StatRow(title: "Average Per Week", value: String(format: "%.1f", averagePerWeek))
            }
            .padding()
        }
    }
    
    private var workoutsThisYear: Int {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        return workouts.filter { w in
            guard let date = w.date else { return false }
            return calendar.component(.year, from: date) == year
        }.count
    }
    
    private var completionPercentage: Double {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        let daysSinceStart = calendar.dateComponents([.day], from: startOfYear, to: Date()).day ?? 0
        
        guard daysSinceStart > 0 else { return 0 }
        return (Double(workoutsThisYear) / Double(daysSinceStart + 1)) * 100
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
        let year = calendar.component(.year, from: Date())
        let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        let weeksSinceStart = calendar.dateComponents([.weekOfYear], from: startOfYear, to: Date()).weekOfYear ?? 1
        
        guard weeksSinceStart > 0 else { return 0 }
        return Double(workoutsThisYear) / Double(weeksSinceStart)
    }
}

// MARK: - Progress Chart
struct ProgressChartView: View {
    let workouts: [WorkoutEntity]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("MONTHLY PROGRESS")
                .font(.system(size: 20, weight: .heavy))
                .padding(.horizontal)
            
            Text("Workouts Per Week")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            let weeklyData = calculateWeeklyWorkouts()
            
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(weeklyData.indices, id: \.self) { index in
                    VStack {
                        Text("\(weeklyData[index])")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppColors.primaryOrange)
                        
                        Rectangle()
                            .fill(AppColors.primaryOrange)
                            .frame(width: 40, height: max(CGFloat(weeklyData[index]) * 20, 1))
                            .cornerRadius(4)
                        
                        Text("W\(index + 1)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
    }
    
    private func calculateWeeklyWorkouts() -> [Int] {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: Date())
        let year = calendar.component(.year, from: Date())
        
        var weeklyData = [Int](repeating: 0, count: 5)
        
        for workout in workouts {
            guard let date = workout.date else { continue }
            let workoutMonth = calendar.component(.month, from: date)
            let workoutYear = calendar.component(.year, from: date)
            
            if workoutMonth == month && workoutYear == year {
                let day = calendar.component(.day, from: date)
                let week = min((day - 1) / 7, 4)
                weeklyData[week] += 1
            }
        }
        
        return weeklyData
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
