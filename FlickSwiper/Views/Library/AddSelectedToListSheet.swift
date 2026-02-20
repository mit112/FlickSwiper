import SwiftUI
import SwiftData
import os

/// List picker to add the current selection (item IDs) to a chosen list. Used from edit mode in FilteredGridView.
struct AddSelectedToListSheet: View {
    let itemIDs: Set<String>
    
    private let logger = Logger(subsystem: "com.flickswiper.app", category: "AddSelectedToList")
    @Query(sort: \UserList.sortOrder) private var lists: [UserList]
    @Query private var entries: [ListEntry]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var persistenceErrorMessage: String?
    
    var body: some View {
        NavigationStack {
            Group {
                if lists.isEmpty {
                    ContentUnavailableView(
                        "No Lists",
                        systemImage: "list.bullet",
                        description: Text("Create a list from the Library tab.")
                    )
                } else {
                    List(lists) { list in
                        Button {
                            if addItemsToList(list) {
                                dismiss()
                            }
                        } label: {
                            HStack {
                                Text(list.name)
                                Spacer()
                                Text("\(existingCount(for: list)) already in list")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add \(itemIDs.count) Items to…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
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
    
    private func existingCount(for list: UserList) -> Int {
        let listItemIDs = Set(entries.filter { $0.listID == list.id }.map(\.itemID))
        return itemIDs.intersection(listItemIDs).count
    }
    
    @discardableResult
    private func addItemsToList(_ list: UserList) -> Bool {
        do {
            let currentEntryIDs = try fetchCurrentItemIDs(for: list.id)
            let newItemIDs = itemIDs.subtracting(currentEntryIDs)
            for itemID in newItemIDs {
                modelContext.insert(ListEntry(listID: list.id, itemID: itemID))
            }

            try dedupeEntries(for: list.id)
            try modelContext.save()
            // Sync to Firestore if this list is published
            let ctx = modelContext
            Task { try? await ListPublisher(context: ctx).syncIfPublished(list: list) }
            return true
        } catch {
            logger.error("Failed to add selected items to list: \(error.localizedDescription)")
            persistenceErrorMessage = "We couldn't update this list. Please try again."
            return false
        }
    }

    private func fetchCurrentItemIDs(for listID: UUID) throws -> Set<String> {
        let id = listID
        let descriptor = FetchDescriptor<ListEntry>(
            predicate: #Predicate<ListEntry> { $0.listID == id }
        )
        let listEntries = try modelContext.fetch(descriptor)
        return Set(listEntries.map(\.itemID))
    }

    private func dedupeEntries(for listID: UUID) throws {
        let id = listID
        let descriptor = FetchDescriptor<ListEntry>(
            predicate: #Predicate<ListEntry> { $0.listID == id }
        )
        let listEntries = try modelContext.fetch(descriptor)
        var seenItemIDs = Set<String>()
        for entry in listEntries {
            if seenItemIDs.contains(entry.itemID) {
                modelContext.delete(entry)
            } else {
                seenItemIDs.insert(entry.itemID)
            }
        }
    }
}
