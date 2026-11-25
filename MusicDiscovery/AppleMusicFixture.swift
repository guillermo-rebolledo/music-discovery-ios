#if DEBUG
import MusicKit

final class AppleMusicFixture: AppleMusic {
    private(set) var authorization: MusicAuthorization.Status

    private let scenario: String
    private var requestCount = 0

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

    func openSettings() {
        authorization = .authorized
        MusicKitClient().openSettings()
    }

    private enum FixtureError: Error {
        case unavailable
    }
}
#endif
