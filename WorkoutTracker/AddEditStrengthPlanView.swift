//
//  AddEditStrengthPlanView.swift
//  WorkoutTracker
//
//  Created by Carl on 1/3/26.
//

import SwiftUI
import CoreData

struct AddEditStrengthPlanView: View {
    let existingPlan: WorkoutPlanEntity?
    let initialName: String
    let initialDescription: String
    let initialType: String

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @State private var planName = ""
    @State private var planDescription = ""
    @State private var showingAddDay = false
    @State private var dayToEdit: DayData?
    @State private var days: [DayData] = []
    @State private var isSaving = false

    var isEditing: Bool {
        existingPlan != nil
    }

    init(plan: WorkoutPlanEntity? = nil, planName: String = "", planDescription: String = "", planType: String = "Strength") {
        self.existingPlan = plan
        self.initialName = planName
        self.initialDescription = planDescription
        self.initialType = planType
    }

    var body: some View {
        NavigationView {
            ZStack {
                Form {
                    planDetailsSection

                    daysSection
                }
                .navigationTitle(isEditing ? "Edit Plan" : "New Strength Plan")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            savePlan()
                        }
                        .disabled(planName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                        .fontWeight(.bold)
                    }
                }
                .onAppear {
                    loadPlanData()
                }
                .sheet(isPresented: $showingAddDay) {
                    AddEditDayInMemoryView(day: dayToEdit, onSave: { dayData in
                        if let editDay = dayToEdit, let index = days.firstIndex(where: { $0.id == editDay.id }) {
                            days[index] = dayData
                        } else {
                            days.append(dayData)
                        }
                    })
                }
                .onChange(of: showingAddDay) { oldValue, newValue in
                    if !newValue {
                        dayToEdit = nil
                    }
                }
                .disabled(isSaving)

                if isSaving {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))

