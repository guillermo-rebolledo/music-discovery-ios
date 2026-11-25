#if DEBUG
import Foundation
import MusicKit

final class AppleMusicFixture: AppleMusic {
    private(set) var authorization: MusicAuthorization.Status

    private let scenario: String
    private var requestCount = 0
    private var recommendationRequests = 0
    private var failedLookup = false
    private var openAttempts = 0

    private let first = SongRecommendation(title: "A Real Hero", artist: "College", album: "Studio Album")
    private let second = SongRecommendation(title: "Intro", artist: "The xx", album: "xx")
    private let songURL = URL(string: "https://music.apple.com/us/album/studio-album/9000?i=1001")!

    init(scenario: String) {
        self.scenario = scenario
        switch scenario {
        case "permission": authorization = .notDetermined
        case "denied": authorization = .denied
        case "restricted": authorization = .restricted
        default: authorization = .authorized
        }
    }

    func requestAuthorization() async -> MusicAuthorization.Status {
        authorization = .authorized
        return authorization
    }

    func recentlyPlayed() async throws -> [RecentSong] {
        requestCount += 1
        if scenario == "retry" && requestCount == 1 {
            throw FixtureError.unavailable
        }
        if scenario == "empty" && requestCount == 1 {
            return []
        }
        if scenario == "refresh" && requestCount > 1 {
            return [RecentSong(title: "Archangel", artist: "Burial")]
        }
        if scenario == "accessibility" {
            return [
                RecentSong(
                    title: "A song title long enough to wrap across multiple lines",
                    artist: "An artist credit that also wraps"
                )
            ]
        }
        return [
            RecentSong(title: "Midnight City", artist: "M83"),
            RecentSong(title: "Digital Love", artist: "Daft Punk")
        ]
    }

    func recommendations(for seed: RecentSong) async throws -> [SongRecommendation] {
        recommendationRequests += 1
        guard seed.title == "Midnight City", seed.artist == "M83", recommendationRequests == 1 else {
            throw FixtureError.unavailable
        }
        switch scenario {
        case "similarSongs":
            try await Task.sleep(for: .seconds(4))
            return [
                first,
                SongRecommendation(title: "Missing URL", artist: "Sample Artist", album: "Sample Album"),
                SongRecommendation(title: "Unavailable", artist: "Sample Artist", album: "Sample Album"),
                SongRecommendation(title: "Ambiguous", artist: "Sample Artist", album: "Sample Album"),
                first, second
            ]
        default:
            return [first, second]
        }
    }

    func catalogSongs(for recommendation: SongRecommendation) async throws -> [CatalogSong] {
        if scenario == "similarSongsEmpty" { return [] }
        switch recommendation.title {
        case first.title:
            return [
                CatalogSong(id: "1002", title: first.title, artist: "Cover Artist", album: first.album, isAvailable: true, url: directURL("1002")),
                CatalogSong(id: "1003", title: "A Real Hero (Live)", artist: first.artist, album: first.album, isAvailable: true, url: directURL("1003")),
                CatalogSong(id: "1004", title: first.title, artist: first.artist, album: "Live Album", isAvailable: true, url: directURL("1004")),
                CatalogSong(id: "1001", title: first.title, artist: first.artist, album: first.album, isAvailable: true, url: songURL)
            ]
        case second.title:
            if scenario == "similarSongsRetry" && !failedLookup {
                failedLookup = true
                throw FixtureError.unavailable
            }
            return [listing(for: recommendation, id: "2000", url: directURL("2000"))]
        case "Missing URL":
            return [listing(for: recommendation, id: "3000", url: nil)]
        case "Unavailable":
            return [listing(for: recommendation, id: "4000", url: directURL("4000"), isAvailable: false)]
        case "Ambiguous":
            return ["5000", "5001"].map { listing(for: recommendation, id: $0, url: directURL($0)) }
        default:
            return []
        }
    }

    func openSongURL(_ url: URL) async -> Bool {
        guard url == songURL else { return false }
        openAttempts += 1
        guard openAttempts > 1 else { return false }
        // Use Settings as a stand-in destination so the test can observe a successful handoff.
        MusicKitClient().openSettings()
        return true
    }

    private func directURL(_ id: String) -> URL? {
        URL(string: "https://music.apple.com/us/song/\(id)")
    }

    private func listing(for recommendation: SongRecommendation, id: String, url: URL?, isAvailable: Bool = true) -> CatalogSong {
        CatalogSong(
            id: id, title: recommendation.title, artist: recommendation.artist,
            album: recommendation.album, isAvailable: isAvailable, url: url
        )
    }

    func openSettings() {
        authorization = .authorized
        MusicKitClient().openSettings()
    }

    private enum FixtureError: Error {
        case unavailable
    }
}
#endif
