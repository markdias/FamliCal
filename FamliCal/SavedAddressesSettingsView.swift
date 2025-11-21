//
//  SavedAddressesSettingsView.swift
//  FamliCal
//
//  Created by Mark Dias on 21/11/2025.
//

import SwiftUI
import CoreData
import MapKit

struct SavedAddressesSettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var premiumManager: PremiumManager

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SavedAddress.name, ascending: true)]
    )
    private var savedAddresses: FetchedResults<SavedAddress>

    @State private var showingAddSheet = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "F2F2F7").ignoresSafeArea()

                if !premiumManager.isPremium {
                    VStack(spacing: 16) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)

                        Text("Saved Places")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.black)

                        Text("Save and reuse your favorite locations with Premium.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)

                        Spacer()

                        Button(action: { }) {
                            Text("Upgrade to Premium")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color(hex: "6A5AE0"))
                                .cornerRadius(12)
                        }
                    }
                    .padding(20)
                } else {
                    ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // MARK: - Saved Places Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Saved Places")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 16)

                            if savedAddresses.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "mappin.slash.circle")
                                        .font(.system(size: 48))
                                        .foregroundColor(.gray)

                                    Text("No saved places")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)

                                    Text("Add favorite locations for quick access")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 32)
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                .padding(.horizontal, 16)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(savedAddresses) { address in
                                        HStack(spacing: 16) {
                                            Image(systemName: "mappin.circle.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(.red)
                                                .frame(width: 32, height: 32)

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(address.name ?? "Unknown")
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundColor(.primary)

                                                if let addr = address.address, !addr.isEmpty {
                                                    Text(addr)
                                                        .font(.system(size: 13))
                                                        .foregroundColor(.gray)
                                                        .lineLimit(1)
                                                }
                                            }

                                            Spacer()

                                            Button(action: { deleteAddress(address) }) {
                                                Image(systemName: "trash")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.red)
                                                    .padding(8)
                                                    .background(Color.red.opacity(0.1))
                                                    .clipShape(Circle())
                                            }
                                        }
                                        .padding(16)

                                        if address.id != savedAddresses.last?.id {
                                            Divider()
                                                .padding(.horizontal, 16)
                                        }
                                    }
                                }
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                .padding(.horizontal, 16)
                            }

                            Button(action: { showingAddSheet = true }) {
                                Text("Add Saved Place")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.blue)
                                    .cornerRadius(12)
                                    .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 3)
                            }
                            .padding(.horizontal, 16)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("Saved Places")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))

                            Text("Back")
                        }
                        .foregroundColor(.black)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddSavedAddressView()
        }
    }
    
    private func deleteAddress(_ address: SavedAddress) {
        withAnimation {
            viewContext.delete(address)
            do {
                try viewContext.save()
            } catch {
                print("Error deleting address: \(error)")
            }
        }
    }
}

struct AddSavedAddressView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var address = ""
    @StateObject private var searchCompleter = LocationSearchCompleter()
    @State private var isSearching = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Home, Work, Gym", text: $name)
                }
                
                Section("Address") {
                    TextField("Search address", text: $address)
                        .onChange(of: address) { _, newValue in
                            if !isSearching {
                                searchCompleter.query = newValue
                            }
                        }
                    
                    if !searchCompleter.results.isEmpty && !isSearching {
                        List {
                            ForEach(searchCompleter.results, id: \.self) { result in
                                Button(action: {
                                    isSearching = true
                                    address = result.title + ", " + result.subtitle
                                    searchCompleter.query = ""
                                    searchCompleter.results = []
                                    // Reset flag after a delay to allow editing again
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        isSearching = false
                                    }
                                }) {
                                    VStack(alignment: .leading) {
                                        Text(result.title)
                                        Text(result.subtitle)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAddress()
                    }
                    .disabled(name.isEmpty || address.isEmpty)
                }
            }
        }
    }
    
    private func saveAddress() {
        let newAddress = SavedAddress(context: viewContext)
        newAddress.id = UUID()
        newAddress.name = name
        newAddress.address = address
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving address: \(error)")
        }
    }
}
