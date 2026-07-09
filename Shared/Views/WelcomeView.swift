//
//  WelcomeView.swift
//  TanyaLe
//
//  Created by Alisha Listya Wardhani on 06/07/26.
//
import SwiftUI

struct WelcomeView: View {
    /// Called when the user taps "Continue to Journey".
    var onContinue: () -> Void = {}

    // MARK: - Design tokens (from Figma)
    private let background = Color(red: 0.965, green: 0.969, blue: 0.976)   // #F6F7F9
    private let primary700 = Color(red: 0.278, green: 0.0, blue: 0.6)        // #470099

    private var brandGradient: LinearGradient {
        .brandPurpleButton()
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 85) {
                // MARK: Headline
                VStack(spacing: 4) {
                    Text("You’re about to enter an")
                        .font(.system(size: 20, weight: .regular))
                        .tracking(-0.6)
                        .foregroundStyle(primary700)

                    Text("AR Experience")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(brandGradient)
                }
                .multilineTextAlignment(.center)

                // MARK: Illustration
                Image("tanyale_map_illustration")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 254, height: 167)
                    .rotationEffect(.degrees(-4))

                // MARK: Survey title
                VStack(spacing: 12) {
                    Text("Trash Cans Survey")
                        .font(.system(size: 24, weight: .bold))
                    Text("RT Malaka Jaya")
                        .font(.system(size: 24, weight: .regular))
                }
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)

                // MARK: CTA + disclaimer
                VStack(spacing: 14) {
                    Button(action: onContinue) {
                        Text("Continue to Journey")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(brandGradient, in: Capsule())
                    }

                    Text("TanyaLe! doesn’t take any data from you other than the ones you put in.")
                        .font(.system(size: 10, weight: .light))
                        .foregroundStyle(.black)
                        .multilineTextAlignment(.center)
                        .frame(width: 207)
                }
                .frame(width: 238)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background)
        .ignoresSafeArea()
    }
}

#Preview {
    WelcomeView()
}