                        Text("Saving workout...")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(24)
                    .background(Color(.systemGray))
                    .cornerRadius(12)
                }
            }
        }
    }

    private var planDetailsSection: some View {
        Section(header: Text("PLAN DETAILS")) {
            TextField("Plan Name", text: $planName)
                .font(.system(size: 16, weight: .semibold))

            TextField("Description (optional)", text: $planDescription)
                .font(.system(size: 14))
        }
    }

    private var daysSection: some View {
        Section(header: Text("WORKOUT DAYS")) {
            if days.isEmpty {
                Text("No days added yet. Tap + to add a day.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                    NavigationLink(destination: DayExercisesInMemoryView(day: day, onUpdate: { updatedDay in
                        if let idx = days.firstIndex(where: { $0.id == updatedDay.id }) {
                            days[idx] = updatedDay
                        }
                    })) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(day.name)
                                    .font(.system(size: 16, weight: .semibold))

                                Text("\(day.exercises.count) exercise\(day.exercises.count == 1 ? "" : "s")")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button(action: {
                                dayToEdit = day
                                showingAddDay = true
                            }) {
                                Image(systemName: "pencil.circle.fill")
                                    .foregroundColor(AppColors.primaryOrange)
                                    .font(.system(size: 20))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .onDelete(perform: deleteDays)
                .onMove(perform: moveDays)
            }

            Button(action: {
                dayToEdit = nil
                showingAddDay = true
            }) {
                Label("Add Day", systemImage: "plus.circle.fill")
                    .foregroundColor(AppColors.primaryOrange)
            }
        }
    }

    private func loadPlanData() {
        planName = initialName.isEmpty ? (existingPlan?.name ?? "") : initialName
        planDescription = initialDescription.isEmpty ? (existingPlan?.planDescription ?? "") : initialDescription

        if let existingPlan = existingPlan {
            // Load existing days and exercises into memory
            let sortedDays = existingPlan.sortedDays
            days = sortedDays.map { dayEntity in
                let exercises = dayEntity.sortedExercises.map { exerciseEntity in
                    ExerciseData(
                        id: exerciseEntity.id ?? UUID(),
                        name: exerciseEntity.name ?? "",
                        type: exerciseEntity.exerciseType ?? "sets_reps",
                        sets: exerciseEntity.isSetsBased ? exerciseEntity.sortedSets.count : 3,
                        reps: exerciseEntity.isSetsBased ? Int(exerciseEntity.sortedSets.first?.reps ?? 10) : 10,
                        weight: exerciseEntity.isSetsBased ? (exerciseEntity.sortedSets.first?.weight ?? 0.0) : 0.0,
                        durationMinutes: exerciseEntity.isDurationBased ? Int((exerciseEntity.durations?.first?.duration ?? 0) / 60) : 0,
                        durationSeconds: exerciseEntity.isDurationBased ? Int((exerciseEntity.durations?.first?.duration ?? 0) % 60) : 0,
                        notes: exerciseEntity.notes ?? "",
                        circuitName: exerciseEntity.circuitName
                    )
                }
                return DayData(id: dayEntity.id ?? UUID(), name: dayEntity.name ?? "", exercises: exercises)
            }
        }
    }

    private func savePlan() {
        isSaving = true

        // Perform save in background
        Task.detached {
            await performSave()
        }
    }

    private func performSave() async {
        let targetPlan: WorkoutPlanEntity

        if let existingPlan = existingPlan {
            targetPlan = existingPlan
            // Clear existing days and exercises
            if let existingDays = targetPlan.days {
                for day in existingDays {
                    viewContext.delete(day)
                }
            }
        } else {
            targetPlan = WorkoutPlanEntity(context: viewContext)
            targetPlan.id = UUID()
            targetPlan.type = initialType
            targetPlan.createdDate = Date()
        }

        targetPlan.name = planName.trimmingCharacters(in: .whitespaces)
        targetPlan.planDescription = planDescription.isEmpty ? nil : planDescription

        // Create all days and exercises in memory first
        for (dayIndex, dayData) in days.enumerated() {
            let newDay = WorkoutDayEntity(context: viewContext)
            newDay.id = dayData.id
            newDay.name = dayData.name
            newDay.orderIndex = Int16(dayIndex)
            newDay.createdDate = Date()
            newDay.plan = targetPlan

            for (exerciseIndex, exerciseData) in dayData.exercises.enumerated() {
                let newExercise = ExerciseEntity(context: viewContext)
                newExercise.id = exerciseData.id
                newExercise.name = exerciseData.name
                newExercise.exerciseType = exerciseData.type
                newExercise.orderIndex = Int16(exerciseIndex)
                newExercise.notes = exerciseData.notes.isEmpty ? nil : exerciseData.notes
                newExercise.circuitName = exerciseData.circuitName
                newExercise.day = newDay

                if exerciseData.type == "sets_reps" {
                    var weightValue = exerciseData.weight
                    if weightValue.isNaN || !weightValue.isFinite || weightValue < 0 {
                        weightValue = 0.0
                    }

                    for setIndex in 0..<exerciseData.sets {
                        let newSet = ExerciseSetEntity(context: viewContext)
                        newSet.id = UUID()
                        newSet.exercise = newExercise
                        newSet.setNumber = Int16(setIndex + 1)
                        newSet.orderIndex = Int16(setIndex)
                        newSet.reps = Int16(exerciseData.reps)
                        newSet.weight = weightValue
                    }
                } else {
                    let totalSeconds = Int32(exerciseData.durationMinutes * 60 + exerciseData.durationSeconds)
                    let newDuration = ExerciseDurationEntity(context: viewContext)
                    newDuration.id = UUID()
                    newDuration.exercise = newExercise
                    newDuration.duration = totalSeconds
                }
            }
        }

        do {
            try viewContext.save()
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        } catch {
            print("Error saving plan: \(error)")
            await MainActor.run {
                isSaving = false
            }
        }
    }

    private func deleteDays(offsets: IndexSet) {
        withAnimation {
            days.remove(atOffsets: offsets)
        }
    }

    private func moveDays(from source: IndexSet, to destination: Int) {
        days.move(fromOffsets: source, toOffset: destination)
    }
}

// MARK: - Data Models

struct DayData: Identifiable, Equatable {
    let id: UUID
    var name: String
    var exercises: [ExerciseData]

    init(id: UUID = UUID(), name: String, exercises: [ExerciseData] = []) {
        self.id = id
        self.name = name
        self.exercises = exercises
    }

    static func == (lhs: DayData, rhs: DayData) -> Bool {
        lhs.id == rhs.id
    }
}

struct ExerciseData: Identifiable, Equatable {
    let id: UUID
    var name: String
    var type: String
    var sets: Int
    var reps: Int
    var weight: Double
    var durationMinutes: Int
    var durationSeconds: Int
    var notes: String
    var circuitName: String?

