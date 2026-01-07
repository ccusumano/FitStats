//
//  StrengthPlanDetailView.swift
//  WorkoutTracker
//
//  Created by Carl on 1/3/26.
//

import SwiftUI
import CoreData

struct StrengthPlanDetailView: View {
    let plan: WorkoutPlanEntity
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingEditSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                planHeaderCard

                if plan.sortedDays.isEmpty {
                    emptyDaysState
                } else {
                    daysListSection
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
            AddEditStrengthPlanView(plan: plan)
        }
    }

    private var planHeaderCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(plan.type ?? "Strength", systemImage: "dumbbell.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppColors.strengthColor)

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
    }

    private var daysListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WORKOUT DAYS")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.secondary)

            ForEach(plan.sortedDays) { day in
                NavigationLink(destination: StrengthDayDetailView(day: day)) {
                    DayCard(day: day)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private var emptyDaysState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 50))
                .foregroundColor(AppColors.calmingTeal)

            Text("No Days Added Yet")
                .font(.system(size: 20, weight: .bold))

            Text("Tap Edit to add workout days to this plan")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct DayCard: View {
    let day: WorkoutDayEntity

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(day.name ?? "Unnamed Day")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)

                Text("\(day.sortedExercises.count) exercise\(day.sortedExercises.count == 1 ? "" : "s")")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.system(size: 14, weight: .semibold))
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
