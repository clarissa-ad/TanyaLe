//
//  SurveyPublishedView.swift
//  TanyaLe
//
//  Created by Alisha Listya Wardhani on 11/07/26.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

/// Shown right after publishing: the journey's QR code, ready to share.
/// Participants scan it to start the journey.
struct SurveyPublishedView: View {
    let journey: Journey
    /// Pops the whole creation flow back to the landing page.
    var onHome: () -> Void = {}

    /// Pushes the journey info screen ("See Survey Info").
    @State private var showSurveyInfo = false
    /// Rendered once on appear — QR generation isn't free.
    @State private var qrImage: UIImage?

    var body: some View {
        ZStack {
            Color.brandDeepPurple
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image(systemName: "party.popper.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
                    .padding(.bottom, 20)

                Text("Survey Published!")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text("Download the QR. Participants can scan\nthis to start the journey.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)

                // QR card
                Group {
                    if let qrImage {
                        Image(uiImage: qrImage)
                            .resizable()
                            .interpolation(.none) // keep QR modules crisp
                            .scaledToFit()
                    } else {
                        ProgressView()
                    }
                }
                .padding(28)
                .frame(width: 300, height: 300)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 40))
                .padding(.top, 32)

                Spacer()

                // Share the QR image via the system share sheet.
                if let qrImage {
                    ShareLink(
                        item: Image(uiImage: qrImage),
                        preview: SharePreview("\(journey.name) — TanyaLe QR", image: Image(uiImage: qrImage))
                    ) {
                        Text("Share QR Code")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.brandPurple, in: Capsule())
                    }
                }

                HStack(spacing: 14) {
                    Button(action: onHome) {
                        Image(systemName: "house")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .overlay(Circle().stroke(.white, lineWidth: 1.5))
                    }
                    .accessibilityLabel("Home")

                    Button {
                        showSurveyInfo = true
                    } label: {
                        Text("See Survey Info")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .overlay(Capsule().stroke(.white, lineWidth: 1.5))
                    }
                }
                .padding(.top, 14)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        // Post-publish is forward-only: no back into the creation flow.
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
        .onAppear {
            if qrImage == nil {
                qrImage = Self.makeQRImage(from: journey.qrCodeData ?? journey.id.uuidString)
            }
        }
        .navigationDestination(isPresented: $showSurveyInfo) {
            JourneyDetailView(journey: journey)
        }
    }

    /// Renders QR data into a crisp UIImage (scaled up — the raw filter
    /// output is only ~30 px).
    private static func makeQRImage(from string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        guard let output = filter.outputImage else { return nil }

        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        guard let cgImage = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

#Preview {
    NavigationStack {
        SurveyPublishedView(journey: Journey(
            name: "RT Malaka Jaya",
            qrCodeData: "{\"journeyID\":\"demo\"}",
            isPublished: true
        ))
    }
}