    init(id: UUID = UUID(), name: String, type: String = "sets_reps", sets: Int = 3, reps: Int = 10, weight: Double = 0.0, durationMinutes: Int = 0, durationSeconds: Int = 30, notes: String = "", circuitName: String? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.durationMinutes = durationMinutes
        self.durationSeconds = durationSeconds
        self.notes = notes
        self.circuitName = circuitName
    }

    static func == (lhs: ExerciseData, rhs: ExerciseData) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - In-Memory Views

struct AddEditDayInMemoryView: View {
    let day: DayData?
    let onSave: (DayData) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var dayName = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("DAY NAME")) {
                    TextField("e.g., Upper Body Push, Leg Day", text: $dayName)
                        .font(.system(size: 16))
                }
            }
            .navigationTitle(day == nil ? "Add Day" : "Edit Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let dayData = DayData(
                            id: day?.id ?? UUID(),
                            name: dayName.trimmingCharacters(in: .whitespaces),
                            exercises: day?.exercises ?? []
                        )
                        onSave(dayData)
                        dismiss()
                    }
                    .disabled(dayName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                dayName = day?.name ?? ""
            }
        }
    }
}

struct DayExercisesInMemoryView: View {
    @State var day: DayData
    let onUpdate: (DayData) -> Void

    @State private var showingAddExercise = false
    @State private var exerciseToEdit: ExerciseData?

