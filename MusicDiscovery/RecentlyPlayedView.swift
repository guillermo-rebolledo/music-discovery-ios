import SwiftUI

struct RecentlyPlayedView: View {
    let recentlyPlayed: RecentlyPlayed
    let lastFM: LastFMDiscovery?

    let makeDiscovery: (DiscoverySelection) -> Discovery

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var choiceSeed: RecentSong?
    @State private var pendingDiscovery: DiscoverySelection?
    @State private var activeDiscovery: DiscoverySelection?
    @State private var consentSelection: DiscoverySelection?
    @State private var showsSettings = false

    private var palette: JournalPalette { JournalPalette(colorScheme: colorScheme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recently Played")
                        .font(.largeTitle.monospaced().weight(.bold))
                        .accessibilityAddTraits(.isHeader)

                    if lastFM != nil {
                        Button("Discovery Settings", systemImage: "gearshape") { showsSettings = true }
                            .tint(palette.accent)
                    }
                }

                Divider()

                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .accessibilityHidden(activeDiscovery != nil)
        .background(palette.background.ignoresSafeArea())
        .sheet(item: $choiceSeed, onDismiss: showPendingDiscovery) { seed in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SongCredit(title: seed.title, artist: seed.artist, secondaryText: palette.secondaryText)
                    Divider()
                    ForEach(DiscoveryMode.allCases, id: \.self) { mode in
                        JournalButton(LocalizedStringKey(mode.rawValue), monospaced: true) {
                            pendingDiscovery = DiscoverySelection(song: seed, mode: mode)
                            choiceSeed = nil
                        }
                    }
                    Button("Cancel") { choiceSeed = nil }
                        .tint(palette.accent)
                        .padding(.vertical, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .background(palette.background.ignoresSafeArea())
        }
        .fullScreenCover(item: $activeDiscovery) { selection in
            DiscoveryView(discovery: makeDiscovery(selection), lastFM: lastFM)
        }
        .sheet(isPresented: $showsSettings) {
            if let lastFM { DiscoverySettings(lastFM: lastFM) }
        }
        .alert("Share with Last.fm?", isPresented: Binding(
            get: { consentSelection != nil },
            set: { if !$0 { consentSelection = nil } }
        ), presenting: consentSelection) { selection in
            Button("Allow") {
                lastFM?.setAllowed(true)
                activeDiscovery = selection
            }
            Button("Not Now", role: .cancel) {}
        } message: { selection in
            if selection.mode == .songs {
                Text("Similar Songs shares “\(selection.song.title)” and artist “\(selection.song.artist)” with Last.fm. Similar Artists shares only the selected artist name. You can turn this off in Discovery Settings.")
            } else {
                Text("Similar Artists shares “\(selection.song.artist)” with Last.fm. Similar Songs shares the selected song title and artist name. You can turn this off in Discovery Settings.")
            }
        }
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
            JournalButton("Allow Apple Music Access") {
                Task { await recentlyPlayed.requestAccess() }
            }
        case .denied:
            message("Apple Music access is off", detail: "To see your recently played songs, allow access in Settings.")
            JournalButton("Open Settings", action: recentlyPlayed.openSettings)
        case .restricted:
            message("Apple Music access is restricted", detail: "This iPhone’s restrictions prevent access to Apple Music.")
        case .loading:
            ProgressView("Loading recently played songs…")
        case .songs(let songs):
            if songs.isEmpty {
                message("No recent songs", detail: "Play a few songs in Apple Music, then come back and refresh.")
            }
            JournalButton("Refresh") {
                Task { await recentlyPlayed.reload() }
            }
            if !songs.isEmpty {
                songList(songs)
            }
        case .failed:
            message("Couldn’t load recent songs", detail: "Try again to load your recently played songs from Apple Music.")
            JournalButton("Try Again") {
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
                .foregroundStyle(palette.secondaryText)
        }
    }

    private func showPendingDiscovery() {
        guard let selection = pendingDiscovery else { return }
        pendingDiscovery = nil
        if lastFM?.isAllowed == false {
            consentSelection = selection
        } else {
            activeDiscovery = selection
        }
    }

    private func songList(_ songs: [RecentSong]) -> some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            // Positions preserve MusicKit's order even when a song appears more than once.
            ForEach(songs.indices, id: \.self) { index in
                let song = songs[index]
                Button {
                    choiceSeed = song
                } label: {
                    SongCredit(title: song.title, artist: song.artist, secondaryText: palette.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(song.title), \(song.artist)")
                Divider()
            }
        }
    }
}

struct SongCredit: View {
    let title: String
    let artist: String
    let secondaryText: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.body.weight(.semibold))
            Text(artist)
                .font(.subheadline)
                .foregroundStyle(secondaryText)
        }
    }
}

struct JournalButton: View {
    let title: LocalizedStringKey
    var monospaced = false
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    init(_ title: LocalizedStringKey, monospaced: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.monospaced = monospaced
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(monospaced ? .body.monospaced().weight(.semibold) : .body.weight(.semibold))
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(JournalPalette(colorScheme: colorScheme).accent)
        .foregroundStyle(colorScheme == .dark ? .black : .white)
    }
}

struct JournalPalette {
    let colorScheme: ColorScheme

    var background: Color {
        colorScheme == .dark
            ? Color(red: 0.10, green: 0.10, blue: 0.11)
            : Color(red: 0.94, green: 0.94, blue: 0.93)
    }

    var accent: Color {
        colorScheme == .dark
            ? Color(red: 1, green: 0.47, blue: 0.34)
            : Color(red: 0.71, green: 0.19, blue: 0.09)
    }

    var secondaryText: Color {
        colorScheme == .dark ? Color(white: 0.72) : Color(white: 0.32)
    }
}
