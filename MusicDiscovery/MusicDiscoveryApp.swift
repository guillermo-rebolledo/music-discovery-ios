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
            RecentlyPlayedView(recentlyPlayed: recentlyPlayed) { seed in
                SimilarSongs(seed: seed, appleMusic: appleMusic, recommendations: recommendations)
            }
        }
    }

    private func recommendations(for seed: RecentSong) async throws -> [SongRecommendation] {
        #if DEBUG
        if let fixture = appleMusic as? AppleMusicFixture {
            return try await fixture.recommendations(for: seed)
        }
        #endif
        return SongRecommendation.samples(for: seed)
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
