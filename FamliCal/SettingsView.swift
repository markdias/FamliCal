//
//  SettingsView.swift
//  FamliCal
//
//  Created by Codex on 20/11/2025.
//

import SwiftUI
import CoreData

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var premiumManager: PremiumManager
    @State private var showingFamilySettings = false
    @State private var showingAppSettings = false
    @State private var showingNotifications = false
    @State private var showingPermissions = false
    @State private var showingHelp = false

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(hex: "F2F2F7") // System Grouped Background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Premium Banner
                        PremiumBannerView()
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        
                        // Settings Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Settings")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)
                            
                            VStack(spacing: 0) {
                                Button(action: { showingFamilySettings = true }) {
                                    SettingsRowView(iconName: "person.circle", title: "My Family")
                                }
                                Divider().padding(.leading, 56)
                                
                                Button(action: { showingPermissions = true }) {
                                    SettingsRowView(iconName: "lock", title: "Permissions")
                                }
                                Divider().padding(.leading, 56)
                                
                                Button(action: { showingNotifications = true }) {
                                    SettingsRowView(iconName: "bell", title: "Notifications", showChevron: true)
                                }
                                Divider().padding(.leading, 56)
                                
                                Button(action: { showingAppSettings = true }) {
                                    SettingsRowView(iconName: "gearshape", title: "App Settings")
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                            .padding(.horizontal, 16)
                        }
                        
                        // More Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("More")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)
                            
                            VStack(spacing: 0) {
                                Button(action: { /* Rate & Review Action */ }) {
                                    SettingsRowView(iconName: "star.bubble", title: "Rate & Review")
                                }
                                Divider().padding(.leading, 56)
                                
                                Button(action: { showingHelp = true }) {
                                    SettingsRowView(iconName: "questionmark.circle", title: "Help")
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                            .padding(.horizontal, 16)
                        }
                        
                        Spacer(minLength: 40)
                        
                        // Log out
                        Button(action: {
                            // Log out action
                        }) {
                            HStack {
                                Image(systemName: "arrow.left.square")
                                Text("Log out")
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                        }
                        .padding(.bottom, 20)
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black)
                    }
                }
            }
        }
        .sheet(isPresented: $showingFamilySettings) {
            FamilySettingsView()
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingAppSettings) {
            AppSettingsView()
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingNotifications) {
            NavigationView {
                NotificationSettingsView()
                    .environment(\.managedObjectContext, viewContext)
            }
        }
        .sheet(isPresented: $showingPermissions) {
            NavigationView {
                PermissionsView()
            }
        }
        .sheet(isPresented: $showingHelp) {
            HelpView()
        }
    }
}

#Preview {
    SettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
}
