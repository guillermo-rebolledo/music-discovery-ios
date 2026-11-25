import SwiftUI

@main
struct MusicDiscoveryApp: App {
    private let appleMusic: any AppleMusic
    @State private var recentlyPlayed: RecentlyPlayed

    init() {
        let appleMusic = Self.appleMusic()
        self.appleMusic = appleMusic
        _recentlyPlayed = State(initialValue: RecentlyPlayed(appleMusic: appleMusic))
    }

    var body: some Scene {
        WindowGroup {
            RecentlyPlayedView(recentlyPlayed: recentlyPlayed) { selection in
                Discovery(selection: selection, appleMusic: appleMusic, recommendations: recommendations)
            }
        }
    }

    private func recommendations(for selection: DiscoverySelection) async throws -> [Recommendation] {
        switch selection.mode {
        case .songs:
            #if DEBUG
            if let fixture = appleMusic as? AppleMusicFixture {
                return try await fixture.songRecommendations(for: selection.song).map(Recommendation.song)
            }
            #endif
            return SongRecommendation.samples(for: selection.song).map(Recommendation.song)
        case .artists:
            #if DEBUG
            if let fixture = appleMusic as? AppleMusicFixture {
                return try await fixture.artistRecommendations(for: selection.song.artist).map(Recommendation.artist)
            }
            #endif
            return ArtistRecommendation.samples(for: selection.song.artist).map(Recommendation.artist)
        }
    }

    private static func appleMusic() -> any AppleMusic {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-recentlyPlayedFixture"),
           let name = arguments.dropFirst(index + 1).first {
            return AppleMusicFixture(scenario: name)
        }
        #endif
        return MusicKitClient()
    }
}
