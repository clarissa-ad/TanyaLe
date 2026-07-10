import SwiftUI

struct OnboardingPageOne: View {
    let primary: Color
    let gradient: LinearGradient
    
    var body: some View {
        VStack(spacing: 24) {
            Color.clear.frame(height: 40)
            
            // Header
            VStack(spacing: 16) {
                CircleNumber(number: 1, color: primary)
                
                Text("Welcome to\nTanyaLe!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(gradient)
                
                Text("Create engaging, location-based AR surveys to gather meaningful feedback from your respondents.")
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
                    .frame(height: 220)
                
                HStack(spacing: 20) {
                    // Phone 1
                    RoundedRectangle(cornerRadius: 16)
                        .fill(primary)
                        .frame(width: 100, height: 160)
                        .overlay(
                            Image(systemName: "mappin.and.ellipse")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                        )
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white, lineWidth: 2))
                    
                    // Phone 2
                    RoundedRectangle(cornerRadius: 16)
                        .fill(primary)
                        .frame(width: 100, height: 160)
                        .overlay(
                            Image(systemName: "viewfinder")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        )
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white, lineWidth: 2))
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Banner
            HStack(spacing: 12) {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.purple)
                    .padding(8)
                    .background(Color.white)
                    .clipShape(Circle())
                
                Text("Designed for community leaders, NGOs, and researchers like you.")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .padding()
            .background(gradient)
            .cornerRadius(12)
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }
}

// MARK: - Helper Component
struct CircleNumber: View {
    let number: Int
    let color: Color
    var isSmall: Bool = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: isSmall ? 30 : 50, height: isSmall ? 30 : 50)
            Text("\(number)")
                .font(isSmall ? .headline : .title)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }
}
