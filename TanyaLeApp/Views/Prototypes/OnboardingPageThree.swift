import SwiftUI

struct OnboardingPageThree: View {
    let primary: Color
    let gradient: LinearGradient
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Header
            VStack(spacing: 16) {
                CircleNumber(number: 3, color: primary)
                
                Text("Launch, Share,\nand Get Insights")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(gradient)
                
                Text("Share your survey, collect responses, and view insights to make better and data-driven decisions.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 20)
            }
            
            Spacer()
            
            // Graphic Placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.purple.opacity(0.1))
                    .frame(height: 250)
                
                VStack {
                    // Browser window fake
                    VStack(spacing: 0) {
                        HStack {
                            Circle().fill(Color.red).frame(width: 8, height: 8)
                            Circle().fill(Color.yellow).frame(width: 8, height: 8)
                            Circle().fill(Color.green).frame(width: 8, height: 8)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.purple.opacity(0.2))
                        
                        // Chart body
                        HStack(alignment: .bottom, spacing: 12) {
                            RoundedRectangle(cornerRadius: 4).fill(primary.opacity(0.6)).frame(width: 20, height: 40)
                            RoundedRectangle(cornerRadius: 4).fill(primary).frame(width: 20, height: 70)
                            RoundedRectangle(cornerRadius: 4).fill(primary.opacity(0.4)).frame(width: 20, height: 30)
                            RoundedRectangle(cornerRadius: 4).fill(primary.opacity(0.8)).frame(width: 20, height: 90)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                    }
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 5)
                    .padding(.horizontal, 50)
                }
                
                // Floating elements
                Circle()
                    .strokeBorder(primary, lineWidth: 6)
                    .frame(width: 60, height: 60)
                    .background(Circle().fill(Color.white))
                    .offset(x: 100, y: -80)
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 5)
                
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
}
