//
//  Asset3D.swift
//  TanyaLe
//
//  Created by Rizki Hidayatul Laeli on 08/07/26.
//

// Definisikan model Asset3D (id, nama, thumbnail, deskripsi)

import Foundation

/// A 3D asset available for Pak RT to attach to a Like & Dislike checkpoint.
/// Assets are provided by the system — Pak RT can only pick one, not
/// create, delete, or upload one.
/// Apa bedanya let dan var? let => statis, gak akan keganti. kalo var => akan terganti selama sesi
/// asumsi: for now kita asset 3d nya statis dulu
struct Asset3D: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let thumbnailImageName: String

    /// The only field Pak RT can edit. Kept `var` since `MockAssetService`
    /// updates it in place; `id`/`name`/`thumbnailImageName` stay `let`
    /// because nothing in this scope is allowed to change them.
    var description: String
}
