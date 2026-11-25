import Foundation
import Observation

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

struct CatalogMatch: Identifiable {
    let id: String
    let title: String
    let artist: String
    let url: URL

    init?(recommendation: SongRecommendation, candidates: [CatalogSong]) {
        let matchingCredits = candidates.filter(recommendation.matchesCredits)
        guard let song = matchingCredits.first,
              matchingCredits.allSatisfy({ $0.id == song.id }),
              song.isAvailable,
              let url = song.url,
              url.scheme == "https", url.host == "music.apple.com",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.user == nil, components.password == nil, components.port == nil else { return nil }

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
}

private func sameCredit(_ first: String, _ second: String) -> Bool {
    first.trimmingCharacters(in: .whitespacesAndNewlines)
        .compare(
            second.trimmingCharacters(in: .whitespacesAndNewlines),
            options: [.caseInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        ) == .orderedSame
}

typealias SongRecommendations = (RecentSong) async throws -> [SongRecommendation]

@Observable
final class SimilarSongs {
    enum Phase {
        case loading, finished, failed
    }

    let seed: RecentSong
    private(set) var phase = Phase.loading
    private(set) var matches: [CatalogMatch] = []
    private(set) var attempt = 0

    private let appleMusic: any AppleMusic
    private let recommendations: SongRecommendations
    private var pendingRecommendations: ArraySlice<SongRecommendation>?

    init(seed: RecentSong, appleMusic: any AppleMusic, recommendations: @escaping SongRecommendations) {
        self.seed = seed
        self.appleMusic = appleMusic
        self.recommendations = recommendations
    }

    func load() async {
        do {
            if pendingRecommendations == nil {
                let songs = try await recommendations(seed)
                try Task.checkCancellation()
                pendingRecommendations = songs[...]
            }
            while let recommendation = pendingRecommendations?.first {
                let candidates = try await appleMusic.catalogSongs(for: recommendation)
                try Task.checkCancellation()
                if let match = CatalogMatch(recommendation: recommendation, candidates: candidates),
                   !matches.contains(where: { $0.id == match.id }) {
                    matches.append(match)
                }
                pendingRecommendations?.removeFirst()
            }
            phase = .finished
        } catch {
            if !Task.isCancelled {
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
        await appleMusic.openSongURL(match.url)
    }
}
