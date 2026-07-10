import SwiftUI

struct SandboxMakerOnboardingView: View {
    @State private var currentPage = 0
    @Environment(\.dismiss) private var dismiss
    
    let primary500 = Color(red: 174/255, green: 0/255, blue: 255/255) // Approx #AE00FF
    let darkPurple = Color(red: 104/255, green: 0/255, blue: 153/255) // #680099
    
    var themeGradient: LinearGradient {
        LinearGradient(colors: [primary500, darkPurple], startPoint: .leading, endPoint: .trailing)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                OnboardingPageOne(primary: primary500, gradient: themeGradient)
                    .tag(0)
                OnboardingPageTwo(primary: primary500, gradient: themeGradient)
                    .tag(1)
                OnboardingPageThree(primary: primary500, gradient: themeGradient)
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            // Bottom Area
            VStack(spacing: 24) {
                // Dots
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(currentPage == index ? primary500 : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                
                // Buttons
                if currentPage == 2 {
                    Button(action: { dismiss() }) {
                        Text("Get Started")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(primary500)
                            .clipShape(Capsule())
                    }
                } else {
                    HStack {
                        if currentPage == 1 {
                            Button("Skip") { dismiss() }
                            .foregroundColor(.gray)
                            .font(.headline)
                        } else {
                            Spacer().frame(width: 40)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation { currentPage += 1 }
                        }) {
                            Text("Next")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(primary500)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .padding(.top, 16)
        }
        .navigationBarHidden(true)
    }
}

#Preview {
    SandboxMakerOnboardingView()
}
