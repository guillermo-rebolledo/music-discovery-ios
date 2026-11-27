import SwiftUI

@main
struct MusicDiscoveryApp: App {
    private let appleMusic: any AppleMusic
    private let lastFM: LastFMDiscovery?
    @State private var recentlyPlayed: RecentlyPlayed

    init() {
        let appleMusic = Self.appleMusic()
        self.appleMusic = appleMusic
        lastFM = Self.lastFMDiscovery(usesAppleMusicFixture: !(appleMusic is MusicKitClient))
        _recentlyPlayed = State(initialValue: RecentlyPlayed(appleMusic: appleMusic))
    }

    var body: some Scene {
        WindowGroup {
            RecentlyPlayedView(recentlyPlayed: recentlyPlayed, lastFM: lastFM) { selection in
                Discovery(selection: selection, appleMusic: appleMusic, recommendations: recommendations)
            }
        }
    }

    private func recommendations(for selection: DiscoverySelection) async throws -> [Recommendation] {
        if let lastFM {
            return try await lastFM.recommendations(for: selection)
        }
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

    private static func lastFMDiscovery(usesAppleMusicFixture: Bool) -> LastFMDiscovery? {
        #if DEBUG
        let process = ProcessInfo.processInfo
        if let index = process.arguments.firstIndex(of: "-lastFMFixture"),
           let scenario = process.arguments.dropFirst(index + 1).first {
            let fixture = LastFMFixture(scenario: scenario)
            let client = LastFMClient(apiKey: "test-key", transport: fixture.respond)
            let discovery = LastFMDiscovery(client: client, defaults: nil)
            discovery.fixture = fixture
            return discovery
        }
        guard !usesAppleMusicFixture,
              let key = process.environment["LAST_FM_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty else { return nil }
        let session = URLSession(configuration: .ephemeral)
        let client = LastFMClient(apiKey: key) { try await session.data(for: $0) }
        return LastFMDiscovery(client: client, defaults: .standard)
        #else
        return nil
        #endif
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
