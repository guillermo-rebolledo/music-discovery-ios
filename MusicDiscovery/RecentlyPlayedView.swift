import SwiftUI

struct RecentlyPlayedView: View {
    let recentlyPlayed: RecentlyPlayed

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    private var background: Color {
        colorScheme == .dark
            ? Color(red: 0.10, green: 0.10, blue: 0.11)
            : Color(red: 0.94, green: 0.94, blue: 0.93)
    }

    private var accent: Color {
        colorScheme == .dark
            ? Color(red: 1, green: 0.47, blue: 0.34)
            : Color(red: 0.71, green: 0.19, blue: 0.09)
    }

    private var secondaryText: Color {
        colorScheme == .dark ? Color(white: 0.72) : Color(white: 0.32)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Recently Played")
                    .font(.largeTitle.monospaced().weight(.bold))
                    .accessibilityAddTraits(.isHeader)

                Divider()

                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .background(background.ignoresSafeArea())
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                Task { await recentlyPlayed.recheckAccess() }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch recentlyPlayed.state {
        case .checkingAccess, .requestingAccess:
            ProgressView("Checking Apple Music access…")
        case .needsPermission:
            message("Connect Apple Music", detail: "Allow Apple Music access to see the songs you’ve played recently.")
            primaryButton("Allow Apple Music Access") {
                Task { await recentlyPlayed.requestAccess() }
            }
        case .denied:
            message("Apple Music access is off", detail: "To see your recently played songs, allow access in Settings.")
            primaryButton("Open Settings", action: recentlyPlayed.openSettings)
        case .restricted:
            message("Apple Music access is restricted", detail: "This iPhone’s restrictions prevent access to Apple Music.")
        case .loading:
            ProgressView("Loading recently played songs…")
        case .songs(let songs):
            if songs.isEmpty {
                message("No recent songs", detail: "Play a few songs in Apple Music, then come back and refresh.")
            }
            primaryButton("Refresh") {
                Task { await recentlyPlayed.reload() }
            }
            if !songs.isEmpty {
                songList(songs)
            }
        case .failed:
            message("Couldn’t load recent songs", detail: "Try again to load your recently played songs from Apple Music.")
            primaryButton("Try Again") {
                Task { await recentlyPlayed.reload() }
            }
        }
    }

    private func message(_ title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline.monospaced())
                .accessibilityAddTraits(.isHeader)
            Text(detail)
                .foregroundStyle(secondaryText)
        }
    }

    private func primaryButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(accent)
        .foregroundStyle(colorScheme == .dark ? .black : .white)
    }

    private func songList(_ songs: [RecentSong]) -> some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            // Positions preserve MusicKit's order even when a song appears more than once.
            ForEach(songs.indices, id: \.self) { index in
                let song = songs[index]
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.title)
                        .font(.body.weight(.semibold))
                    Text(song.artist)
                        .font(.subheadline)
                        .foregroundStyle(secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 14)
                .accessibilityElement(children: .combine)
                Divider()
            }
        }
    }
}
