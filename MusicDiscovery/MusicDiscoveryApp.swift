import SwiftUI

@main
struct MusicDiscoveryApp: App {
    @State private var recentlyPlayed = RecentlyPlayed(appleMusic: Self.appleMusic())

    var body: some Scene {
        WindowGroup {
            RecentlyPlayedView(recentlyPlayed: recentlyPlayed)
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
