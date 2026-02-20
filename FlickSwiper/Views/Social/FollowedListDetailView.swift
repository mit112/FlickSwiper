import SwiftUI
import SwiftData
@preconcurrency import FirebaseAuth
import os

/// Full detail view for a followed list. Shows all items in a grid.
/// Read-only — the user can't edit someone else's list.
/// Provides unfollow and individual item actions (add to own library).
struct FollowedListDetailView: View {
    let followedList: FollowedList
    
    @Query private var allFollowedItems: [FollowedListItem]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(FollowedListSyncService.self) private var syncService
    
    private let firestoreService = FirestoreService()
    private let logger = Logger(subsystem: "com.flickswiper.app", category: "FollowedListDetail")
    
    @State private var showUnfollowConfirmation = false
    @State private var isUnfollowing = false
    @State private var errorMessage: String?
    
    /// Items belonging to this specific followed list, ordered by sortOrder.
    private var items: [FollowedListItem] {
        allFollowedItems
            .filter { $0.followedListID == followedList.firestoreDocID }
            .sorted { $0.sortOrder < $1.sortOrder }
    }
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        Group {
            if !followedList.isActive {
                deactivatedBanner
            }
            
            if items.isEmpty {
                ContentUnavailableView(
                    "No Items",
                    systemImage: "film",
                    description: Text("This list is empty.")
                )
            } else {
                ScrollView {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("by \(followedList.ownerDisplayName)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Text("\(items.count) items")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if let lastFetched = followedList.lastFetchedAt {
                            Text("Updated \(lastFetched, style: .relative) ago")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    // Items grid
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(items) { item in
                            followedItemCard(item: item)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .navigationTitle(followedList.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        showUnfollowConfirmation = true
                    } label: {
                        Label("Unfollow", systemImage: "person.badge.minus")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(
            "Unfollow \"\(followedList.name)\"?",
            isPresented: $showUnfollowConfirmation,
            titleVisibility: .visible
        ) {
            Button("Unfollow", role: .destructive) {
                performUnfollow()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This list will be removed from your library. You can follow it again if someone shares the link with you.")
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Something went wrong.")
        }
        .overlay {
            if isUnfollowing {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay {
                        ProgressView("Unfollowing...")
                            .padding(20)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
            }
        }
    }
    
    // MARK: - Deactivated Banner
    
    @ViewBuilder
    private var deactivatedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("This list is no longer maintained by the owner.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // MARK: - Item Card
    
    private func followedItemCard(item: FollowedListItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let url = item.thumbnailURL {
                AsyncImage(url: url) { image in
                    image.resizable()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.gray.opacity(0.2))
                        .overlay {
                            Image(systemName: "film")
                                .foregroundStyle(.secondary)
                        }
                }
                .aspectRatio(2/3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.gray.opacity(0.2))
                    .aspectRatio(2/3, contentMode: .fit)
                    .overlay {
                        Image(systemName: "film")
                            .foregroundStyle(.secondary)
                    }
            }
            
            Text(item.title)
                .font(.caption2.weight(.medium))
                .lineLimit(2)
            
            Text(item.mediaType == "movie" ? "Movie" : "TV Show")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title), \(item.mediaType == "movie" ? "Movie" : "TV Show")")
    }
    
    // MARK: - Unfollow
    
    private func performUnfollow() {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "You must be signed in to unfollow."
            return
        }
        
        isUnfollowing = true
        let docID = followedList.firestoreDocID
        
        Task {
            do {
                // 1. Delete follow from Firestore
                try await firestoreService.unfollowList(
                    followerUID: uid,
                    listID: docID
                )
                
                // 2. Delete local FollowedListItems
                let itemsToDelete = items
                for item in itemsToDelete {
                    modelContext.delete(item)
                }
                
                // 3. Delete local FollowedList
                modelContext.delete(followedList)
                
                try modelContext.save()
                
                // 4. Detach real-time listener
                syncService.detachListener(for: docID)
                
                isUnfollowing = false
                dismiss()
                
                logger.info("Unfollowed list \(docID)")
            } catch {
                isUnfollowing = false
                logger.error("Unfollow failed: \(error.localizedDescription)")
                errorMessage = "Couldn't unfollow this list. Please try again."
            }
        }
    }
}
