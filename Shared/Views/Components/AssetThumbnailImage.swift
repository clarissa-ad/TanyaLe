import SwiftUI

/// Renders an asset's thumbnail, preferring a real catalog image named after
/// `asset.id` (e.g. "kandang_ayam" → an image set of the same name in
/// Assets.xcassets) and falling back to the SF Symbol in
/// `thumbnailImageName` when no catalog image exists yet. This lets dummy
/// assets get upgraded to real artwork one at a time — just add an image
/// set named after the asset's id, no code change needed.
struct AssetThumbnailImage: View {
    let asset: Asset3D
    var iconSize: CGFloat = 40

    var body: some View {
        if let uiImage = UIImage(named: asset.id) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: asset.thumbnailImageName)
                .font(.system(size: iconSize))
                .foregroundStyle(.purple)
        }
    }
}

#Preview {
    // ubah thumnail di sini
    HStack(spacing: 20) {
        AssetThumbnailImage(asset: Asset3D(id: "kandang_ayam", name: "Kandang Ayam", thumbnailImageName: "bird.fill", description: ""))
        AssetThumbnailImage(asset: Asset3D(id: "unknown_id", name: "Unknown", thumbnailImageName: "leaf.fill", description: ""))
    }
    .frame(height: 100)
    .padding()
}

// KALAU MAU NAMBAHIN THUMBNAIL DI GRID TUTORIAL:
//
//Kabar baiknya: **tidak perlu ubah `AssetThumbnailImage.swift`** — komponen itu sudah generic, otomatis nyari gambar berdasarkan `asset.id`. Yang perlu dilakukan cuma 2 langkah:
//
//## 1. Tambahkan PNG ke `Assets.xcassets`
//Di Xcode:
//- Buka `Shared/Resources/Assets.xcassets` di navigator kiri
//- Drag file PNG kamu langsung ke area kosong asset catalog itu (atau klik kanan → **New Image Set**)
//- **Rename imageset-nya supaya persis sama dengan `id` asset**-nya di `MockAssetService.swift`. Contoh: kalau mau tambah thumbnail untuk Pos Ronda, id-nya `"pos_ronda"` → nama imageset harus `pos_ronda` (persis, case-sensitive)
//- Drag PNG-mu ke slot 1x (slot 2x/3x boleh dikosongin kalau cuma punya 1 resolusi, seperti kandang ayam kemarin)
//
//## 2. Selesai — build & run
//Begitu nama imageset match `id`, `AssetThumbnailImage` otomatis nemuin dan pakai gambar itu di:
//- Grid "Select an Item"
//- Preview kecil di form checkpoint
//- Hero image di detail ("About this X")
//
//Tidak ada kode yang perlu diubah, karena `MockAssetService.swift` juga tidak perlu disentuh — `id` asset-nya sudah ada di sana dari awal.
//
//**Kalau kamu mau saya yang urus** (kayak kandang ayam kemarin) — taruh aja file PNG-nya di project (folder mana saja), kasih tau saya nama asset-nya (misal "Pos Ronda"), saya cari filenya, buatkan imageset dengan nama yang benar, dan verifikasi tampil dengan benar di simulator.
