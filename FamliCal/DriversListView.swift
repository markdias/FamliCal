import SwiftUI
import CoreData

struct DriversListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(entity: Driver.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \Driver.name, ascending: true)]) private var drivers: FetchedResults<Driver>

    @State private var showingAddDriver = false

    var body: some View {
        NavigationStack {
            ZStack {
                if drivers.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No Drivers")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Add drivers to manage who can drive to events")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                } else {
                    List {
                        ForEach(drivers, id: \.self) { driver in
                            NavigationLink(destination: EditDriverView(driver: driver)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(driver.name ?? "Unknown")
                                        .font(.headline)
                                    if let phone = driver.phone, !phone.isEmpty {
                                        Text(phone)
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                    if let email = driver.email, !email.isEmpty {
                                        Text(email)
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete(perform: deleteDrivers)
                    }
                }
            }
            .navigationTitle("Drivers")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAddDriver = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingAddDriver) {
                AddDriverView()
            }
        }
    }

    private func deleteDrivers(offsets: IndexSet) {
        withAnimation {
            offsets.map { drivers[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
                print("✅ Driver deleted successfully")
            } catch {
                print("❌ Failed to delete driver: \(error.localizedDescription)")
                let nsError = error as NSError
                print("   Error: \(nsError.domain) - \(nsError.code)")
            }
        }
    }
}

#Preview {
    DriversListView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
