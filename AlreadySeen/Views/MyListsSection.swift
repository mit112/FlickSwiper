import SwiftUI
import SwiftData

/// Horizontal scroll section showing user-created lists + "New List" button
struct MyListsSection: View {
    @Query(sort: \UserList.sortOrder) private var userLists: [UserList]
    @Query private var allEntries: [ListEntry]
    @Query(filter: #Predicate<SwipedItem> {
        $0.swipeDirection == "seen" || $0.swipeDirection == "watchlist"
    })
    private var libraryItems: [SwipedItem]
    @Environment(\.modelContext) private var modelContext
    
    @State private var showCreateList = false
    @State private var newListName = ""
    @State private var showRenameAlert = false
    @State private var renameTarget: UserList?
    @State private var renameText = ""
    
    var body: some View {
        if !userLists.isEmpty || true { // Always show to allow creating first list
            VStack(alignment: .leading, spacing: 12) {
                Text("My Lists")
                    .font(.title3.weight(.bold))
                    .padding(.horizontal, 16)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(userLists) { list in
                            let listItems = list.items(entries: allEntries, allItems: libraryItems)
                            NavigationLink(value: list) {
                                UserListCard(
                                    list: list,
                                    itemCount: listItems.count,
                                    coverPosterPath: listItems.first?.posterPath
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    renameTarget = list
                                    renameText = list.name
                                    showRenameAlert = true
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                
                                Button(role: .destructive) {
                                    deleteList(list)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        
                        // New List button
                        Button { showCreateList = true } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.title3.weight(.semibold))
                                Text("New List")
                                    .font(.caption.weight(.medium))
                            }
                            .foregroundStyle(.secondary)
                            .frame(width: 140, height: 110)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                                    .foregroundStyle(.secondary.opacity(0.4))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .alert("New List", isPresented: $showCreateList) {
                TextField("List name", text: $newListName)
                Button("Create") {
                    guard !newListName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    let list = UserList(name: newListName, sortOrder: userLists.count)
                    modelContext.insert(list)
                    try? modelContext.save()
                    newListName = ""
                }
                Button("Cancel", role: .cancel) { newListName = "" }
            }
            .alert("Rename List", isPresented: $showRenameAlert) {
                TextField("List name", text: $renameText)
                Button("Rename") {
                    guard !renameText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    renameTarget?.name = renameText
                    try? modelContext.save()
                    renameTarget = nil
                }
                Button("Cancel", role: .cancel) { renameTarget = nil }
            }
        }
    }
    
    private func deleteList(_ list: UserList) {
        // Delete all entries for this list
        let listID = list.id
        let entriesToDelete = allEntries.filter { $0.listID == listID }
        for entry in entriesToDelete {
            modelContext.delete(entry)
        }
        modelContext.delete(list)
        try? modelContext.save()
    }
}
