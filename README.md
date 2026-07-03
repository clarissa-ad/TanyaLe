# 📍 TanyaLe: Urban Intelligence & Citizen Aspiration Platform

![Swift](https://img.shields.io/badge/Swift-5.9-F05138?style=flat&logo=swift)
![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20App%20Clip-lightgrey)
![Architecture](https://img.shields.io/badge/Architecture-MVVM-blue)

## 📖 Overview
**TanyaLe** (from *tanya*, "to ask") is a dual-sided, location-aware AR platform bridging the gap between neighborhood leadership and citizen participation. Built on the **C4 Framework (Capture, Collect, Coordinate, Collaborate)**, it allows neighborhood heads (Pak RT) to validate their *program kerja* by placing interactive AR checkpoints in the real world, while citizens (*warga*) can effortlessly provide context-aware feedback.

The core UX mandate for the citizen experience is **"Gue ga harus mikir"** (Frictionless entry & interaction). 

---

## ✨ Core Features & Personas

### 🏗️ The Architect (Pak RT / Survey Maker)
* **AR Checkpoint Creation:** Pinpoint specific geographic locations to drop AR anchors.
* **Survey Configuration:** Assign distinct interaction types to checkpoints:
    * **AR MCQ & Emoji:** Quick sentiment and structured data gathering.
    * **AR Photobooth:** Visual evidence collection.
    * **3D Asset Likability:** Drop 3D models (e.g., trash cans, *lele*, chicken coops) in AR to gauge citizen approval before physical implementation.
* **Data Aggregation:** View real-time, location-based insights.

### 🚶 The Contributor (Warga / Citizen)
* **App Clip / Instant App Integration:** Zero-install entry. Users simply scan a QR code at the physical location to immediately launch the AR experience.
* **Proximity Gating:** System verifies physical presence via `CoreLocation` before allowing survey submission, ensuring high-quality, on-site data.
* **Walkable Aspirations:** A free-form feature allowing citizens to drop geo-anchored feedback (text/audio/photo) anywhere in the neighborhood.

---

## 🛠️ App Clip & Technical Architecture

TanyaLe strictly adheres to a **Backend-Agnostic MVVM Architecture**. Because we are deploying an App Clip, the Xcode project is divided into distinct targets. The App Clip **must remain under 15MB**, so code reuse and strict target management are critical.

**⚠️ STRICT RULE: No Logic in Views.**
Do not write business logic, database calls, or `CoreLocation` math inside `ContentView` or any SwiftUI View. Always route logic through Services (Protocols) and ViewModels.

* **UI/UX:** SwiftUI
* **AR/Spacial:** RealityKit & ARKit
* **Location:** CoreLocation
* **Database/Sync:** CloudKit (Public Database) to allow seamless sync between the App Clip (Warga) and the Main App (Pak RT) without requiring user authentication for citizens.

### Directory & Target Layout
```text
TanyaLe_Workspace/
├── 📁 Shared/                   // ⚠️ Code compiled for BOTH targets (Keep it light!)
│   ├── Manager/               // Hardware managers (LocationManager, ARManager)
│   ├── Models/                // Codable schemas (SurveyRecord, Checkpoint)
│   ├── Resources/             // Lightweight .usdz assets, Configs
│   ├── Services/              // CloudKit, Network services
│   └── Views/                 // Reusable UI pieces
│       └── Components/        // Buttons, Theme, Cards
│
├── 📱 TanyaLeApp/               // MAIN APP TARGET (Pak RT / Architect)
│   ├── App/                   // TanyaLeApp.swift (Main entry point)
│   ├── Resources/             // Heavy 3D assets only for Pak RT
│   ├── ViewModels/            // MakerViewModel (Admin logic)
│   └── Views/                 // Dashboard, Data Aggregation, Checkpoint Creator
│
└── ⚡️ TanyaLeClip/              // APP CLIP TARGET (Warga / Respondent) - MAX 15MB
    ├── App/                   // TanyaLeClipApp.swift (Handles QR Code Payload)
    ├── Resources/             // Lightweight QR/Scanner assets
    ├── ViewModels/            // RespondentViewModel (Map & AR flow)
    └── Views/                 // MapView, SurveyInputView, ARViewContainer

```

### App Clip Specifics

* **Payload Handling:** The `TanyaLeClipApp.swift` listens for `onContinueUserActivity` to extract the Checkpoint ID encoded in the scanned QR code.
* **Local Testing:** We use **Local Experiences** in iOS Developer Settings to simulate scanning a QR code during development.
* **CloudKit Rules:** Since App Clip users are typically unauthenticated (not signed in to iCloud in the clip), all read/write operations for survey responses must hit the **CloudKit Public Database**.
* **Size Enforcement (Strict <15MB):** We must periodically check the App Thinning Size Report. Do NOT import large image assets into the `Shared/` folder. Heavy third-party packages (CocoaPods, large SPM dependencies) are strictly prohibited. Stick to native Apple frameworks.

---

## 🤝 Team Workflow (How We Build)

We operate as a parallel, agile team of 4. To maintain velocity and prevent merge conflicts, we follow a strict **Feature-Branch Git Workflow**.

### 1. Branching Strategy

* `main` — Production-ready code.
* `staging` — Integration branch for testing features together.
* `feature/feature-name` — Active development branches.

### 2. Development Process & Panduan Commit

1. **Sync:** Selalu pastikan branch lokal kamu up-to-date dengan origin sebelum mulai kerja (`git pull origin main`).
2. **Branch:** Buat feature branch baru untuk setiap task (`git checkout -b feature/nama-task-kamu`).
3. **Commit Messages:** Gunakan format **Conventional Commits** agar history rapi dan gampang dibaca:
   * `feat:` — Untuk fitur baru (contoh: `feat: add AR checkpoint raycasting`)
   * `fix:` — Untuk bug fixes (contoh: `fix: map coordinate drift indoors`)
   * `chore:` — Untuk hal kecil/maintenance (contoh: `chore: update .gitignore`)
   * `refactor:` — Untuk perombakan code (contoh: `refactor: move AR logic to viewmodel`)
4. **Target Verification:** *Crucial step.* Jika kamu menambahkan file ke folder `Shared/`, pastikan di Xcode Inspector bahwa file tersebut dicentang untuk KEDUA target: `TanyaLe` dan `TanyaLeClip`.
5. **Pull Request (PR) Flow:**
   * Push branch kamu ke GitHub.
   * Buka PR dari branch kamu menuju `staging` (JANGAN langsung ke `main`).
   * Berikan deskripsi yang jelas tentang apa yang kamu ubah.
   * **Wajib Review:** Minimal satu anggota tim lain harus meng-approve PR kamu sebelum di-merge.
6. **Git Errors & Resolving Conflicts:**
   * Jika GitHub Desktop menolak merge karena ada "changes present" di file `.DS_Store` (file sampah macOS), buka Terminal kamu dan ketik: `git restore .DS_Store`. Ini akan mereset file tersebut dan kamu bisa melanjutkan merge.

### 3. Responsibility Matrix

To avoid stepping on each other's toes, stick to your assigned domains:

* **Architect A (Alisha/Angel):** Design UI Kits, Figma flows, and 3D Asset integration.
* **Architect B (Ian):** AR logic (MCQ, Emoji, Walkable Aspirations).
* **Frontend C (Caca):** Spacial databases, Checkpoint logic, and Photobooth integration.
* **Frontend D (Kikii):** Real-time aggregation logic, Like/Dislike tech, and Result previews.

---

## 🚀 Getting Started (Local Setup)

1. Clone the repository: `git clone [repository-url]`
2. Open `TanyaLe.xcodeproj` in Xcode 15+.
3. Select your target scheme at the top (Choose **TanyaLe** for Maker features, or **TanyaLeClip** for Warga features).
4. Run on a physical iOS device (ARKit features will not compile/run on the simulator).

**Note (Permissions First):** Ensure `Privacy - Camera Usage` and `Privacy - Location When In Use` are correctly configured in the `Info.plist` for **both** targets. Additionally, any feature touching the camera or GPS **must handle authorization states gracefully**. Do not crash or show a blank screen if a user denies access—always provide clear UI fallback instructions.
