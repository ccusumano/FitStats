//
//  WorkoutDayEntity+CoreData.swift
//  WorkoutTracker
//
//  Created by Carl on 1/3/26.
//

import Foundation
import CoreData

@objc(WorkoutDayEntity)
public class WorkoutDayEntity: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var orderIndex: Int16
    @NSManaged public var createdDate: Date?
    @NSManaged public var plan: WorkoutPlanEntity?
    @NSManaged public var exercises: Set<ExerciseEntity>?

    var sortedExercises: [ExerciseEntity] {
        guard let exercises = exercises else { return [] }
        return exercises.sorted { ($0.orderIndex) < ($1.orderIndex) }
    }
}

extension WorkoutDayEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<WorkoutDayEntity> {
        return NSFetchRequest<WorkoutDayEntity>(entityName: "WorkoutDayEntity")
    }
}
