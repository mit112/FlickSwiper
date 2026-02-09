import SwiftUI
import SwiftData

/// Sheet that shows all user lists as a checklist, allowing toggling membership
struct AddToListSheet: View {
    let item: SwipedItem
    @Query(sort: \UserList.sortOrder) private var lists: [UserList]
    @Query private var entries: [ListEntry]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var showCreateList = false
    @State private var newListName = ""
    
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
                    try? modelContext.save()
                    newListName = ""
                }
                Button("Cancel", role: .cancel) { newListName = "" }
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
        if let existing = entries.first(where: { $0.listID == list.id && $0.itemID == item.uniqueID }) {
            modelContext.delete(existing)
        } else {
            let entry = ListEntry(listID: list.id, itemID: item.uniqueID)
            modelContext.insert(entry)
        }
        try? modelContext.save()
    }
}
