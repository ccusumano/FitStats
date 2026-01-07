//
//  StrengthDayDetailView.swift
//  WorkoutTracker
//
//  Created by Carl on 1/3/26.
//

import SwiftUI
import CoreData

struct StrengthDayDetailView: View {
    let day: WorkoutDayEntity

    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingAddExercise = false
    @State private var exerciseToEdit: ExerciseEntity? = nil
    @State private var refreshID = UUID()
    @State private var completedExercises: Set<UUID> = []
    @State private var completedCircuits: Set<String> = []
    @State private var editMode: EditMode = .inactive

    // Grouped items in original order (not sorted by circuit)
    private var orderedGroups: [WorkoutGroup] {
        let exercises = day.sortedExercises

        var groups: [WorkoutGroup] = []
        var processedCircuits: Set<String> = []

        for exercise in exercises {
            if let circuitName = exercise.circuitName {
                // If we haven't processed this circuit yet, create a group for it
                if !processedCircuits.contains(circuitName) {
                    processedCircuits.insert(circuitName)
                    // Get all exercises in this circuit
                    let circuitExercises = exercises.filter { $0.circuitName == circuitName }
                    groups.append(WorkoutGroup(circuit: circuitName, exercises: circuitExercises))
                }
            } else {
                // Non-circuit exercise
                groups.append(WorkoutGroup(circuit: nil, exercises: [exercise]))
            }
        }

        return groups
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if day.sortedExercises.isEmpty {
                    emptyExercisesState
                } else {
                    ForEach(orderedGroups) { group in
                        if let circuitName = group.circuit {
                            // Circuit frame with single checkbox
                            CircuitCard(
                                circuitName: circuitName,
                                exercises: group.exercises,
                                isCompleted: completedCircuits.contains(circuitName),
                                onToggleComplete: {
                                    toggleCircuitCompletion(for: circuitName)
                                },
                                onTapExercise: { exercise in
                                    exerciseToEdit = exercise
                                }
                            )
                        } else if let exercise = group.exercises.first {
                            // Non-circuit exercise with individual checkbox
                            ExerciseCardWithCheckbox(
                                exercise: exercise,
                                isCompleted: completedExercises.contains(exercise.id ?? UUID()),
                                onToggleComplete: {
                                    toggleCompletion(for: exercise)
                                },
                                onTap: {
                                    exerciseToEdit = exercise
                                }
                            )
                        }
                    }
                    .onMove { source, destination in
                        moveGroups(from: source, to: destination)
                    }
                }
            }
            .padding()
            .id(refreshID)
        }
        .refreshable {
            await refreshDay()
        }
        .navigationTitle(day.name ?? "Workout Day")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddExercise = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppColors.strengthColor)
                }
            }
        }
        .environment(\.editMode, $editMode)
        .sheet(isPresented: $showingAddExercise) {
            AddEditExerciseDirectView(day: day, exercise: nil)
        }
        .sheet(item: $exerciseToEdit) { exercise in
            AddEditExerciseDirectView(day: day, exercise: exercise)
        }
    }

    private func refreshDay() async {
        // Refresh the Core Data context to get latest data
        day.managedObjectContext?.refresh(day, mergeChanges: true)
        // Trigger view update by changing the ID
        refreshID = UUID()
    }

    private func toggleCompletion(for exercise: ExerciseEntity) {
        guard let id = exercise.id else { return }
        if completedExercises.contains(id) {
            completedExercises.remove(id)
        } else {
            completedExercises.insert(id)
        }
    }

    private func toggleCircuitCompletion(for circuitName: String) {
        if completedCircuits.contains(circuitName) {
            completedCircuits.remove(circuitName)
        } else {
            completedCircuits.insert(circuitName)
        }
    }

    private func moveGroups(from source: IndexSet, to destination: Int) {
        var groups = orderedGroups
        groups.move(fromOffsets: source, toOffset: destination)

        // Update orderIndex for all exercises based on new group order
        var currentIndex: Int16 = 0
        for group in groups {
            for exercise in group.exercises {
                exercise.orderIndex = currentIndex
                currentIndex += 1
            }
        }

        // Save to Core Data
        do {
            try viewContext.save()
            refreshID = UUID()
        } catch {
            print("Error saving reorder: \(error)")
        }
    }

    private var emptyExercisesState: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 50))
                .foregroundColor(AppColors.strengthColor)

            Text("No Exercises")
                .font(.system(size: 20, weight: .bold))

            Text("This day has no exercises")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// Represents a draggable group (either a circuit or a single exercise)
