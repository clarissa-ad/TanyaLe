//
//  MockAssetService.swift
//  TanyaLe
//
//  Created by Rizki Hidayatul Laeli on 08/07/26.
//

//     Buat dummy data asset (hardcoded, tapi mudah diganti backend nanti) sebagai service in-memory (support edit deskripsi, ikut pola MockDatabaseService/MockPhotoService)

import Foundation
import Observation

/// TEMPORARY DEV FILE
/// Mock data source for the system-provided 3D asset catalog. Assets
/// themselves are fixed — Pak RT can only pick one and edit its description,
/// never add, delete, or upload one. Mirrors the MockDatabaseService pattern
/// so both the picker UI and the checkpoint form share the same live data.

@Observable
class MockAssetService {
    static let shared = MockAssetService()

    /// `thumbnailImageName` currently points to an SF Symbol since no real
    /// 3D render/thumbnail files exist yet. Swap the values here for actual
    /// asset catalog image names once they're available — nothing else needs
    /// to change since call sites just do `Image(systemName:)`.
    var assets: [Asset3D] = [
        Asset3D(
            id: "kandang_ayam",
            name: "Kandang Ayam",
            thumbnailImageName: "bird.fill",
            description: "Kandang ayam warga di area RT. Digunakan untuk memelihara ayam secara bersama."
        ),
        Asset3D(
            id: "pos_ronda",
            name: "Pos Ronda",
            thumbnailImageName: "building.2.fill",
            description: "Pos jaga malam warga, tempat ronda bergiliran setiap malam."
        ),
        Asset3D(
            id: "taman",
            name: "Taman",
            thumbnailImageName: "leaf.fill",
            description: "Taman kecil di tengah lingkungan sebagai ruang terbuka hijau warga."
        ),
        Asset3D(
            id: "tempat_sampah",
            name: "Tempat Sampah",
            thumbnailImageName: "trash.fill",
            description: "Tempat pembuangan sampah sementara sebelum diangkut petugas kebersihan."
        ),
        Asset3D(
            id: "gapura",
            name: "Gapura",
            thumbnailImageName: "building.columns.fill",
            description: "Gapura sebagai penanda pintu masuk kompleks/RT."
        ),
        Asset3D(
            id: "lapangan",
            name: "Lapangan",
            thumbnailImageName: "sportscourt.fill",
            description: "Lapangan serbaguna untuk kegiatan olahraga dan acara warga."
        )
    ]

    private init() {}

    func asset(withId id: String) -> Asset3D? {
        assets.first { $0.id == id }
    }

    func updateDescription(_ description: String, forAssetId id: String) {
        guard let index = assets.firstIndex(where: { $0.id == id }) else { return }
        assets[index].description = description
        print("MockAssetService: Updated description for asset \(id)")
    }
}

