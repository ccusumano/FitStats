//
//  ExerciseDurationEntity+CoreData.swift
//  WorkoutTracker
//
//  Created by Carl on 1/3/26.
//

import Foundation
import CoreData

@objc(ExerciseDurationEntity)
public class ExerciseDurationEntity: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var duration: Int32
    @NSManaged public var notes: String?
    @NSManaged public var exercise: ExerciseEntity?

    var formattedDuration: String {
        let minutes = duration / 60
        let seconds = duration % 60

        if minutes > 0 && seconds > 0 {
            return "\(minutes)m \(seconds)s"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(seconds)s"
        }
    }
}

extension ExerciseDurationEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ExerciseDurationEntity> {
        return NSFetchRequest<ExerciseDurationEntity>(entityName: "ExerciseDurationEntity")
    }
}