    var body: some View {
        List {
            if day.exercises.isEmpty {
                Text("No exercises yet. Tap + to add an exercise.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(day.exercises) { exercise in
                    Button(action: {
                        exerciseToEdit = exercise
                        showingAddExercise = true
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)

                            HStack {
                                Label(
                                    exercise.type == "sets_reps" ? "Sets & Reps" : "Duration",
                                    systemImage: exercise.type == "sets_reps" ? "repeat" : "clock.fill"
                                )
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)

                                if exercise.type == "sets_reps" {
                                    Text("• \(exercise.sets) set\(exercise.sets == 1 ? "" : "s")")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .onDelete(perform: deleteExercises)
                .onMove(perform: moveExercises)
            }
        }
        .navigationTitle(day.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    exerciseToEdit = nil
                    showingAddExercise = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppColors.primaryOrange)
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
        .sheet(isPresented: $showingAddExercise) {
            let existingCircuits = Array(Set(day.exercises.compactMap { $0.circuitName })).sorted()
            AddEditExerciseInMemoryView(exercise: exerciseToEdit, onSave: { exerciseData in
                if let editExercise = exerciseToEdit, let index = day.exercises.firstIndex(where: { $0.id == editExercise.id }) {
                    day.exercises[index] = exerciseData
                } else {
                    day.exercises.append(exerciseData)
                }
                onUpdate(day)
            }, existingCircuits: existingCircuits)
        }
        .onChange(of: showingAddExercise) { oldValue, newValue in
            if !newValue {
                exerciseToEdit = nil
            }
        }
    }

    private func deleteExercises(offsets: IndexSet) {
        withAnimation {
            day.exercises.remove(atOffsets: offsets)
            onUpdate(day)
        }
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        day.exercises.move(fromOffsets: source, toOffset: destination)
        onUpdate(day)
    }
}

struct AddEditExerciseInMemoryView: View {
    let exercise: ExerciseData?
    let onSave: (ExerciseData) -> Void
    let existingCircuits: [String]

    @Environment(\.dismiss) var dismiss

    @State private var exerciseName = ""
    @State private var selectedType = "sets_reps"
    @State private var exerciseNotes = ""
    @State private var numberOfSets = "3"
    @State private var reps = "10"
    @State private var weight = "0"
    @State private var durationMinutes = 0
    @State private var durationSeconds = 30
    @State private var inCircuit = false
    @State private var selectedCircuitIndex = 0

    private func extractCircuitNumber(_ circuitName: String) -> Int {
        let components = circuitName.split(separator: " ")
        if components.count == 2, let num = Int(components[1]) {
            return num
        }
        return Int.max
    }

    private var sortedExistingCircuits: [String] {
        existingCircuits.sorted { (lhs, rhs) -> Bool in
            let lhsNum = extractCircuitNumber(lhs)
            let rhsNum = extractCircuitNumber(rhs)
            return lhsNum < rhsNum
        }
    }

    private var nextCircuitNumber: Int {
        let existingNumbers = existingCircuits.compactMap { extractCircuitNumber($0) }
        if existingNumbers.isEmpty {
            return 1
        }
        return (existingNumbers.max() ?? 0) + 1
    }

    private var circuitOptions: [String] {
        var options = sortedExistingCircuits
        options.append("Circuit \(nextCircuitNumber)")
        return options
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("EXERCISE DETAILS")) {
                    TextField("Exercise Name", text: $exerciseName)
                        .font(.system(size: 16, weight: .semibold))

                    Picker("Type", selection: $selectedType) {
                        Text("Sets & Reps").tag("sets_reps")
                        Text("Duration").tag("duration")
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text("CIRCUIT (OPTIONAL)")) {
                    Toggle("In Circuit", isOn: $inCircuit)
                        .font(.system(size: 14, weight: .semibold))

                    if inCircuit {
                        Picker("Select Circuit", selection: $selectedCircuitIndex) {
                            ForEach(0..<circuitOptions.count, id: \.self) { index in
                                Text(circuitOptions[index]).tag(index)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                if selectedType == "sets_reps" {
                    Section(header: Text("SETS & REPS")) {
                        HStack {
                            Text("Number of sets:")
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                            TextField("3", text: $numberOfSets)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 16))
                                .frame(width: 80)
                                .multilineTextAlignment(.center)
                        }

                        HStack {
                            Text("Reps per set:")
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                            TextField("10", text: $reps)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 16))
                                .frame(width: 80)
                                .multilineTextAlignment(.center)
                        }

                        HStack {
                            Text("Weight (lbs):")
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                            TextField("0", text: $weight)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 16))
                                .frame(width: 80)
                                .multilineTextAlignment(.center)
                        }
                    }
                } else {
                    Section(header: Text("DURATION")) {
                        HStack {
                            Picker("Minutes", selection: $durationMinutes) {
                                ForEach(0..<60) { minute in
                                    Text("\(minute) min").tag(minute)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 120)

                            Picker("Seconds", selection: $durationSeconds) {
                                ForEach(0..<60) { second in
                                    Text("\(second) sec").tag(second)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 120)
                        }
                        .frame(height: 120)
                    }
                }

                Section(header: Text("NOTES (OPTIONAL)")) {
                    TextEditor(text: $exerciseNotes)
                        .frame(minHeight: 80)
                        .font(.system(size: 14))
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            .navigationTitle(exercise == nil ? "Add Exercise" : "Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let finalCircuitName: String?
                        if inCircuit && selectedCircuitIndex < circuitOptions.count {
                            finalCircuitName = circuitOptions[selectedCircuitIndex]
                        } else {
                            finalCircuitName = nil
                        }

                        let exerciseData = ExerciseData(
                            id: exercise?.id ?? UUID(),
                            name: exerciseName.trimmingCharacters(in: .whitespaces),
                            type: selectedType,
                            sets: max(1, Int(numberOfSets) ?? 3),
                            reps: max(1, Int(reps) ?? 10),
                            weight: max(0.0, Double(weight) ?? 0.0),
                            durationMinutes: durationMinutes,
                            durationSeconds: durationSeconds,
                            notes: exerciseNotes,
                            circuitName: finalCircuitName
                        )
                        onSave(exerciseData)
                        dismiss()
                    }
                    .disabled(!isValid)
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                loadExerciseData()
            }
        }
    }

    private var isValid: Bool {
        let nameValid = !exerciseName.trimmingCharacters(in: .whitespaces).isEmpty

        if selectedType == "sets_reps" {
            let setsValid = (Int(numberOfSets) ?? 0) > 0
            let repsValid = (Int(reps) ?? 0) > 0
            return nameValid && setsValid && repsValid
        } else {
            let durationValid = (durationMinutes > 0 || durationSeconds > 0)
            return nameValid && durationValid
        }
    }

    private func loadExerciseData() {
        guard let exercise = exercise else { return }

        exerciseName = exercise.name
        selectedType = exercise.type
        exerciseNotes = exercise.notes

        if let circuit = exercise.circuitName, !circuit.isEmpty {
            inCircuit = true
            // Find the index of this circuit in circuitOptions
            if let index = circuitOptions.firstIndex(of: circuit) {
                selectedCircuitIndex = index
            }
        }

        if exercise.type == "sets_reps" {
            numberOfSets = "\(exercise.sets)"
            reps = "\(exercise.reps)"
            let weightValue = exercise.weight
            weight = weightValue.isNaN || !weightValue.isFinite ? "0.0" : "\(weightValue)"
        } else {
            durationMinutes = exercise.durationMinutes
            durationSeconds = exercise.durationSeconds
        }
    }
}
