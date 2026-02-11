# FlickSwiper

**A gesture-driven iOS app for discovering, tracking, and organizing movies & TV shows.**

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-5-blue.svg)](https://developer.apple.com/swiftui/)
[![SwiftData](https://img.shields.io/badge/SwiftData-1.0-green.svg)](https://developer.apple.com/documentation/swiftdata)
[![iOS](https://img.shields.io/badge/iOS-17.0%2B-lightgrey.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

<!-- Screenshots placeholder — replace with actual App Store screenshots -->
<!-- <p align="center">
  <img src="docs/screenshots/discover.png" width="200" />
  <img src="docs/screenshots/library.png" width="200" />
  <img src="docs/screenshots/search.png" width="200" />
  <img src="docs/screenshots/settings.png" width="200" />
</p> -->

## Overview

FlickSwiper brings a Tinder-style swipe interface to movie and TV show discovery. Swipe right to mark something as seen, left to skip, or up to save it to your watchlist. The app pulls content from [The Movie Database (TMDB)](https://www.themoviedb.org/) and stores everything locally on-device using SwiftData — no accounts, no analytics, no tracking.

### Why I Built This

I wanted a quick, tactile way to log what I've watched without the overhead of full-featured tracking apps. The swipe mechanic makes it feel like a game rather than a chore, and the library features grew organically from there.

## Features

**Discover** — Browse trending, popular, top-rated, now playing, upcoming, and 11 streaming services. Filter by genre, year range, and content type. Sort streaming catalogs by popularity, rating, release date, or alphabetically.

**Swipe & Rate** — Swipe right (seen), left (skip), or up (watchlist). After marking something as seen, an inline rating prompt (1–5 stars) appears with a smooth scale+opacity transition over a dimmed card stack.

**Search** — Debounced TMDB search with instant results. Green checkmarks and blue bookmarks indicate items already in your library or watchlist.

**Library** — Smart collections auto-generated from your data (favorites, genres, platforms, recently added). Create custom lists, add items individually or in bulk via a full-screen selectable grid. Apple-style edit mode with multi-select, bulk delete, and share.

**Watchlist → Seen** — When you finally watch something, tap "I've Watched This" to move it from watchlist to seen with a rating prompt.

## Technical Highlights

- **SwiftData with Versioned Schema Migration** — V1→V2 lightweight migration adds rating, genre, and platform fields without data loss. UUID-based join models (`UserList` ↔ `ListEntry` ↔ `SwipedItem`) avoid SwiftData relationship pitfalls.
- **Actor-Isolated Networking** — `TMDBService` is an `actor`, ensuring thread-safe API access. Handles 429 rate limiting with automatic retry using the `Retry-After` header.
- **Gesture-Driven Animation Orchestration** — Card swipe animations in three directions with precise timing between fly-off animation (0.2s delay), array mutation, and rating prompt presentation to prevent visual artifacts.
- **Image Caching & Prefetch** — Enlarged `URLCache` (50MB memory / 200MB disk) with a custom `RetryAsyncImage` wrapper that retries failed loads. Prefetches both w500 posters and w185 thumbnails.
- **Protocol-Oriented Service Layer** — `MediaServiceProtocol` with a `MockMediaService` ready for unit testing.
- **Accessibility** — Custom accessibility actions on swipe cards, descriptive labels on all interactive elements, proper modifier ordering.

For a deeper look at architecture decisions, see [ARCHITECTURE.md](ARCHITECTURE.md).

## Project Structure

```
FlickSwiper/
├── FlickSwiperApp.swift              # App entry, URLCache config, ModelContainer + migration
├── ContentView.swift                 # Tab navigation (Discover, Search, Library, Settings)
├── Config/                           # xcconfig-based API key management
├── Models/
│   ├── SwipedItem.swift              # SwiftData model — swipes, ratings, genres, platform
│   ├── MediaItem.swift               # Unified media type for UI consumption
│   ├── TMDBModels.swift              # TMDB API response decodables
│   ├── SchemaVersions.swift          # Versioned schema + migration plan
│   ├── UserList.swift / ListEntry.swift  # Custom list models (UUID join)
│   ├── DiscoveryMethod.swift         # Discovery methods + streaming provider config
│   ├── Genre.swift                   # Genre model for filtering
│   └── StreamingSortOption.swift     # Sort options for streaming content
├── ViewModels/
│   ├── SwipeViewModel.swift          # Discovery feed, swipe logic, filtering, prefetch
│   └── SearchViewModel.swift         # Debounced search with Task cancellation
├── Views/
│   ├── SwipeView.swift               # Card stack, rating prompt, undo
│   ├── MovieCardView.swift           # Swipeable card with gestures + overlays
│   ├── SearchView.swift              # Search tab with library-aware results
│   ├── FlickSwiperHomeView.swift     # Library tab — watchlist, collections, lists
│   ├── FilteredGridView.swift        # Reusable grid with edit mode + share
│   ├── 15+ additional views...       # Detail views, pickers, cards, sheets
│   └── Pickers/                      # Discovery method, genre, year pickers
├── Services/
│   ├── TMDBService.swift             # Actor-based TMDB API client
│   └── MediaServiceProtocol.swift    # Protocol + mock for testing
└── Utils/
    ├── Constants.swift               # App-wide constants
    ├── Extensions.swift              # Helper extensions
    ├── GenreMap.swift                # TMDB genre ID → name/icon mapping
    ├── HapticManager.swift           # Haptic feedback patterns
    └── RetryAsyncImage.swift         # AsyncImage with retry logic
```

## Getting Started

### Requirements

- iOS 17.0+
- Xcode 15.0+
- A free [TMDB API Key](https://www.themoviedb.org/settings/api)

### Setup

1. Clone the repo:
   ```bash
   git clone https://github.com/mit112/FlickSwiper.git
   cd FlickSwiper
   ```

2. Configure your API key:
   ```bash
   cp FlickSwiper/Config/Secrets.xcconfig.template FlickSwiper/Config/Secrets.xcconfig
   ```
   Open `Secrets.xcconfig` and replace `YOUR_TOKEN_HERE` with your TMDB API Read Access Token (v4 auth).

3. Open `FlickSwiper.xcodeproj` in Xcode and run (⌘R).

> **Note:** `Secrets.xcconfig` is gitignored. You need to create it locally before building.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI 5 |
| Persistence | SwiftData with versioned schema migration |
| Networking | URLSession + async/await, actor isolation |
| API | TMDB v3 (movies, TV, search, streaming providers) |
| Architecture | MVVM with @Observable |
| Minimum Target | iOS 17.0 |

## Privacy

All data is stored locally on device. No accounts, no analytics, no tracking. Network requests go only to TMDB for content metadata and poster images.

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Movie and TV show data provided by [The Movie Database (TMDB)](https://www.themoviedb.org/). This app uses the TMDB API but is not endorsed or certified by TMDB.
