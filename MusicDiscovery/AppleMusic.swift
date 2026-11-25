import MusicKit
import UIKit

struct RecentSong: Hashable, Identifiable {
    let title: String
    let artist: String

    var id: Self { self }
}

protocol AppleMusic {
    var authorization: MusicAuthorization.Status { get }
    func requestAuthorization() async -> MusicAuthorization.Status
    func recentlyPlayed() async throws -> [RecentSong]
    func catalogSongs(for recommendation: SongRecommendation) async throws -> [CatalogSong]
    func catalogArtists(for recommendation: ArtistRecommendation) async throws -> [CatalogArtist]
    func openCatalogURL(_ url: URL) async -> Bool
    func openSettings()
}

struct MusicKitClient: AppleMusic {
    var authorization: MusicAuthorization.Status { MusicAuthorization.currentStatus }

    func requestAuthorization() async -> MusicAuthorization.Status {
        await MusicAuthorization.request()
    }

    func recentlyPlayed() async throws -> [RecentSong] {
        let response = try await MusicRecentlyPlayedRequest<Song>().response()
        return response.items.map { RecentSong(title: $0.title, artist: $0.artistName) }
    }

    func catalogSongs(for recommendation: SongRecommendation) async throws -> [CatalogSong] {
        let request = MusicCatalogSearchRequest(
            term: "\(recommendation.title) \(recommendation.artist)",
            types: [Song.self]
        )
        var page = try await request.response().songs
        var candidates: [CatalogSong] = []

        while true {
            try Task.checkCancellation()
            for song in page {
                let candidate = CatalogSong(
                    id: song.id.rawValue,
                    title: song.title,
                    artist: song.artistName,
                    album: song.albumTitle,
                    isAvailable: song.playParameters != nil,
                    url: song.url
                )
                guard recommendation.matchesCredits(of: candidate),
                      candidates.first?.id != candidate.id else { continue }
                candidates.append(candidate)
                // A second distinct listing makes this Recommendation ambiguous.
                if candidates.count == 2 { return candidates }
            }
            guard page.hasNextBatch, let nextPage = try await page.nextBatch() else { return candidates }
            page = nextPage
        }
    }

    func catalogArtists(for recommendation: ArtistRecommendation) async throws -> [CatalogArtist] {
        guard let id = recommendation.catalogID else { return [] }
        let request = MusicCatalogResourceRequest<Artist>(matching: \.id, memberOf: [MusicItemID(id)])
        let response = try await request.response()
        return response.items.map { CatalogArtist(id: $0.id.rawValue, name: $0.name, url: $0.url) }
    }

    func openCatalogURL(_ url: URL) async -> Bool {
        await UIApplication.shared.open(url)
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
