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

**Collaborator Note:** *TanyaLe is in its C4-Experiment phase. When proposing code changes, prioritize stability in the AR pipeline and the precision of geofencing logic. Always ensure the architecture remains backend-agnostic.*
