import SwiftUI
import SwiftData

/// Horizontal scroll section showing lists the user is following.
/// Only visible when the user follows at least one list.
/// Placed between Watchlist and Smart Collections in FlickSwiperHomeView.
struct FollowingSection: View {
    @Query(sort: \FollowedList.followedAt, order: .reverse)
    private var followedLists: [FollowedList]
    
    @Query private var allFollowedItems: [FollowedListItem]
    
    /// Returns nil if user follows no lists, allowing the parent to skip rendering.
    var isEmpty: Bool { followedLists.isEmpty }
    
    var body: some View {
        if !followedLists.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Following")
                    .font(.title3.weight(.bold))
                    .padding(.horizontal, 16)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(followedLists) { list in
                            NavigationLink(value: list) {
                                FollowedListCard(
                                    followedList: list,
                                    firstPosterPath: firstPosterPath(for: list)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
    
    /// Finds the first item's poster path for a given followed list.
    private func firstPosterPath(for list: FollowedList) -> String? {
        allFollowedItems
            .filter { $0.followedListID == list.firestoreDocID }
            .sorted { $0.sortOrder < $1.sortOrder }
            .first?
            .posterPath
    }
}
