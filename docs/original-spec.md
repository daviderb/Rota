# App Specification: Cycle-Based Workout Tracker

## 1. App Overview & Philosophy
This is a personal iOS workout tracking application designed to ensure balanced training and progressive overload without tying workouts to specific days of the week. 

Instead of traditional day-based routines, the app uses an **Asynchronous Cycle System**. A cycle requires a specific *number* of exercises per muscle group, but the *specific* exercises are rotated based on a "Least Recently Used" (LRU) stack to prevent exercise imbalances. 

The UI is inspired by the "Bring!" shopping app: highly visual, tactile, and utilizing a disappearing-card interface for outstanding tasks.

## 2. Core Mechanics & Logic

### 2.1 The "Cycle" Concept
* A user defines a "Cycle Blueprint" (e.g., 2 Push, 2 Pull, 2 Hinge, 2 Squat).
* The Main View displays these requirements as distinct, tappable tiles/cards (e.g., two individual "Push" tiles).
* **Completion:** When a user completes an exercise for a category, one corresponding tile disappears.
* **Reset:** The cycle only resets when *all* tiles in the current cycle are completed. Once the active cycle is empty, it automatically repopulates based on the Blueprint.

### 2.2 The Exercise Stack (LRU Rotation)
* Specific exercises are decoupled from the Cycle Blueprint. 
* Each category contains an arbitrary list of user-defined exercises.
* **Sorting Logic:** When a user taps a category tile (e.g., "Push"), a list of available Push exercises pops up. This list is strictly sorted by **time since last performed** (Least Recently Used at the top).
* **Execution:** The user selects the top exercise. Once completed, this exercise is stamped with the current date/time and pushed to the *bottom* of the list.

### 2.3 Progressive Overload Tracking
* In the exercise selection list, the weight used during the *previous* session is displayed directly next to the exercise name.
* Upon selecting an exercise to perform, the user is prompted to input the *new* weight, which is then saved for the next time the exercise rotates to the top.

## 3. User Interface (UI) & User Experience (UX) Flow

### 3.1 Main View (Active Cycle)
* Displays a grid or list of remaining category tiles for the current cycle.
* Tiles should be visually distinct (e.g., color-coded by category).
* As tiles are tapped and exercises are logged, the tiles disappear from this view.

### 3.2 Exercise Selection Modal
* Triggered by tapping a category tile.
* Displays the LRU-sorted list of exercises for that category.
* Shows: `Exercise Name` | `Previous Weight`.
* Tapping an exercise opens a quick-input field to log the new weight.
* Confirming the log closes the modal and removes one category tile from the Main View.

### 3.3 Customization & Settings View
* **Manage Categories:** Create, edit, or delete muscle groups/categories.
* **Manage Exercises:** Add new exercises (strings) to specific categories.
* **Edit Cycle Blueprint:** Define how many tiles of each category make up one complete cycle (e.g., Category: "Push" -> Quantity: 2).

## 4. Data Model Architecture 

To assist with the core logic, here is the suggested entity relationship:

| Entity | Attributes | Description |
| :--- | :--- | :--- |
| **Category** | `id`, `name`, `color` | Represents a muscle group (e.g., Push, Pull). |
| **Exercise** | `id`, `categoryId`, `name`, `lastWeight`, `lastPerformedAt` | The specific movement. `lastPerformedAt` is crucial for the stack sorting. |
| **BlueprintItem** | `categoryId`, `requiredCount` | Defines how many times a category appears in a fresh cycle. |
| **ActiveCycle** | `id`, `remainingTasks (Array of categoryIds)` | The user's current progress. State must persist indefinitely until empty. |

## 5. Technical Requirements
* **Platform:** iOS
* **Framework:** SwiftUI (highly recommended for the tap-to-disappear state management and visual grid).
* **Local Storage:** CoreData or SwiftData to ensure active cycle states, exercise histories, and custom setups persist across app launches and device restarts.
