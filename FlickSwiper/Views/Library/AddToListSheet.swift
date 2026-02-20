import SwiftUI
import SwiftData
import os

/// Sheet that shows all user lists as a checklist, allowing toggling membership
struct AddToListSheet: View {
    let item: SwipedItem
    private let logger = Logger(subsystem: "com.flickswiper.app", category: "AddToListSheet")
    @Query(sort: \UserList.sortOrder) private var lists: [UserList]
    @Query private var entries: [ListEntry]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var showCreateList = false
    @State private var newListName = ""
    @State private var persistenceErrorMessage: String?
    
    var body: some View {
        NavigationStack {
            listContent
                .navigationTitle("Add to List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .alert("New List", isPresented: $showCreateList) {
                TextField("List name", text: $newListName)
                Button("Create") {
                    guard !newListName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    let list = UserList(name: newListName, sortOrder: lists.count)
                    modelContext.insert(list)
                    // Also add the current item to this new list
                    let entry = ListEntry(listID: list.id, itemID: item.uniqueID)
                    modelContext.insert(entry)
                    do {
                        try modelContext.save()
                        // Sync to Firestore if this list is published
                        let ctx = modelContext
                        Task { try? await ListPublisher(context: ctx).syncIfPublished(list: list) }
                        newListName = ""
                    } catch {
                        logger.error("Failed to create list from AddToListSheet: \(error.localizedDescription)")
                        persistenceErrorMessage = "We couldn't create this list. Please try again."
                    }
                }
                Button("Cancel", role: .cancel) { newListName = "" }
            }
            .alert(
                "Couldn't Save Changes",
                isPresented: Binding(
                    get: { persistenceErrorMessage != nil },
                    set: { if !$0 { persistenceErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { persistenceErrorMessage = nil }
            } message: {
                Text(persistenceErrorMessage ?? "Please try again.")
            }
        }
    }
    
    @ViewBuilder
    private var listContent: some View {
        if lists.isEmpty {
            VStack(spacing: 16) {
                Text("No Lists Yet")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Text("Create your first list to start organizing.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Button {
                    showCreateList = true
                } label: {
                    Label("New List", systemImage: "plus")
                        .font(.body.weight(.semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.accentColor, in: Capsule())
                        .foregroundStyle(.white)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(lists) { list in
                    Button {
                        toggleMembership(list: list)
                        HapticManager.selectionChanged()
                    } label: {
                        HStack {
                            Text(list.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if isInList(list) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
                
                Button {
                    showCreateList = true
                } label: {
                    Label("New List", systemImage: "plus")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }
    
    private func isInList(_ list: UserList) -> Bool {
        entries.contains { $0.listID == list.id && $0.itemID == item.uniqueID }
    }
    
    private func toggleMembership(list: UserList) {
        do {
            let listID = list.id
            let itemID = item.uniqueID
            let descriptor = FetchDescriptor<ListEntry>(
                predicate: #Predicate<ListEntry> {
                    $0.listID == listID && $0.itemID == itemID
                }
            )
            let matches = try modelContext.fetch(descriptor)
            if let existing = matches.first {
                modelContext.delete(existing)
            } else {
                let entry = ListEntry(listID: list.id, itemID: item.uniqueID)
                modelContext.insert(entry)
            }
            // Deduplicate in case concurrent sheets created duplicates.
            for duplicate in matches.dropFirst() {
                modelContext.delete(duplicate)
            }
            try modelContext.save()
            // Sync to Firestore if this list is published
            let ctx = modelContext
            Task { try? await ListPublisher(context: ctx).syncIfPublished(list: list) }
        } catch {
            logger.error("Failed to toggle list membership: \(error.localizedDescription)")
            persistenceErrorMessage = "We couldn't update this list. Please try again."
        }
    }
}
