//
//  AddEditExerciseDirectView.swift
//  WorkoutTracker
//
//  For editing existing saved workouts - saves directly to Core Data
//

import SwiftUI
import CoreData

struct AddEditExerciseDirectView: View {
    let day: WorkoutDayEntity
    let exercise: ExerciseEntity?

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var selectedType = "sets_reps"
    @State private var sets = "3"
    @State private var reps = "10"
    @State private var weight = "0.0"
    @State private var durationMinutes = 0
    @State private var durationSeconds = 30
    @State private var notes = ""
    @State private var inCircuit = false
    @State private var selectedCircuitIndex = 0

    private var existingCircuits: [String] {
        guard let exercises = day.exercises else { return [] }
        let circuits = Set(exercises.compactMap { $0.circuitName })
        return circuits.sorted { (lhs, rhs) -> Bool in
            let lhsNum = extractCircuitNumber(lhs)
            let rhsNum = extractCircuitNumber(rhs)
            return lhsNum < rhsNum
        }
    }

    private var nextCircuitNumber: Int {
        guard let exercises = day.exercises else { return 1 }
        let existingNumbers = exercises.compactMap { exercise -> Int? in
            guard let circuitName = exercise.circuitName else { return nil }
            return extractCircuitNumber(circuitName)
        }
        if existingNumbers.isEmpty {
            return 1
        }
        return (existingNumbers.max() ?? 0) + 1
    }

    private func extractCircuitNumber(_ circuitName: String) -> Int {
        let components = circuitName.split(separator: " ")
        if components.count == 2, let num = Int(components[1]) {
            return num
        }
        return Int.max
    }

    private var circuitOptions: [String] {
        var options = existingCircuits
        options.append("Circuit \(nextCircuitNumber)")
        return options
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("EXERCISE DETAILS")) {
                    TextField("Exercise Name", text: $name)
                        .font(.system(size: 16, weight: .semibold))

                    Picker("Type", selection: $selectedType) {
                        Text("Sets & Reps").tag("sets_reps")
                        Text("Duration").tag("duration")
                    }
                    .pickerStyle(SegmentedPickerStyle())
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
                            Text("Number of Sets")
                            Spacer()
                            TextField("Sets", text: $sets)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                        }

                        HStack {
                            Text("Reps per Set")
                            Spacer()
                            TextField("Reps", text: $reps)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                        }

                        HStack {
                            Text("Weight (lbs)")
                            Spacer()
                            TextField("Weight", text: $weight)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
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
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                        .font(.system(size: 14))
                }
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
                        saveExercise()
                    }
                    .disabled(name.isEmpty)
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                loadExerciseData()
            }
        }
    }

    private func loadExerciseData() {
        guard let exercise = exercise else { return }

        name = exercise.name ?? ""
        selectedType = exercise.exerciseType ?? "sets_reps"
        notes = exercise.notes ?? ""

        if let circuit = exercise.circuitName, !circuit.isEmpty {
            inCircuit = true
            // Find the index of this circuit in circuitOptions
            if let index = circuitOptions.firstIndex(of: circuit) {
                selectedCircuitIndex = index
            }
        }

        if exercise.isSetsBased {
            sets = "\(exercise.sortedSets.count)"
            if let firstSet = exercise.sortedSets.first {
                reps = "\(firstSet.reps)"
                let weightValue = firstSet.weight.isNaN || !firstSet.weight.isFinite ? 0.0 : firstSet.weight
                weight = "\(weightValue)"
            }
        } else if exercise.isDurationBased {
            if let duration = exercise.durations?.first {
                let totalSeconds = Int(duration.duration)
                durationMinutes = totalSeconds / 60
                durationSeconds = totalSeconds % 60
            }
        }
    }

    private func saveExercise() {
        let targetExercise: ExerciseEntity

        if let existingExercise = exercise {
            targetExercise = existingExercise

            // Clear existing sets/durations
            if let existingSets = targetExercise.sets {
                for set in existingSets {
                    viewContext.delete(set)
                }
            }
            if let existingDurations = targetExercise.durations {
                for duration in existingDurations {
                    viewContext.delete(duration)
                }
            }
        } else {
            targetExercise = ExerciseEntity(context: viewContext)
            targetExercise.id = UUID()
            targetExercise.day = day

            // Set order index for new exercise
            let existingCount = day.exercises?.count ?? 0
            targetExercise.orderIndex = Int16(existingCount)
        }

        targetExercise.name = name
        targetExercise.exerciseType = selectedType
        targetExercise.notes = notes.isEmpty ? nil : notes

        // Set circuit name based on picker selection
        if inCircuit && selectedCircuitIndex < circuitOptions.count {
            targetExercise.circuitName = circuitOptions[selectedCircuitIndex]
        } else {
            targetExercise.circuitName = nil
        }

        if selectedType == "sets_reps" {
            let setsCount = Int(sets) ?? 3
            let repsValue = Int(reps) ?? 10
            var weightValue = Double(weight) ?? 0.0

            // NaN validation
            if weightValue.isNaN || !weightValue.isFinite || weightValue < 0 {
                weightValue = 0.0
            }

            for setIndex in 0..<setsCount {
                let newSet = ExerciseSetEntity(context: viewContext)
                newSet.id = UUID()
                newSet.exercise = targetExercise
                newSet.setNumber = Int16(setIndex + 1)
                newSet.orderIndex = Int16(setIndex)
                newSet.reps = Int16(repsValue)
                newSet.weight = weightValue
            }
        } else {
            let totalSeconds = Int32(durationMinutes * 60 + durationSeconds)
            let newDuration = ExerciseDurationEntity(context: viewContext)
            newDuration.id = UUID()
            newDuration.exercise = targetExercise
            newDuration.duration = totalSeconds
        }

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving exercise: \(error)")
        }
    }
}
