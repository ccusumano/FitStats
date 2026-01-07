//
//  WorkoutPlanEntity+CoreData.swift
//  WorkoutTracker
//
//  Created by Carl on 12/30/25.
//

import Foundation
import CoreData

@objc(WorkoutPlanEntity)
public class WorkoutPlanEntity: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var planDescription: String?
    @NSManaged public var type: String?
    @NSManaged public var exercises: String?
    @NSManaged public var createdDate: Date?
    @NSManaged public var days: Set<WorkoutDayEntity>?

    var isStructuredStrength: Bool {
        return type?.lowercased() == "strength" && !(days?.isEmpty ?? true)
    }

    var sortedDays: [WorkoutDayEntity] {
        guard let days = days else { return [] }
        return days.sorted { ($0.orderIndex) < ($1.orderIndex) }
    }
}

extension WorkoutPlanEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<WorkoutPlanEntity> {
        return NSFetchRequest<WorkoutPlanEntity>(entityName: "WorkoutPlanEntity")
    }
}
