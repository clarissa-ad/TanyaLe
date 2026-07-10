import SwiftUI

struct OnboardingPageTwo: View {
    let primary: Color
    let gradient: LinearGradient
    
    var body: some View {
        VStack(spacing: 24) {
            Color.clear.frame(height: 40)
            
            // Header
            VStack(spacing: 16) {
                CircleNumber(number: 2, color: primary)
                
                Text("Build Your Survey\nin 3 Simple Steps")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(gradient)
                
                Text("Add locations and create questions to understand your respondents better.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 20)
            }
            
            Spacer()
            
            // Steps Graphic
            VStack(spacing: 12) {
                StepRow(number: 1, title: "Add Location", desc: "Pick a place on the map or in the real world.", primary: primary, gradient: gradient)
                StepRow(number: 2, title: "Add Questions", desc: "Create simple questions to collect feedback.", primary: primary, gradient: gradient)
                StepRow(number: 3, title: "Publish & Collect Responses", desc: "Share your survey and view respondents' feedback.", primary: primary, gradient: gradient)
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }
}

struct StepRow: View {
    let number: Int
    let title: String
    let desc: String
    let primary: Color
    let gradient: LinearGradient
    
    var body: some View {
        HStack(spacing: 16) {
            CircleNumber(number: number, color: primary, isSmall: true)
                .background(Circle().fill(Color.white))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding()
        .background(gradient)
        .cornerRadius(12)
    }
}
