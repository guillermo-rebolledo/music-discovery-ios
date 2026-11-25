import Foundation
import Observation

enum DiscoveryMode: String, CaseIterable {
    case songs = "Similar Songs"
    case artists = "Similar Artists"
}

struct DiscoverySelection: Hashable, Identifiable {
    let song: RecentSong
    let mode: DiscoveryMode

    var id: Self { self }
}

struct SongRecommendation {
    let title: String
    let artist: String
    let album: String

    func matchesCredits(of song: CatalogSong) -> Bool {
        guard let album = song.album else { return false }
        return sameCredit(song.title, title)
            && sameCredit(song.artist, artist)
            && sameCredit(album, self.album)
    }

    static func samples(for seed: RecentSong) -> [Self] {
        [
            Self(title: "A Real Hero (feat. Electric Youth)", artist: "College", album: "A Real Hero - EP"),
            Self(title: "Intro", artist: "The xx", album: "xx")
        ].filter { recommendation in
            !sameCredit(recommendation.title, seed.title) || !sameCredit(recommendation.artist, seed.artist)
        }
    }
}

struct CatalogSong {
    let id: String
    let title: String
    let artist: String
    let album: String?
    let isAvailable: Bool
    let url: URL?
}

struct ArtistRecommendation {
    let name: String
    let catalogID: String?

    static func samples(for artist: String) -> [Self] {
        let samples: [Self] = if sameCredit(artist, "Daft Punk") {
            [Self(name: "Justice", catalogID: "145072812"), Self(name: "Air", catalogID: "5641488")]
        } else {
            [Self(name: "CHVRCHES", catalogID: "566867492"), Self(name: "Purity Ring", catalogID: "461030854")]
        }
        // This sample has no identity evidence to distinguish same-name artists.
        return (samples + [Self(name: "Phoenix", catalogID: nil)]).filter { !sameCredit($0.name, artist) }
    }
}

struct CatalogArtist {
    let id: String
    let name: String
    let url: URL?
}

struct CatalogMatch: Identifiable {
    let id: String
    let title: String
    let artist: String?
    let url: URL

    init?(recommendation: SongRecommendation, candidates: [CatalogSong]) {
        let matchingCredits = candidates.filter(recommendation.matchesCredits)
        guard let song = matchingCredits.first,
              matchingCredits.allSatisfy({ $0.id == song.id }),
              song.isAvailable,
              let url = song.url,
              let components = Self.appleMusicComponents(for: url) else { return nil }

        // Apple Music supplies both direct song URLs and album URLs with a song ID.
        let path = url.pathComponents
        let trackIDs = components.queryItems?.filter { $0.name == "i" }.map(\.value)
        guard path.count >= 4,
              (path[2] == "song" && path.last == song.id)
                || (path[2] == "album" && trackIDs == [song.id])
        else { return nil }

        id = song.id
        title = song.title
        artist = song.artist
        self.url = url
    }

    init?(recommendation: ArtistRecommendation, candidates: [CatalogArtist]) {
        guard let verifiedID = recommendation.catalogID,
              let artist = candidates.first(where: {
                  $0.id == verifiedID && sameCredit($0.name, recommendation.name)
              }),
              let url = artist.url,
              Self.appleMusicComponents(for: url) != nil else { return nil }
        let path = url.pathComponents
        guard (4...5).contains(path.count), path[2] == "artist", path.last == artist.id else { return nil }

        id = artist.id
        title = artist.name
        self.artist = nil
        self.url = url
    }

    private static func appleMusicComponents(for url: URL) -> URLComponents? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "https", components.host == "music.apple.com",
              components.user == nil, components.password == nil, components.port == nil else { return nil }
        return components
    }
}

private func sameCredit(_ first: String, _ second: String) -> Bool {
    first.trimmingCharacters(in: .whitespacesAndNewlines)
        .compare(
            second.trimmingCharacters(in: .whitespacesAndNewlines),
            options: [.caseInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        ) == .orderedSame
}

enum Recommendation {
    case song(SongRecommendation)
    case artist(ArtistRecommendation)
}

@Observable
final class Discovery {
    enum Phase {
        case loading, finished, failed
    }

    let song: RecentSong
    private(set) var mode: DiscoveryMode
    private(set) var phase = Phase.loading
    private(set) var matches: [CatalogMatch] = []
    private(set) var attempt = 0

    private let appleMusic: any AppleMusic
    private let recommendations: (DiscoverySelection) async throws -> [Recommendation]
    private var pendingRecommendations: ArraySlice<Recommendation>?

    init(
        selection: DiscoverySelection,
        appleMusic: any AppleMusic,
        recommendations: @escaping (DiscoverySelection) async throws -> [Recommendation]
    ) {
        song = selection.song
        mode = selection.mode
        self.appleMusic = appleMusic
        self.recommendations = recommendations
    }

    func select(_ mode: DiscoveryMode) {
        guard self.mode != mode else { return }
        self.mode = mode
        pendingRecommendations = nil
        matches.removeAll()
        phase = .loading
        attempt += 1
    }

    func load(attempt: Int) async {
        guard isCurrent(attempt) else { return }
        do {
            if pendingRecommendations == nil {
                let results = try await recommendations(DiscoverySelection(song: song, mode: mode))
                guard isCurrent(attempt) else { return }
                pendingRecommendations = results[...]
            }
            while let recommendation = pendingRecommendations?.first {
                let match = try await catalogMatch(for: recommendation)
                guard isCurrent(attempt) else { return }
                if let match, !matches.contains(where: { $0.id == match.id }) {
                    matches.append(match)
                }
                pendingRecommendations?.removeFirst()
            }
            phase = .finished
        } catch {
            if isCurrent(attempt) {
                phase = .failed
            }
        }
    }

    func retry() {
        guard phase == .failed else { return }
        phase = .loading
        attempt += 1
    }

    func open(_ match: CatalogMatch) async -> Bool {
        await appleMusic.openCatalogURL(match.url)
    }

    private func isCurrent(_ attempt: Int) -> Bool {
        attempt == self.attempt && !Task.isCancelled
    }

    private func catalogMatch(for recommendation: Recommendation) async throws -> CatalogMatch? {
        switch recommendation {
        case .song(let song):
            let candidates = try await appleMusic.catalogSongs(for: song)
            return CatalogMatch(recommendation: song, candidates: candidates)
        case .artist(let artist):
            let candidates = try await appleMusic.catalogArtists(for: artist)
            return CatalogMatch(recommendation: artist, candidates: candidates)
        }
    }
}
