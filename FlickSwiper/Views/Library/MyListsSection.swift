import SwiftUI
import SwiftData
import os
@preconcurrency import FirebaseAuth

/// Horizontal scroll section showing user-created lists + "New List" button
struct MyListsSection: View {
    private let logger = Logger(subsystem: "com.flickswiper.app", category: "MyListsSection")
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
    @State private var persistenceErrorMessage: String?
    
    // Social lists state
    @Environment(AuthService.self) private var authService
    @State private var showSignInPrompt = false
    @State private var publishTarget: UserList?
    @State private var isPublishing = false
    @State private var shareURL: URL?
    @State private var showShareSheet = false
    @State private var showUnpublishConfirmation = false
    @State private var unpublishTarget: UserList?
    
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
                                // Publish / Share / Unpublish
                                if list.isPublished {
                                    Button {
                                        if let docID = list.firestoreDocID,
                                           let url = URL(string: "\(Constants.URLs.deepLinkBase)/list/\(docID)") {
                                            shareURL = url
                                            showShareSheet = true
                                        }
                                    } label: {
                                        Label("Copy Link", systemImage: "link")
                                    }
                                    
                                    Button {
                                        unpublishTarget = list
                                        showUnpublishConfirmation = true
                                    } label: {
                                        Label("Unpublish", systemImage: "link.badge.plus")
                                    }
                                } else {
                                    Button {
                                        publishTarget = list
                                        startPublishFlow(for: list)
                                    } label: {
                                        Label("Share List", systemImage: "square.and.arrow.up")
                                    }
                                }
                                
                                Divider()
                                
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
                    do {
                        try modelContext.save()
                        newListName = ""
                    } catch {
                        logger.error("Failed to create user list: \(error.localizedDescription)")
                        persistenceErrorMessage = "We couldn't create this list. Please try again."
                    }
                }
                Button("Cancel", role: .cancel) { newListName = "" }
            }
            .alert("Rename List", isPresented: $showRenameAlert) {
                TextField("List name", text: $renameText)
                Button("Rename") {
                    guard !renameText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    renameTarget?.name = renameText
                    do {
                        try modelContext.save()
                        // Sync renamed list to Firestore if published
                        if let list = renameTarget {
                            let ctx = modelContext
                            Task { try? await ListPublisher(context: ctx).syncIfPublished(list: list) }
                        }
                        renameTarget = nil
                    } catch {
                        logger.error("Failed to rename user list: \(error.localizedDescription)")
                        persistenceErrorMessage = "We couldn't rename this list. Please try again."
                    }
                }
                Button("Cancel", role: .cancel) { renameTarget = nil }
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
            // MARK: - Social Lists Sheets
            .sheet(isPresented: $showSignInPrompt) {
                SignInPromptView(reason: "share lists with friends") {
                    // After sign-in, retry the publish flow
                    if let target = publishTarget {
                        startPublishFlow(for: target)
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = shareURL {
                    ShareLinkSheet(url: url)
                }
            }
            .confirmationDialog(
                "Unpublish List?",
                isPresented: $showUnpublishConfirmation,
                titleVisibility: .visible
            ) {
                Button("Unpublish", role: .destructive) {
                    if let list = unpublishTarget {
                        performUnpublish(list: list)
                    }
                }
                Button("Cancel", role: .cancel) { unpublishTarget = nil }
            } message: {
                Text("This will remove the shared link. Friends who followed this list will see it as no longer available. You can re-share it later with a new link.")
            }
            .overlay {
                if isPublishing {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay {
                            ProgressView("Publishing...")
                                .padding(20)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                }
            }
        }
    }
    
    // MARK: - Publish / Unpublish
    
    private func startPublishFlow(for list: UserList) {
        // Check auth first
        guard authService.isSignedIn else {
            publishTarget = list
            showSignInPrompt = true
            return
        }
        
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let displayName = authService.displayName
        
        isPublishing = true
        Task {
            do {
                let publisher = ListPublisher(context: modelContext)
                let url = try await publisher.publish(
                    list: list,
                    ownerUID: uid,
                    ownerDisplayName: displayName
                )
                isPublishing = false
                shareURL = url
                showShareSheet = true
                publishTarget = nil
            } catch {
                isPublishing = false
                logger.error("Publish failed: \(error.localizedDescription)")
                persistenceErrorMessage = "We couldn't publish this list. Please try again."
                publishTarget = nil
            }
        }
    }
    
    private func performUnpublish(list: UserList) {
        Task {
            do {
                let publisher = ListPublisher(context: modelContext)
                try await publisher.unpublish(list: list)
                unpublishTarget = nil
            } catch {
                logger.error("Unpublish failed: \(error.localizedDescription)")
                persistenceErrorMessage = "We couldn't unpublish this list. Please try again."
                unpublishTarget = nil
            }
        }
    }
    
    // MARK: - Delete
    
    private func deleteList(_ list: UserList) {
        // If published, unpublish first (soft-delete in Firestore)
        if list.isPublished {
            Task {
                do {
                    let publisher = ListPublisher(context: modelContext)
                    try await publisher.unpublish(list: list)
                } catch {
                    logger.warning("Failed to unpublish during delete: \(error.localizedDescription)")
                    // Continue with local delete even if Firestore fails
                }
                deleteListLocally(list)
            }
        } else {
            deleteListLocally(list)
        }
    }
    
    private func deleteListLocally(_ list: UserList) {
        let listID = list.id
        let entriesToDelete = allEntries.filter { $0.listID == listID }
        for entry in entriesToDelete {
            modelContext.delete(entry)
        }
        modelContext.delete(list)
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to delete user list: \(error.localizedDescription)")
            persistenceErrorMessage = "We couldn't delete this list. Please try again."
        }
    }
}
