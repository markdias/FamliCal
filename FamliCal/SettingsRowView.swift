//
//  SettingsRowView.swift
//  FamliCal
//
//  Created by Codex on 21/11/2025.
//

import SwiftUI

struct SettingsRowView: View {
    let iconName: String
    let title: String
    var showChevron: Bool = true
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 20))
                .foregroundColor(.gray)
                .frame(width: 24, height: 24)
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .padding(.vertical, 12)
    }
}

#Preview {
    VStack {
        SettingsRowView(iconName: "person.circle", title: "Profile")
        SettingsRowView(iconName: "lock", title: "Password")
    }
    .padding()
}
