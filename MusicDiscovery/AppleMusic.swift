import MusicKit
import UIKit

struct RecentSong {
    let title: String
    let artist: String
}

protocol AppleMusic {
    var authorization: MusicAuthorization.Status { get }
    func requestAuthorization() async -> MusicAuthorization.Status
    func recentlyPlayed() async throws -> [RecentSong]
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

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
