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
    private let artistURL = URL(string: "https://music.apple.com/us/artist/chvrches/566867492")!

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

    func songRecommendations(for seed: RecentSong) async throws -> [SongRecommendation] {
        guard seed.title == "Midnight City", seed.artist == "M83" else {
            throw FixtureError.unavailable
        }
        switch scenario {
        case "similarSongs":
            recommendationRequests += 1
            guard recommendationRequests == 1 else { throw FixtureError.unavailable }
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

    func artistRecommendations(for artist: String) async throws -> [ArtistRecommendation] {
        guard artist == "M83" else { throw FixtureError.unavailable }
        guard scenario == "similarArtists" else { return ArtistRecommendation.samples(for: artist) }
        let chvrches = ArtistRecommendation(name: "CHVRCHES", catalogID: "566867492")
        return [
            chvrches, ArtistRecommendation(name: "Phoenix", catalogID: nil),
            ArtistRecommendation(name: "Unavailable Artist", catalogID: "5000"),
            ArtistRecommendation(name: "Missing URL", catalogID: "3000"),
            ArtistRecommendation(name: "Wrong URL", catalogID: "4000"),
            chvrches, ArtistRecommendation(name: "Purity Ring", catalogID: "461030854")
        ]
    }

    func catalogSongs(for recommendation: SongRecommendation) async throws -> [CatalogSong] {
        if scenario == "similarSongsEmpty" { return [] }
        switch recommendation.title {
        case "Genesis":
            return [
                listing(for: recommendation, id: "6000", url: directURL("6000")),
                CatalogSong(id: "6001", title: "Genesis", artist: "Cover Artist", album: "Cover", isAvailable: true, url: directURL("6001")),
                CatalogSong(id: "6002", title: "Genesis (Live)", artist: "Justice", album: "Live", isAvailable: true, url: directURL("6002"))
            ]
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

    func catalogArtists(for recommendation: ArtistRecommendation) async throws -> [CatalogArtist] {
        switch recommendation.name {
        case "Kavinsky":
            return [
                CatalogArtist(id: "6000", name: "Kavinsky", url: artistPage("6000")),
                CatalogArtist(id: "115429828", name: "Kavinsky", url: artistPage("115429828"))
            ]
        case "Same Name":
            return [CatalogArtist(id: "7000", name: "Same Name", url: artistPage("7000"))]
        case "CHVRCHES":
            return [
                CatalogArtist(id: "1001", name: "CHVRCHES", url: artistPage("1001")),
                CatalogArtist(id: "566867492", name: "CHVRCHES", url: artistURL)
            ]
        case "Purity Ring":
            if scenario == "modeSwitch" {
                // Model a catalog response that arrives even after the caller is cancelled.
                try await Task { try await Task.sleep(for: .seconds(7)) }.value
            }
            return [CatalogArtist(id: "461030854", name: "Purity Ring", url: artistPage("461030854"))]
        case "Phoenix":
            return ["2000", "2001"].map { CatalogArtist(id: $0, name: "Phoenix", url: artistPage($0)) }
        case "Missing URL":
            return [CatalogArtist(id: "3000", name: "Missing URL", url: nil)]
        case "Wrong URL":
            return [CatalogArtist(id: "4000", name: "Wrong URL", url: artistPage("4001"))]
        default:
            return []
        }
    }

    func openCatalogURL(_ url: URL) async -> Bool {
        if scenario == "lastFM" {
            guard url == directURL("6000") || url == artistPage("115429828") else { return false }
            MusicKitClient().openSettings()
            return true
        }
        guard url == (scenario == "similarArtists" ? artistURL : songURL) else { return false }
        openAttempts += 1
        if scenario == "similarSongsRetry" && openAttempts == 1 {
            try? await Task.sleep(for: .seconds(4))
        }
        guard openAttempts > 1 else { return false }
        // Use Settings as a stand-in destination so the test can observe a successful handoff.
        MusicKitClient().openSettings()
        return true
    }

    private func artistPage(_ id: String) -> URL? {
        URL(string: "https://music.apple.com/us/artist/\(id)")
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
