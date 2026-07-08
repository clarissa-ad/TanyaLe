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
struct AssetDetailView: View {
    let assetId: String
    let onUseItem: () -> Void

    private let assetService = MockAssetService.shared
    @State private var isEditing = false
    @State private var draftDescription = ""

    init(assetId: String, onUseItem: @escaping () -> Void) {
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

                        Button(isEditing ? "Save" : "Edit") {
                            if isEditing {
                                assetService.updateDescription(draftDescription, forAssetId: asset.id)
                            } else {
                                draftDescription = asset.description
                            }
                            isEditing.toggle()
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
            PrimaryActionButton(title: "Use this Item", isDisabled: isEditing) {
                onUseItem()
            }
            .padding()
        }
    }
}

#Preview {
    NavigationStack {
        AssetDetailView(assetId: "kandang_ayam") {}
    }
}
