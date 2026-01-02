//
//  ChatView.swift
//  WorkoutTracker
//
//  Created by Carl on 12/30/25.
//

import SwiftUI

struct ChatView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()
                
                Image(systemName: "message.badge.waveform.fill")
                    .font(.system(size: 80))
                    .foregroundColor(AppColors.calmingTeal)
                
                Text("AI Chat Coming Soon")
                    .font(.system(size: 28, weight: .heavy))
                
                Text("The AI workout generation feature is currently under development. Check back soon for personalized workout plans!")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Spacer()
            }
            .navigationTitle("AI CHAT")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
