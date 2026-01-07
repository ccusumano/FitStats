//
//  ExerciseSetEntity+CoreData.swift
//  WorkoutTracker
//
//  Created by Carl on 1/3/26.
//

import Foundation
import CoreData

@objc(ExerciseSetEntity)
public class ExerciseSetEntity: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var setNumber: Int16
    @NSManaged public var reps: Int16
    @NSManaged public var weight: Double
    @NSManaged public var orderIndex: Int16
    @NSManaged public var exercise: ExerciseEntity?
}

extension ExerciseSetEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ExerciseSetEntity> {
        return NSFetchRequest<ExerciseSetEntity>(entityName: "ExerciseSetEntity")
    }
}
