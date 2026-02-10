import SwiftUI
import SwiftData

/// List picker to add the current selection (item IDs) to a chosen list. Used from edit mode in FilteredGridView.
struct AddSelectedToListSheet: View {
    let itemIDs: Set<String>
    
    @Query(sort: \UserList.sortOrder) private var lists: [UserList]
    @Query private var entries: [ListEntry]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if lists.isEmpty {
                    ContentUnavailableView(
                        "No Lists",
                        systemImage: "list.bullet",
                        description: Text("Create a list first from the Already Seen tab.")
                    )
                } else {
                    List(lists) { list in
                        Button {
                            addItemsToList(list)
                            dismiss()
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
    }
    
    private func existingCount(for list: UserList) -> Int {
        let listItemIDs = Set(entries.filter { $0.listID == list.id }.map(\.itemID))
        return itemIDs.intersection(listItemIDs).count
    }
    
    private func addItemsToList(_ list: UserList) {
        let existingItemIDs = Set(entries.filter { $0.listID == list.id }.map(\.itemID))
        let newItemIDs = itemIDs.subtracting(existingItemIDs)
        for itemID in newItemIDs {
            modelContext.insert(ListEntry(listID: list.id, itemID: itemID))
        }
        try? modelContext.save()
    }
}
