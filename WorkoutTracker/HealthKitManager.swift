//
//  HealthKitManager.swift
//  WorkoutTracker
//
//  Created by Carl on 12/30/25.
//
// v6

import HealthKit
import CoreData
import Combine

class HealthKitManager: ObservableObject {
    let healthStore = HKHealthStore()
    @Published var isAuthorized = false
    
    let workoutType = HKObjectType.workoutType()
    let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
    let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
    
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            return
        }
        
        let typesToRead: Set<HKObjectType> = [
            workoutType,
            heartRateType,
            activeEnergyType
        ]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                self.isAuthorized = success
                if success {
                    self.importHistoricalWorkouts()
                    self.setupWorkoutObserver()
                }
            }
        }
    }
    
    func importHistoricalWorkouts() {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .year, value: -2, to: endDate)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { (query, samples, error) in
            guard let workouts = samples as? [HKWorkout], error == nil else {
                print("Error fetching workouts: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            DispatchQueue.main.async {
                self.saveWorkoutsToCoreData(workouts)
            }
        }
        
        healthStore.execute(query)
    }
    
    private func setupWorkoutObserver() {
        let query = HKObserverQuery(sampleType: workoutType, predicate: nil) { [weak self] query, completionHandler, error in
            if error != nil {
                print("Error setting up observer: \(error?.localizedDescription ?? "Unknown")")
                return
            }
            
            self?.fetchLatestWorkouts()
            completionHandler()
        }
        
        healthStore.execute(query)
        healthStore.enableBackgroundDelivery(for: workoutType, frequency: .immediate) { success, error in
            if let error = error {
                print("Failed to enable background delivery: \(error.localizedDescription)")
            }
        }
    }
    
    private func fetchLatestWorkouts() {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -7, to: endDate)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: 10, sortDescriptors: [sortDescriptor]) { (query, samples, error) in
            guard let workouts = samples as? [HKWorkout], error == nil else { return }
            
            DispatchQueue.main.async {
                self.saveWorkoutsToCoreData(workouts)
            }
        }
        
        healthStore.execute(query)
    }
    
    private func saveWorkoutsToCoreData(_ workouts: [HKWorkout]) {
        let context = PersistenceController.shared.container.viewContext
        
        print("ðŸ“¥ Importing \(workouts.count) workouts from HealthKit")
        
        for workout in workouts {
            // Debug: Print what workout type we're receiving
            print("ðŸƒ Workout: \(workout.workoutActivityType.rawValue) - Date: \(workout.startDate)")
            
            // Check if workout already exists
            let fetchRequest: NSFetchRequest<WorkoutEntity> = WorkoutEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "date == %@", workout.startDate as NSDate)
            
            do {
                let existingWorkouts = try context.fetch(fetchRequest)
                if !existingWorkouts.isEmpty {
                    print("â­ï¸  Skipping duplicate workout")
                    continue // Skip if already imported
                }
                
                // Create new workout entity
                let workoutEntity = WorkoutEntity(context: context)
                workoutEntity.id = UUID()
                workoutEntity.date = workout.startDate
                workoutEntity.duration = workout.duration / 60 // Convert to minutes
                workoutEntity.type = mapWorkoutType(workout.workoutActivityType)
                workoutEntity.calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
                
                print("âœ… Mapped to type: \(workoutEntity.type ?? "nil")")
                
                // Fetch heart rate
                fetchHeartRate(for: workout) { heartRate in
                    if let heartRate = heartRate {
                        workoutEntity.heartRate = heartRate
                        try? context.save()
                    }
                }
                
                try context.save()
            } catch {
                print("âŒ Error saving workout: \(error)")
            }
        }
    }
    
    private func fetchHeartRate(for workout: HKWorkout, completion: @escaping (Double?) -> Void) {
        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: heartRateType, quantitySamplePredicate: predicate, options: .discreteAverage) { query, statistics, error in
            guard let statistics = statistics, let average = statistics.averageQuantity() else {
                completion(nil)
                return
            }
            
            let heartRate = average.doubleValue(for: HKUnit(from: "count/min"))
            completion(heartRate)
        }
        
        healthStore.execute(query)
    }
    
    private func mapWorkoutType(_ type: HKWorkoutActivityType) -> String {
        let mappedType: String
        
        switch type {
        // Walking - separate category
        case .walking:
            mappedType = "Walking"
        case .hiking:
            mappedType = "Walking"
            
        // Cardio activities (running, jogging)
        case .running:
            mappedType = "Cardio"
        case .stepTraining:
            mappedType = "Cardio"
        case .elliptical:
            mappedType = "Cardio"
        case .rowing:
            mappedType = "Cardio"
        case .stairClimbing:
            mappedType = "Cardio"
        case .swimming:
            mappedType = "Cardio"
            
        // Cycling
        case .cycling:
            mappedType = "Cycling"
        case .wheelchairWalkPace:
            mappedType = "Cycling"
        case .wheelchairRunPace:
            mappedType = "Cycling"
            
        // Strength
        case .traditionalStrengthTraining:
            mappedType = "Strength"
        case .functionalStrengthTraining:
            mappedType = "Strength"
        case .crossTraining:
            mappedType = "Strength"
        case .mixedCardio:
            mappedType = "Strength"
        case .coreTraining:
            mappedType = "Strength"
            
        // Flexibility
        case .flexibility:
            mappedType = "Flexibility"
        case .cooldown:
            mappedType = "Flexibility"
        case .mindAndBody:
            mappedType = "Flexibility"
        case .pilates:
            mappedType = "Flexibility"
            
        // Volleyball (IMPORTANT!)
        case .volleyball:
            mappedType = "Volleyball"
            
        // Other Sports
        case .soccer:
            mappedType = "Sports"
        case .basketball:
            mappedType = "Sports"
        case .tennis:
            mappedType = "Sports"
        case .baseball:
            mappedType = "Sports"
        case .softball:
            mappedType = "Sports"
        case .americanFootball:
            mappedType = "Sports"
        case .hockey:
            mappedType = "Sports"
        case .lacrosse:
            mappedType = "Sports"
        case .rugby:
            mappedType = "Sports"
        case .handball:
            mappedType = "Sports"
        case .bowling:
            mappedType = "Sports"
        case .cricket:
            mappedType = "Sports"
        case .racquetball:
            mappedType = "Sports"
        case .squash:
            mappedType = "Sports"
        case .tableTennis:
            mappedType = "Sports"
        case .badminton:
            mappedType = "Sports"
        case .boxing:
            mappedType = "Sports"
        case .kickboxing:
            mappedType = "Sports"
        case .martialArts:
            mappedType = "Sports"
        case .wrestling:
            mappedType = "Sports"
        case .fencing:
            mappedType = "Sports"
            
        // HIIT
        case .highIntensityIntervalTraining:
            mappedType = "HIIT"
        case .jumpRope:
            mappedType = "HIIT"
        case .fitnessGaming:
            mappedType = "HIIT"
            
        // Yoga
        case .yoga:
            mappedType = "Yoga"
        case .barre:
            mappedType = "Yoga"
        case .taiChi:
            mappedType = "Yoga"
            
        // Golf
        case .golf:
            mappedType = "Golf"
        case .discSports:
            mappedType = "Golf"
            
        // Catch-all for other activities
        default:
            mappedType = "Cardio"
            print("âš ï¸ Unknown workout type: \(type.rawValue) - defaulting to Cardio")
        }
        
        print("ðŸ”„ Mapping HKWorkoutActivityType \(type.rawValue) â†’ \(mappedType)")
        return mappedType
    }
}
