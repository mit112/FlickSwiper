import SwiftUI
import SwiftData
@preconcurrency import FirebaseAuth
import os

/// Displayed when the user opens a Universal Link to a shared list.
///
/// Fetches the list from Firestore and shows:
/// - List name and owner ("by Alex")
/// - Item count and grid of posters
/// - "Follow" button (or "Already Following" / hidden if own list)
///
/// Handles states: loading, error, list not found, list deactivated.
struct SharedListView: View {
    let docID: String
    
    @Environment(AuthService.self) private var authService
    @Environment(FollowedListSyncService.self) private var syncService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    private let firestoreService = FirestoreService()
    private let logger = Logger(subsystem: "com.flickswiper.app", category: "SharedList")
    
    @State private var listSnapshot: FirestoreService.PublishedListSnapshot?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isFollowing = false
    @State private var isProcessingFollow = false
    @State private var showSignInPrompt = false
    @State private var followCompleted = false
    
    private var isOwnList: Bool {
        guard let uid = Auth.auth().currentUser?.uid,
              let snapshot = listSnapshot else { return false }
        return snapshot.ownerUID == uid
    }
    
    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(message: error)
                } else if let snapshot = listSnapshot {
                    if !snapshot.isActive {
                        deactivatedView
                    } else {
                        listContentView(snapshot: snapshot)
                    }
                } else {
                    errorView(message: "List not found.")
                }
            }
            .navigationTitle(listSnapshot?.name ?? "Shared List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showSignInPrompt) {
                SignInPromptView(reason: "follow this list") {
                    // After sign-in, retry follow
                    performFollow()
                }
            }
        }
        .task {
            await loadList()
        }
    }
    
    // MARK: - Content View
    
    private func listContentView(snapshot: FirestoreService.PublishedListSnapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text(snapshot.name)
                        .font(.title2.weight(.bold))
                    
                    Text("by \(snapshot.ownerDisplayName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text("\(snapshot.itemCount) items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                
                // Follow button
                if !isOwnList {
                    followButton
                        .padding(.horizontal, 16)
                }
                
                // Items grid
                if snapshot.items.isEmpty {
                    Text("This list is empty.")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Array(snapshot.items.enumerated()), id: \.offset) { _, item in
                            sharedItemCard(item: item)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Follow Button
    
    @ViewBuilder
    private var followButton: some View {
        if followCompleted || isFollowing {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Following")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        } else {
            Button {
                if authService.isSignedIn {
                    performFollow()
                } else {
                    showSignInPrompt = true
                }
            } label: {
                HStack(spacing: 8) {
                    if isProcessingFollow {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "plus.circle.fill")
                    }
                    Text(isProcessingFollow ? "Following..." : "Follow This List")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .foregroundStyle(.black)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isProcessingFollow)
        }
    }
    
    // MARK: - Item Card
    
    private func sharedItemCard(item: FirestoreService.PublishedListItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let posterPath = item.posterPath,
               let url = URL(string: "https://image.tmdb.org/t/p/w185\(posterPath)") {
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
        }
    }
    
    // MARK: - State Views
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading list...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
    
    private var deactivatedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("This list is no longer available")
                .font(.headline)
            Text("The owner has removed this shared list.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
    
    // MARK: - Data Loading
    
    private func loadList() async {
        isLoading = true
        errorMessage = nil
        
        do {
            listSnapshot = try await firestoreService.fetchPublishedList(docID: docID)
            
            // Check if already following
            if let uid = Auth.auth().currentUser?.uid {
                isFollowing = try await firestoreService.isFollowing(
                    followerUID: uid,
                    listID: docID
                )
            }
        } catch {
            logger.error("Failed to load shared list: \(error.localizedDescription)")
            errorMessage = "Couldn't load this list. Check your internet connection and try again."
        }
        
        isLoading = false
    }
    
    // MARK: - Follow Action
    
    private func performFollow() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let snapshot = listSnapshot else { return }
        
        isProcessingFollow = true
        
        Task {
            do {
                // 1. Create follow in Firestore
                _ = try await firestoreService.followList(
                    followerUID: uid,
                    listID: docID
                )
                
                // 2. Cache locally as FollowedList
                let followedList = FollowedList(
                    firestoreDocID: docID,
                    name: snapshot.name,
                    ownerDisplayName: snapshot.ownerDisplayName,
                    ownerUID: snapshot.ownerUID,
                    itemCount: snapshot.itemCount
                )
                modelContext.insert(followedList)
                
                // 3. Cache items locally
                for (index, item) in snapshot.items.enumerated() {
                    let followedItem = FollowedListItem(
                        followedListID: docID,
                        tmdbID: item.tmdbID,
                        mediaType: item.mediaType,
                        title: item.title,
                        posterPath: item.posterPath,
                        sortOrder: index
                    )
                    modelContext.insert(followedItem)
                }
                
                try modelContext.save()
                
                isFollowing = true
                followCompleted = true
                isProcessingFollow = false
                
                // Start real-time listener for this list
                syncService.attachListener(for: docID)
                
                logger.info("Followed list \(docID)")
            } catch {
                isProcessingFollow = false
                logger.error("Follow failed: \(error.localizedDescription)")
                errorMessage = "Couldn't follow this list. Please try again."
            }
        }
    }
}