struct WorkoutGroup: Identifiable {
    let id = UUID()
    let circuit: String?
    let exercises: [ExerciseEntity]
}

// Circuit card with all exercises inside a single frame, one checkbox for the whole circuit
struct CircuitCard: View {
    let circuitName: String
    let exercises: [ExerciseEntity]
    let isCompleted: Bool
    let onToggleComplete: () -> Void
    let onTapExercise: (ExerciseEntity) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Single checkbox for entire circuit (centered vertically)
            Button(action: onToggleComplete) {
                ZStack {
                    Circle()
                        .strokeBorder(isCompleted ? Color.green : Color.gray, lineWidth: 2)
                        .background(Circle().fill(isCompleted ? Color.green : Color.clear))
                        .frame(width: 24, height: 24)

                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            // Circuit frame
            VStack(alignment: .leading, spacing: 12) {
                // Circuit header
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(AppColors.strengthColor)
                        .font(.system(size: 14, weight: .bold))

                    Text(circuitName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.strengthColor)
                }

                // All exercises in circuit
                ForEach(exercises) { exercise in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(exercise.name ?? "Unnamed Exercise")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)

                            Spacer()

                            Label(
                                exercise.isSetsBased ? "Sets" : "Duration",
                                systemImage: exercise.isSetsBased ? "repeat" : "clock.fill"
                            )
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppColors.strengthColor)
                        }

                        if exercise.isSetsBased {
                            if let firstSet = exercise.sortedSets.first {
                                let repsValue = max(0, firstSet.reps)
                                let weightValue = firstSet.weight.isNaN || !firstSet.weight.isFinite ? 0.0 : firstSet.weight

                                HStack(spacing: 8) {
                                    Text("\(exercise.sortedSets.count) sets")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text("×")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                    Text("\(repsValue) reps")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text("|")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                    Text("\(String(format: "%.1f", weightValue)) lbs")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.primary)
                                }
                                .padding(8)
                                .background(Color(.systemBackground))
                                .cornerRadius(6)
                            }
                        } else if exercise.isDurationBased {
                            if let duration = exercise.durations?.first {
                                HStack {
                                    Image(systemName: "clock.fill")
                                        .foregroundColor(AppColors.strengthColor)
                                        .font(.system(size: 12))

                                    Text(duration.formattedDuration)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.primary)

                                    Spacer()
                                }
                                .padding(8)
                                .background(Color(.systemBackground))
                                .cornerRadius(6)
                            }
                        }

                        if let notes = exercise.notes, !notes.isEmpty {
                            Text(notes)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                    .padding(12)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(8)
                    .onTapGesture {
                        onTapExercise(exercise)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

// Individual exercise card with checkbox (for non-circuit exercises)
struct ExerciseCardWithCheckbox: View {
    let exercise: ExerciseEntity
    let isCompleted: Bool
    let onToggleComplete: () -> Void
    let onTap: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Completion checkbox (centered vertically)
            Button(action: onToggleComplete) {
                ZStack {
                    Circle()
                        .strokeBorder(isCompleted ? Color.green : Color.gray, lineWidth: 2)
                        .background(Circle().fill(isCompleted ? Color.green : Color.clear))
                        .frame(width: 24, height: 24)

                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            // Exercise card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(exercise.name ?? "Unnamed Exercise")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)

                    Spacer()

                    Label(
                        exercise.isSetsBased ? "Sets" : "Duration",
                        systemImage: exercise.isSetsBased ? "repeat" : "clock.fill"
                    )
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.strengthColor)
                }

                if exercise.isSetsBased {
                    if let firstSet = exercise.sortedSets.first {
                        let repsValue = max(0, firstSet.reps)
                        let weightValue = firstSet.weight.isNaN || !firstSet.weight.isFinite ? 0.0 : firstSet.weight

                        HStack(spacing: 8) {
                            Text("\(exercise.sortedSets.count) sets")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            Text("×")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                            Text("\(repsValue) reps")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            Text("|")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                            Text("\(String(format: "%.1f", weightValue)) lbs")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        .padding(12)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                    }
                } else if exercise.isDurationBased {
                    if let duration = exercise.durations?.first {
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(AppColors.strengthColor)

                            Text(duration.formattedDuration)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)

                            Spacer()
                        }
                        .padding(12)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                    }
                }

                if let notes = exercise.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .onTapGesture(perform: onTap)
        }
    }
}
