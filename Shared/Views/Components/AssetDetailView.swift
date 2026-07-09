//
//  AssetDetailView.swift
//  TanyaLe
//
//  Created by Rizki Hidayatul Laeli on 08/07/26.
//


// Buat komponen detail asset (judul "About this X", deskripsi, tombol Edit/Save)
import SwiftUI

/// Shows one asset's description with an inline Edit/Save toggle, plus a
/// "Use this Item" action that commits the selection back to the picker.
/// Description edits go straight through `MockAssetService`, so they apply
/// to the shared asset record — not just the checkpoint being configured.
///
/// `onUseItem` is optional: pass it for Pak RT's asset-picker flow (shows
/// Edit and "Use this Item"). Omit it for a plain read-only view — e.g. the
/// citizen's "Read more" sheet, which only ever displays the description.
struct AssetDetailView: View {
    let assetId: String
    let onUseItem: (() -> Void)?

    private let assetService = MockAssetService.shared
    @State private var isEditing = false
    @State private var draftDescription = ""

    init(assetId: String, onUseItem: (() -> Void)? = nil) {
        self.assetId = assetId
        self.onUseItem = onUseItem
    }

    private var asset: Asset3D? {
        assetService.asset(withId: assetId)
    }

    var body: some View {
        ScrollView {
            if let asset {
                VStack(alignment: .leading, spacing: 16) {
                    AssetThumbnailImage(asset: asset, iconSize: 72)
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    HStack {
                        Text("About this \(asset.name)")
                            .font(.title3.bold())

                        Spacer()

                        if onUseItem != nil {
                            Button(isEditing ? "Save" : "Edit") {
                                if isEditing {
                                    assetService.updateDescription(draftDescription, forAssetId: asset.id)
                                } else {
                                    draftDescription = asset.description
                                }
                                isEditing.toggle()
                            }
                        }
                    }

                    if isEditing {
                        TextEditor(text: $draftDescription)
                            .frame(minHeight: 120)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.separator), lineWidth: 1)
                            )
                    } else {
                        Text(asset.description)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(asset?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if let onUseItem {
                PrimaryActionButton(title: "Use this Item", isDisabled: isEditing) {
                    onUseItem()
                }
                .padding()
            }
        }
    }
}

#Preview("Pak RT — pickable") {
    NavigationStack {
        AssetDetailView(assetId: "kandang_ayam") {}
    }
}

#Preview("Citizen — read only") {
    NavigationStack {
        AssetDetailView(assetId: "kandang_ayam")
    }
}
