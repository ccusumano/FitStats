//
//  SavedWorkoutsView.swift
//  WorkoutTracker
//
//  Created by Carl on 12/30/25.
//
// v4

import SwiftUI
import CoreData

struct SavedWorkoutsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \WorkoutPlanEntity.createdDate, ascending: false)],
        animation: .default)
    private var workoutPlans: FetchedResults<WorkoutPlanEntity>
    
    @State private var showingAddWorkout = false
    
    var body: some View {
        NavigationView {
            Group {
                if workoutPlans.isEmpty {
                    emptyState
                } else {
                    workoutsList
                }
            }
            .navigationTitle("SAVED WORKOUTS")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddWorkout = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppColors.primaryOrange)
                    }
                }
            }
            .sheet(isPresented: $showingAddWorkout) {
                AddWorkoutPlanView()
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 80))
                .foregroundColor(AppColors.calmingTeal)
            
            Text("No Saved Workouts Yet")
                .font(.system(size: 24, weight: .heavy))
            
            Text("Create your first workout plan to get started on your fitness journey!")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    private var workoutsList: some View {
        List {
            ForEach(workoutPlans) { plan in
                NavigationLink(destination: WorkoutPlanDetailView(plan: plan)) {
                    WorkoutPlanRow(plan: plan)
                }
            }
            .onDelete(perform: deletePlans)
        }
        .listStyle(.insetGrouped)
    }
    
    private func deletePlans(offsets: IndexSet) {
        withAnimation {
            offsets.map { workoutPlans[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                print("Error deleting plan: \(error)")
            }
        }
    }
}

struct WorkoutPlanRow: View {
    let plan: WorkoutPlanEntity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(plan.name ?? "Untitled Plan")
                .font(.system(size: 18, weight: .bold))
            
            if let description = plan.planDescription, !description.isEmpty {
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                if let type = plan.type {
                    Label(type, systemImage: iconForWorkoutType(type))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(colorForWorkoutType(type))
                }
                
                Spacer()
                
                if let date = plan.createdDate {
                    Text(date, style: .date)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func colorForWorkoutType(_ type: String) -> Color {
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
    
    private func iconForWorkoutType(_ type: String) -> String {
        switch type.lowercased() {
        case "cardio": return "heart.fill"
        case "strength": return "dumbbell.fill"
        case "cycling": return "bicycle"
        case "flexibility": return "figure.mind.and.body"
        case "volleyball": return "volleyball.fill"
        case "sports": return "sportscourt.fill"
        case "hiit": return "flame.fill"
        case "yoga": return "figure.yoga"
        case "golf": return "figure.golf"
        default: return "figure.walk"
        }
    }
}

struct AddWorkoutPlanView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var selectedType = "Cardio"
    @State private var exercises = ""
    @State private var showingStrengthPlanView = false

    let workoutTypes = ["Cardio", "Strength", "Cycling", "Flexibility", "Volleyball", "Sports", "HIIT", "Yoga", "Golf"]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("PLAN DETAILS")) {
                    TextField("Plan Name", text: $name)
                        .font(.system(size: 16, weight: .semibold))

                    Picker("Type", selection: $selectedType) {
                        ForEach(workoutTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }

                    TextField("Description (optional)", text: $description)
                        .font(.system(size: 14))
                }

                if selectedType != "Strength" {
                    Section(header: Text("EXERCISES")) {
                        TextEditor(text: $exercises)
                            .frame(minHeight: 150)
                            .font(.system(size: 14))
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                } else {
                    Section {
                        Text("For strength workouts, you'll set up days and exercises in the next step")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("New Workout Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(selectedType == "Strength" ? "Next" : "Save") {
                        if selectedType == "Strength" {
                            showingStrengthPlanView = true
                        } else {
                            savePlan()
                        }
                    }
                    .disabled(name.isEmpty)
                    .fontWeight(.bold)
                }
            }
            .fullScreenCover(isPresented: $showingStrengthPlanView, onDismiss: {
                dismiss()
            }) {
                AddEditStrengthPlanView(
                    plan: nil,
                    planName: name,
                    planDescription: description,
                    planType: selectedType
                )
            }
        }
    }

    private func savePlan() {
        let newPlan = WorkoutPlanEntity(context: viewContext)
        newPlan.id = UUID()
        newPlan.name = name
        newPlan.planDescription = description.isEmpty ? nil : description
        newPlan.type = selectedType
        newPlan.exercises = exercises.isEmpty ? nil : exercises
        newPlan.createdDate = Date()

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving plan: \(error)")
        }
    }
}

struct WorkoutPlanDetailView: View {
    let plan: WorkoutPlanEntity
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        Group {
            if plan.isStructuredStrength {
                StrengthPlanDetailView(plan: plan)
            } else {
                LegacyPlanDetailView(plan: plan)
            }
        }
    }
}

struct LegacyPlanDetailView: View {
    let plan: WorkoutPlanEntity
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingEditSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(plan.type ?? "Workout", systemImage: iconForWorkoutType(plan.type ?? ""))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(colorForWorkoutType(plan.type ?? ""))

                        Spacer()

                        if let date = plan.createdDate {
                            Text(date, style: .date)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }

                    if let description = plan.planDescription, !description.isEmpty {
                        Text(description)
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

                if let exercises = plan.exercises, !exercises.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("EXERCISES")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.secondary)

                        Text(exercises)
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                            .lineSpacing(6)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
        .navigationTitle(plan.name ?? "Workout Plan")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingEditSheet = true }) {
                    Text("Edit")
                        .fontWeight(.bold)
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditWorkoutPlanView(plan: plan)
        }
    }
    
    private func colorForWorkoutType(_ type: String) -> Color {
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
    
    private func iconForWorkoutType(_ type: String) -> String {
        switch type.lowercased() {
        case "cardio": return "heart.fill"
        case "strength": return "dumbbell.fill"
        case "cycling": return "bicycle"
        case "flexibility": return "figure.mind.and.body"
        case "volleyball": return "volleyball.fill"
        case "sports": return "sportscourt.fill"
        case "hiit": return "flame.fill"
        case "yoga": return "figure.yoga"
        case "golf": return "figure.golf"
        default: return "figure.walk"
        }
    }
}

struct EditWorkoutPlanView: View {
    let plan: WorkoutPlanEntity
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var description = ""
    @State private var selectedType = "Cardio"
    @State private var exercises = ""
    
    let workoutTypes = ["Cardio", "Strength", "Flexibility", "Sports", "HIIT", "Yoga", "Golf"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("PLAN DETAILS")) {
                    TextField("Plan Name", text: $name)
                        .font(.system(size: 16, weight: .semibold))
                    
                    Picker("Type", selection: $selectedType) {
                        ForEach(workoutTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    
                    TextField("Description (optional)", text: $description)
                        .font(.system(size: 14))
                }
                
                Section(header: Text("EXERCISES")) {
                    TextEditor(text: $exercises)
                        .frame(minHeight: 150)
                        .font(.system(size: 14))
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            .navigationTitle("Edit Workout Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        updatePlan()
                    }
                    .disabled(name.isEmpty)
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                name = plan.name ?? ""
                description = plan.planDescription ?? ""
                selectedType = plan.type ?? "Cardio"
                exercises = plan.exercises ?? ""
            }
        }
    }
    
    private func updatePlan() {
        plan.name = name
        plan.planDescription = description.isEmpty ? nil : description
        plan.type = selectedType
        plan.exercises = exercises.isEmpty ? nil : exercises
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error updating plan: \(error)")
        }
    }
}
