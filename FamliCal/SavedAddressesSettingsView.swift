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
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SavedAddress.name, ascending: true)]
    )
    private var savedAddresses: FetchedResults<SavedAddress>
    
    @State private var showingAddSheet = false
    
    var body: some View {
        List {
            ForEach(savedAddresses) { address in
                VStack(alignment: .leading) {
                    Text(address.name ?? "Unknown")
                        .font(.headline)
                    if let addr = address.address, !addr.isEmpty {
                        Text(addr)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
            }
            .onDelete(perform: deleteAddresses)
        }
        .navigationTitle("Saved Places")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddSavedAddressView()
        }
    }
    
    private func deleteAddresses(offsets: IndexSet) {
        withAnimation {
            offsets.map { savedAddresses[$0] }.forEach(viewContext.delete)
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
