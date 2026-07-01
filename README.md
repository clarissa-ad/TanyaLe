# TanyaLe: Urban Intelligence & Citizen Aspiration Platform

## 1. Project Overview

**TanyaLe** (derived from the Indonesian *tanya*, "to ask") is a dual-sided, location-aware mobile platform designed to bridge the gap between urban planning/NGO data collection and active citizen participation.

The platform facilitates a "Ground Truth" data loop where:

* **Architects (NGOs/Planners)** define localized, purpose-driven inquiries at specific geographic checkpoints.
* **Contributors (Citizens)** provide real-time insights via location-anchored AR snapshots, sentiment sliders, structured MCQ surveys, and open-ended "aspirational" feedback.

The project is currently in its **C4-Experiment** phase, focusing on the core mechanics of **Capture, Collect, Coordinate, and Collaborate** using lightweight, high-performance Apple native frameworks.

---

## 2. Implementation Plan (Phased Roadmap)

### Phase 1: Core Mechanics (Current)

* **Geofencing Logic**: Implementation of `LocationService` for mini-checkpoint proximity verification.
* **AR Pipeline**: Basic camera integration via `RealityKit` to capture evidence anchored to physical space.
* **Data Backbone**: Establishment of the `SurveyRecord` model and the `SurveyStorageService` protocol to allow future backend migration.

### Phase 2: Engagement Layers

* **Interaction Modules**: Development of `SurveyInputView` supporting Emoji sliders, MCQ sets, and Aspiration text fields.
* **Visualization**: Implementation of the `MapView` (Mini-Map) to help users discover active checkpoints in their vicinity.

### Phase 3: Platform Ecosystem

* **Architect Portal**: Implementation of the `MakerViewModel` allowing users to "drop" new checkpoints at their current location.
* **Sync & Sync Strategy**: Transition from `MockSurveyService` to a production-grade cloud solution (e.g., CloudKit or Firebase).

---

## 3. Current & Planned Features

### Core Features

* **Mini-Checkpoint Discovery**: A real-time mini-map showing available interaction points based on GPS proximity.
* **Proof-of-Presence Verification**: Hardware-level location gating ensures survey responses originate from the required site.
* **Dynamic Survey Engine**: A single `SurveyInputView` that adapts its UI component based on the survey type (Emoji vs. MCQ vs. Photo).

### Future Planned Features

* **Aspiration Cloud**: A global input field enabling citizens to voice urban concerns anywhere, creating a "heat map" of citizen sentiment beyond predefined checkpoints.
* **Role-Based Access**: Toggle logic between "Maker" (setup/admin) and "Contributor" (response/participation).
* **Offline Cache**: Robust local storage to queue survey responses in low-connectivity areas and sync upon network recovery.

---

## 4. MVVM Architecture & Directory Structure

TanyaLe strictly adheres to the Model-View-ViewModel (MVVM) design pattern to ensure scalability and testability.

### MVVM Responsibility Mapping

* **Models**: Pure data structures (e.g., `SurveyRecord`, `Checkpoint`) representing the core business entities.
* **ViewModels**: The "Brains" of the application. They coordinate business logic, interact with services, and expose `@Published` states to the Views.
* **Services**: Modular, protocol-based interfaces handling cross-cutting concerns like hardware interaction (`LocationService`), data persistence (`SurveyStorageService`), and network calls.
* **Views**: Declarative UI components that react automatically to ViewModel state changes.

### Directory Layout

```text
TanyaLe/
├── App/
│   ├── TanyaLeApp.swift         // Entry point & Dependency injection
│   └── Info.plist               // Camera/Location permissions
├── Models/
│   ├── SurveyRecord.swift       // Codable blueprint
│   └── Checkpoint.swift         // Location + Interaction type
├── Services/
│   ├── LocationService.swift    // Proximity logic
│   └── SurveyStorageService.swift // Storage contract
├── ViewModels/
│   ├── MakerViewModel.swift     // Admin logic for checkpoint creation
│   └── RespondentViewModel.swift // Map, proximity, & survey interaction logic
└── Views/
    ├── MapView.swift            // Mini-map preview for discovery
    ├── SurveyInputView.swift    // Dynamic UI based on SurveyType
    └── ARViewContainer.swift    // RealityKit/ARKit implementation

```

---

## 5. Development Guidelines for LLM Collaborators

1. **Prioritize App Clip Constraints**: Maintain a minimal binary footprint. Favor native frameworks (RealityKit, CoreLocation, Combine) over third-party dependencies.
2. **Modular Logic**: **Strictly forbidden** to write business logic directly into `ContentView.swift`. Always offload logic to `Services` or `ViewModels`.
3. **Permission-First Design**: Any hardware interaction (Camera/GPS) must be gated by proper authorization checks implemented within the `LocationService` or `ARKit` delegate.
4. **State Integrity**: Utilize state machines (via `enum` states in ViewModels) to manage lifecycle flows (Ready -> Capturing -> Saving -> Finished). Never allow UI interactions to occur out of sequence.
5. **Conversational Tone**: TanyaLe is a platform for human dialogue. Maintain a human-centered, clear, and professional tone in all UI copy and error handling.

---

## 6. Implementation Backlog (For Now :P)

This backlog organizes tasks by their operational domain: **Logic** (Services/ViewModels), **UI** (Views), and **Process** (Permissions/Architecture).

### Mini-Backlog Summary

| Feature | Logic | UI | Process |
| --- | --- | --- | --- |
| **Proximity Discovery** | Implement `LocationService` distance math | Create `MapView.swift` with dynamic pins | Request `WhenInUse` location permissions |
| **AR Evidence** | `SurveyViewModel` snapshot pipeline | `ARViewContainer` integration | Configure `Privacy - Camera Usage` |
| **Survey Engine** | `SurveyType` enum switch case logic | `SurveyInputView` (dynamic inputs) | Define `SurveyRecord` data mapping |
| **Admin Controls** | Coordinate capture service | "Place Checkpoint" button workflow | Setup role-based access flag |
| **Cloud Sync** | Async `SurveyStorageService` implementation | Sync status spinner/progress view | Define `Codable` JSON structure |

---

### Task Breakdown

#### Logic (Services & ViewModels)

* [ ] **Proximity Engine**: Refine `LocationService` to toggle `isAtCheckpoint` boolean based on a 20-meter geofence.
* [ ] **Data Mapping**: Finalize `SurveyRecord` to handle multi-type responses (Emoji string, MCQ index, or photo path).
* **State Machine**: Formalize `RespondentViewModel` states (Ready -> Capturing -> Saving -> Finished) to prevent invalid user inputs.

#### UI (Views)

* **Discovery Map**: Implement `MapView` to render checkpoint locations relative to the user's current GPS position.
* **Adaptive Survey UI**: Build `SurveyInputView` to render specific components (Slider/Picker/Image) based on the current `SurveyType`.
* **HUD Layer**: Ensure UI elements in `ContentView` do not obstruct the AR camera feed while maintaining high visibility.

#### Process (Permissions & Architecture)

* **App Clip Optimization**: Audit current imports to ensure only necessary frameworks are included to keep the binary small.
* **Permission Flow**: Map out the graceful handling of denied permissions (Camera/Location) to prevent the "white screen" issue.
* **Role Routing**: Implement a high-level switch in `TanyaLeApp` to toggle between the Maker (Admin) and Contributor (Respondent) UI entry points.

---

**Collaborator Note:** *TanyaLe is currently in its C4-Experiment phase. When proposing code changes, prioritize stability in the AR pipeline and the precision of geofencing logic. Always ensure the architecture remains backend-agnostic.*
