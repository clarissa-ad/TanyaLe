//
//  TextFieldBottomSheet.swift
//  TanyaLe
//
//  Created by Alisha Listya Wardhani on 05/07/26.
//

import SwiftUI

struct TextFieldBottomSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var message: String = ""
    var onSubmit: (String) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header: title + close button
            Spacer()
            
            VStack {
                HStack {
                    Text("Share your thought here")
                        .font(.title2.bold())
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel("Close")
                }
                Text("What do you hope for in this exact spot?")
                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .font(.caption)
            }
            

            // Text field
            ZStack(alignment: .topLeading) {
                if message.isEmpty {
                    Text("Write your message...")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 22)
                }
                TextEditor(text: $message)
                    .scrollContentBackground(.hidden) // iOS 16+
                    .padding(12)
            }
            .background(.gray.opacity(0.25), in: RoundedRectangle(cornerRadius: 28))
            
            Button {
                onSubmit(message)
                dismiss()
            } label: {
                Text("Leave my thought")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.purple,
                                in: Capsule())
            }
        }
        .padding(24)
        .dismissKeyboardOnTap()
        .presentationBackground(.ultraThinMaterial)
        .presentationDetents([.medium, .large])
    }
    
}

#Preview {
    TextFieldBottomSheet()
}
