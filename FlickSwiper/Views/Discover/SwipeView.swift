import SwiftUI
import SwiftData
import os

/// Main swipe view for discovering movies and TV shows
struct SwipeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SwipeViewModel
    private let logger = Logger(subsystem: "com.flickswiper.app", category: "SwipeView")
    @State private var showingDiscoveryPicker = false
    @State private var triggerSwipeLeft = false
    @State private var triggerSwipeRight = false
    @State private var showRatingPrompt = false
    @State private var pendingRatedItem: SwipedItem?
    @State private var pendingRatedTitle: String = ""
    @State private var detailItem: MediaItem?
    @State private var persistenceErrorMessage: String?
    @State private var ratingPresentationTask: Task<Void, Never>?
    @AppStorage(Constants.StorageKeys.hasSeenSwipeTutorial) private var hasSeenTutorial = false

    init(mediaService: any MediaServiceProtocol = TMDBService()) {
        _viewModel = State(initialValue: SwipeViewModel(mediaService: mediaService))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Discovery method selector
                DiscoverySelectorView(
                    selectedMethod: $viewModel.selectedMethod,
                    contentTypeFilter: $viewModel.contentTypeFilter,
                    yearFilterMin: $viewModel.yearFilterMin,
                    yearFilterMax: $viewModel.yearFilterMax,
                    selectedGenre: $viewModel.selectedGenre,
                    selectedSort: $viewModel.selectedSort
                )
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(Color(.systemBackground))
                .zIndex(1)
                
                // Card stack or state views
                ZStack {
                    if viewModel.isLoading && viewModel.mediaItems.isEmpty {
                        loadingView
                    } else if viewModel.isOffline && viewModel.mediaItems.isEmpty {
                        offlineView
                    } else if let error = viewModel.errorMessage, viewModel.mediaItems.isEmpty {
                        errorView(message: error)
                    } else if viewModel.mediaItems.isEmpty && viewModel.hasReachedEnd {
                        emptyStateView
                    } else {
                        // Card stack is always visible — rating prompt overlays on top
                        cardStackView
                            .allowsHitTesting(!showRatingPrompt)

                        // Rating prompt overlays on top of the card stack
                        if showRatingPrompt {
                            Color.black.opacity(0.4)
                                .ignoresSafeArea()
                                .transition(.opacity)
                            
                            InlineRatingPrompt(
                                itemTitle: pendingRatedTitle,
                                onRate: { stars in
                                    if let item = pendingRatedItem {
                                        do {
                                            try SwipedItemStore(context: modelContext).setPersonalRating(stars, for: item)
                                            HapticManager.seen()
                                            withAnimation(.easeIn(duration: 0.2)) {
                                                showRatingPrompt = false
                                            }
                                            pendingRatedItem = nil
                                        } catch {
                                            logger.error("Failed to save discover rating: \(error.localizedDescription)")
                                            persistenceErrorMessage = "We couldn't save your rating. Please try again."
                                        }
                                    }
                                },
                                onSkip: {
                                    withAnimation(.easeIn(duration: 0.2)) {
                                        showRatingPrompt = false
                                    }
                                    pendingRatedItem = nil
                                }
                            )
                            .id(pendingRatedItem?.uniqueID)
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Action buttons (Skip, Undo, Seen)
                if !viewModel.mediaItems.isEmpty && !showRatingPrompt {
                    actionButtonsView
                        .padding(.bottom, 16)
                }
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $detailItem) { item in
                DiscoverDetailView(
                    item: item,
                    onSeen: {
                        detailItem = nil
                        let swipedItem = viewModel.swipeRight(item: item, context: modelContext)
                        
                        // Skip rating prompt if item was already rated
                        guard swipedItem.personalRating == nil else { return }
                        
                        pendingRatedItem = swipedItem
                        pendingRatedTitle = item.title
                        
                        ratingPresentationTask?.cancel()
                        let uniqueID = swipedItem.uniqueID
                        ratingPresentationTask = Task {
                            try? await Task.sleep(for: .seconds(0.3))
                            guard !Task.isCancelled else { return }
                            guard pendingRatedItem?.uniqueID == uniqueID else { return }
                            guard canPresentDiscoverRating(for: uniqueID) else { return }
                            withAnimation(.easeOut(duration: 0.2)) {
                                showRatingPrompt = true
                            }
                        }
                    },
                    onSkip: {
                        detailItem = nil
                        viewModel.swipeLeft(item: item, context: modelContext)
                    },
                    onSaveToWatchlist: {
                        detailItem = nil
                        saveToWatchlist(item: item)
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .task {
                await viewModel.loadInitialContent(context: modelContext)
                viewModel.prefetchUpcomingImages()
            }
            .onAppear {
                viewModel.syncWithSettings(context: modelContext)
            }
            .overlay {
                if !hasSeenTutorial && !viewModel.mediaItems.isEmpty {
                    SwipeTutorialOverlay {
                        hasSeenTutorial = true
                    }
                    .transition(.opacity)
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
            .onDisappear {
                ratingPresentationTask?.cancel()
                ratingPresentationTask = nil
            }
        }
    }
    
    // MARK: - Card Stack View
    
    private var cardStackView: some View {
        ZStack {
            // Render cards in reverse order (bottom to top)
            ForEach(Array(viewModel.visibleCards.enumerated().reversed()), id: \.element.uniqueID) { index, item in
                MovieCardView(
                    item: item,
                    onSwipeLeft: {
                        viewModel.swipeLeft(item: item, context: modelContext)
                        resetTriggers()
                    },
                    onSwipeRight: {
                        // Card has already flown off (0.2s delay in MovieCardView)
                        let swipedItem = viewModel.swipeRight(item: item, context: modelContext)
                        resetTriggers()
                        
                        // Skip rating prompt if item was already rated (re-encounter via
                        // "Show Previously Swiped"). Only prompt for unrated items.
                        guard swipedItem.personalRating == nil else { return }
                        
                        pendingRatedItem = swipedItem
                        pendingRatedTitle = item.title
                        
                        // Brief pause for next card to settle, then show rating prompt
                        ratingPresentationTask?.cancel()
                        let uniqueID = swipedItem.uniqueID
                        ratingPresentationTask = Task {
                            try? await Task.sleep(for: .seconds(0.15))
                            guard !Task.isCancelled else { return }
                            guard pendingRatedItem?.uniqueID == uniqueID else { return }
                            guard canPresentDiscoverRating(for: uniqueID) else { return }
                            withAnimation(.easeOut(duration: 0.2)) {
                                showRatingPrompt = true
                            }
                        }
                    },
                    onInfoTap: { detailItem = item },
                    onSaveToWatchlist: {
                        saveToWatchlist(item: item)
                    },
                    isTopCard: index == 0,
                    stackIndex: index,
                    triggerSwipeLeft: $triggerSwipeLeft,
                    triggerSwipeRight: $triggerSwipeRight
                )
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Action Buttons View
    
    private var actionButtonsView: some View {
        HStack(spacing: 20) {
            // Skip Button (Left)
            Button {
                triggerSwipeLeft = true
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "xmark")
                        .font(.title2.weight(.bold))
                    Text("Skip")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.white)
                .frame(width: 70, height: 70)
                .background(
                    Circle()
                        .fill(Color.gray.opacity(0.8))
                        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Skip this title")
            
            // Undo Button (Center)
            Button {
                viewModel.undoLastSwipe(context: modelContext)
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.title3.weight(.semibold))
                    Text("Undo")
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(viewModel.canUndo ? .orange : .gray.opacity(0.5))
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canUndo)
            .accessibilityLabel("Undo last swipe")
            
            // Seen Button (Right)
            Button {
                triggerSwipeRight = true
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.title2.weight(.bold))
                    Text("Seen")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.white)
                .frame(width: 70, height: 70)
                .background(
                    Circle()
                        .fill(Color.green)
                        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Mark as already seen")
        }
        .padding(.horizontal, 40)
    }
    
    private func resetTriggers() {
        triggerSwipeLeft = false
        triggerSwipeRight = false
    }

    // MARK: - Watchlist
    
    /// Save the given item to the watchlist and remove it from the stack
    /// without triggering a rating prompt.
    /// Delegates to the ViewModel's `swipeUp` which enforces direction transition
    /// policy (won't demote "seen" items) and records undo state.
    private func saveToWatchlist(item: MediaItem) {
        viewModel.swipeUp(item: item, context: modelContext)
    }

    private func canPresentDiscoverRating(for uniqueID: String) -> Bool {
        let id = uniqueID
        let descriptor = FetchDescriptor<SwipedItem>(
            predicate: #Predicate<SwipedItem> { $0.uniqueID == id }
        )
        return (try? modelContext.fetch(descriptor).first) != nil
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Offline View
    
    private var offlineView: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            
            Text("You're Offline")
                .font(.title2.weight(.semibold))
            
            Text("Connect to the internet to\ndiscover new titles.\nYour library is still available!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                Task {
                    await viewModel.resetAndLoadContent()
                }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.body.weight(.semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
            }
        }
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundStyle(.orange)
            
            Text("Oops!")
                .font(.title2.weight(.semibold))
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                Task {
                    await viewModel.resetAndLoadContent()
                }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.body.weight(.semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
            }
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundStyle(.green)
            
            Text("All Caught Up!")
                .font(.title2.weight(.semibold))
            
            Text("You've seen everything in \"\(viewModel.selectedMethod.rawValue)\".\nTry a different discovery method!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                showingDiscoveryPicker = true
            } label: {
                Label("Browse Options", systemImage: "rectangle.stack")
                    .font(.body.weight(.semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.gray.opacity(0.15), in: Capsule())
                    .foregroundStyle(.primary)
            }
            .sheet(isPresented: $showingDiscoveryPicker) {
                DiscoveryMethodPicker(selectedMethod: $viewModel.selectedMethod)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
    
}

// MARK: - Preview

#Preview {
    SwipeView()
        .modelContainer(for: [SwipedItem.self, UserList.self, ListEntry.self, FollowedList.self, FollowedListItem.self], inMemory: true)
}
