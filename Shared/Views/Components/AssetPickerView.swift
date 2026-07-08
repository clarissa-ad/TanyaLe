//
//  AssetPickerView.swift
//  TanyaLe
//
//  Created by Rizki Hidayatul Laeli on 08/07/26.
//

//Buat komponen grid picker asset 3D sesuai desain Figma (list asset + thumbnail + nama)

import SwiftUI

/// Grid of system-provided 3D assets Pak RT can attach to a Like/Dislike
/// checkpoint. Tapping a card pushes to `AssetDetailView`; the picker only
/// commits `selectedAssetId` (and dismisses) once the detail view's "Use
/// this Item" is tapped, so browsing a description never overwrites the
/// current selection.
struct AssetPickerView: View {
    @Binding var selectedAssetId: String?

    @Environment(\.dismiss) private var dismiss
    private let assetService = MockAssetService.shared

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    init(selectedAssetId: Binding<String?>) {
        self._selectedAssetId = selectedAssetId
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(assetService.assets) { asset in
                        NavigationLink {
                            AssetDetailView(assetId: asset.id) {
                                selectedAssetId = asset.id
                                dismiss()
                            }
                        } label: {
                            AssetGridCard(asset: asset, isSelected: asset.id == selectedAssetId)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Select an Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

/// A single selectable card in the asset grid.
private struct AssetGridCard: View {
    let asset: Asset3D
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            AssetThumbnailImage(asset: asset, iconSize: 40)
                .frame(maxWidth: .infinity)
                .frame(height: 100)

            Text(asset.name)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.purple : .clear, lineWidth: 2)
        )
    }
}

#Preview {
    AssetPickerView(selectedAssetId: .constant(nil))
}
