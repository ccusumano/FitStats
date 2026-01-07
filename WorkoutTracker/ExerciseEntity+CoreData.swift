//
//  ExerciseEntity+CoreData.swift
//  WorkoutTracker
//
//  Created by Carl on 1/3/26.
//

import Foundation
import CoreData

@objc(ExerciseEntity)
public class ExerciseEntity: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var exerciseType: String?
    @NSManaged public var orderIndex: Int16
    @NSManaged public var notes: String?
    @NSManaged public var circuitName: String?
    @NSManaged public var day: WorkoutDayEntity?
    @NSManaged public var sets: Set<ExerciseSetEntity>?
    @NSManaged public var durations: Set<ExerciseDurationEntity>?

    var sortedSets: [ExerciseSetEntity] {
        guard let sets = sets else { return [] }
        return sets.sorted { ($0.orderIndex) < ($1.orderIndex) }
    }

    var isSetsBased: Bool {
        exerciseType == "sets_reps"
    }

    var isDurationBased: Bool {
        exerciseType == "duration"
    }
}

extension ExerciseEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ExerciseEntity> {
        return NSFetchRequest<ExerciseEntity>(entityName: "ExerciseEntity")
    }
}
