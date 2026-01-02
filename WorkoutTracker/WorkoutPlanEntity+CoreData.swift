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
}

extension WorkoutPlanEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<WorkoutPlanEntity> {
        return NSFetchRequest<WorkoutPlanEntity>(entityName: "WorkoutPlanEntity")
    }
}
