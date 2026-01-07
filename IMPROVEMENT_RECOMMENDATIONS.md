# Strength Workout Flow - Performance Improvements

## Issues Identified

### 1. Excessive Core Data Saves (CRITICAL)
**Current**: 4+ saves per workout creation
**Impact**: 200-500ms cumulative latency

### 2. Broken FetchRequest Predicate (BUG)
**Location**: `AddEditStrengthPlanView.swift:34`
**Issue**: Predicate `plan == nil` won't fetch days because plan is already saved
**Impact**: Days don't appear after being added

### 3. UI Blocking During Set Creation
**Location**: `AddEditExerciseView.swift:218-226`
**Issue**: Synchronous loop creating many Core Data objects
**Impact**: UI lag with 20+ sets

### 4. Orphaned Data on Cancel
**Issue**: Plan saved before user completes setup
**Impact**: Empty workouts in database

### 5. No User Feedback
**Issue**: Silent failures, no loading states
**Impact**: Poor UX, users unsure if actions succeeded

---

## Recommended Solutions

### Priority 1: Fix FetchRequest Predicate (IMMEDIATE)

```swift
// AddEditStrengthPlanView.swift:30-36
init(plan: WorkoutPlanEntity? = nil) {
    self.plan = plan

    let request: NSFetchRequest<WorkoutDayEntity> = WorkoutDayEntity.fetchRequest()
    if let planID = plan?.id {
        // FIX: Fetch days belonging to THIS plan
        request.predicate = NSPredicate(format: "plan.id == %@", planID as CVarArg)
    } else {
        // For new plans, this won't work - need different approach
        request.predicate = NSPredicate(value: false) // Returns nothing
    }
    request.sortDescriptors = [NSSortDescriptor(keyPath: \WorkoutDayEntity.orderIndex, ascending: true)]

    _days = FetchRequest(fetchRequest: request, animation: .default)
}
```

**BUT** the real issue is: The plan is already saved before this view opens, so we're always in edit mode.

### Priority 2: Batch Core Data Saves

**Option A: Single Save at End (RECOMMENDED)**
```swift
// Delay saving until user taps "Done" on AddEditStrengthPlanView
// Keep all objects in memory (inserted but not saved)
// Single viewContext.save() at the very end

Benefits:
- Reduces saves from 4+ to 1
- Atomic operation (all or nothing)
- Easy to cancel/rollback

Drawbacks:
- Need to manage unsaved object state
- More complex cancel logic
```

**Option B: Batch Inserts**
```swift
// Use NSBatchInsertRequest for sets
// Only available for simple inserts without relationships

Benefits:
- Extremely fast for creating many sets

Drawbacks:
- More complex code
- Doesn't trigger relationship updates automatically
```

### Priority 3: Add Loading Indicators

```swift
// In each save function:
@State private var isSaving = false

private func saveExercise() {
    isSaving = true

    Task {
        // Save in background
        await MainActor.run {
            // Update UI
            isSaving = false
            dismiss()
        }
    }
}

// In view:
.overlay {
    if isSaving {
        ProgressView()
            .scaleEffect(1.5)
            .progressViewStyle(CircularProgressViewStyle())
    }
}
```

### Priority 4: Defer Plan Creation

**Current Flow**:
1. Create plan → Save
2. Add days → Save each
3. Add exercises → Save each
4. Done → Save again

**Improved Flow**:
1. Collect plan details (no save)
2. Show AddEditStrengthPlanView with nil plan
3. User adds days/exercises (all in memory)
4. On "Done" → Create plan + days + exercises in single save

```swift
// SavedWorkoutsView - Remove createStrengthPlan()
Button(selectedType == "Strength" ? "Next" : "Save") {
    if selectedType == "Strength" {
        // Don't save yet - just show editor with temp data
        showingStrengthPlanView = true
    } else {
        savePlan()
    }
}

.fullScreenCover(isPresented: $showingStrengthPlanView) {
    // Pass name and description as parameters, not a saved plan
    AddEditStrengthPlanView(
        planName: name,
        planDescription: description,
        planType: selectedType
    )
}
```

### Priority 5: Background Thread Saves

```swift
// Use background context for saves
private func saveExercise() {
    let backgroundContext = viewContext.newBackgroundContext()

    backgroundContext.perform {
        // Create objects in background context
        // ...

        do {
            try backgroundContext.save()

            DispatchQueue.main.async {
                dismiss()
            }
        } catch {
            // Handle error
        }
    }
}
```

---

## Performance Benchmarks (Expected)

### Current Implementation
- Create plan: ~100ms
- Add day: ~80ms
- Add exercise (3 sets): ~120ms
- Final save: ~80ms
- **Total: ~380ms**

### With Single Save Optimization
- Collect data: <10ms (in-memory)
- Final save: ~150ms
- **Total: ~160ms** (58% faster)

### With Background Saves
- UI remains responsive
- Perceived latency: ~50ms
- **70% improvement in UX**

---

## Implementation Priority

1. **IMMEDIATE**: Fix FetchRequest predicate (currently broken)
2. **HIGH**: Defer plan creation until "Done"
3. **HIGH**: Single save at end
4. **MEDIUM**: Add loading indicators
5. **MEDIUM**: Background thread saves
6. **LOW**: Batch inserts for sets (optimization)

---

## Alternative: Simplified Flow

If complete rewrite is acceptable:

```swift
// Single-screen approach
AddStrengthWorkoutView
  ├─ Plan details (name, description)
  ├─ Days section (expandable list)
  │   └─ Each day has inline exercise list
  └─ Single "Save" button at bottom

Benefits:
- Single view = single save
- Clearer UX
- No deep navigation
- Faster workflow

Drawbacks:
- Less detail visibility
- Potential UI complexity
```

---

## Testing Recommendations

1. Test with 10+ days, 10+ exercises per day, 20+ sets per exercise
2. Monitor memory usage during creation
3. Test on older devices (iPhone 8, SE)
4. Profile Core Data performance in Instruments
5. Test cancel scenarios thoroughly
