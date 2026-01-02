//
//  WorkoutEntity+CoreData.swift
//  WorkoutTracker
//
//  Created by Carl on 12/30/25.
//

import Foundation
import CoreData

@objc(WorkoutEntity)
public class WorkoutEntity: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var date: Date?
    @NSManaged public var duration: Double
    @NSManaged public var type: String?
    @NSManaged public var calories: Double
    @NSManaged public var heartRate: Double
    @NSManaged public var notes: String?
    @NSManaged public var tags: String? // Comma-separated tags
}

extension WorkoutEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<WorkoutEntity> {
        return NSFetchRequest<WorkoutEntity>(entityName: "WorkoutEntity")
    }
    
    var tagArray: [String] {
        get {
            guard let tags = tags, !tags.isEmpty else { return [] }
            return tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        set {
            tags = newValue.joined(separator: ",")
        }
    }
}
