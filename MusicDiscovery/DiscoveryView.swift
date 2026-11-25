import SwiftUI

struct DiscoveryView: View {
    @State var discovery: Discovery

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var opening = false
    @State private var failedHandoff: CatalogMatch?

    private var palette: JournalPalette { JournalPalette(colorScheme: colorScheme) }

    var body: some View {
        let attempt = discovery.attempt
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Button {
                    dismiss()
                } label: {
                    Label("Recently Played", systemImage: "chevron.left")
                        .padding(.vertical, 8)
                }
                .tint(palette.accent)

                VStack(alignment: .leading, spacing: 12) {
                    modeControl
                    if discovery.mode == .songs {
                        SongCredit(title: discovery.song.title, artist: discovery.song.artist, secondaryText: palette.secondaryText)
                            .accessibilityAddTraits(.isHeader)
                    } else {
                        Text(discovery.song.artist)
                            .font(.title2.weight(.semibold))
                            .accessibilityAddTraits(.isHeader)
                    }
                }
                Divider()

                switch discovery.phase {
                case .loading:
                    ProgressView("Loading \(discovery.mode.rawValue.lowercased())…")
                case .failed:
                    Text("Couldn’t finish loading \(discovery.mode.rawValue.lowercased())")
                        .font(.headline.monospaced())
                    JournalButton("Retry Lookup", action: discovery.retry)
                case .finished where discovery.matches.isEmpty:
                    Text("No matches")
                        .font(.headline.monospaced())
                    JournalButton("Choose Another Song") { dismiss() }
                case .finished:
                    EmptyView()
                }

                if !discovery.matches.isEmpty {
                    results
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .accessibilityIdentifier("discoveryResults")
        .background(palette.background.ignoresSafeArea())
        .task(id: attempt) { await discovery.load(attempt: attempt) }
        .alert("Couldn’t open Apple Music", isPresented: Binding(
            get: { failedHandoff != nil },
            set: { if !$0 { failedHandoff = nil } }
        ), presenting: failedHandoff) { match in
            Button("Retry") { open(match) }
            Button("Cancel", role: .cancel) {}
        } message: { match in
            Text("Try opening \(match.title) again.")
        }
    }

    private var modeControl: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))

        return layout {
            ForEach(DiscoveryMode.allCases, id: \.self) { mode in
                let selected = discovery.mode == mode
                Button {
                    discovery.select(mode)
                    failedHandoff = nil
                } label: {
                    HStack(spacing: 4) {
                        if selected {
                            Image(systemName: "checkmark")
                                .accessibilityHidden(true)
                        }
                        Text(mode.rawValue)
                    }
                    .font(.subheadline.monospaced().weight(selected ? .bold : .medium))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.horizontal, 6)
                    .background(selected ? palette.accent : .clear, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8).strokeBorder(palette.secondaryText)
                    }
                    .foregroundStyle(selected ? (colorScheme == .dark ? .black : .white) : .primary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(mode.rawValue)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Opens in Apple Music")
                .font(.headline.monospaced())
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, 12)
            Divider()

            ForEach(discovery.matches) { match in
                Button {
                    open(match)
                } label: {
                    HStack(spacing: 16) {
                        if let artist = match.artist {
                            SongCredit(title: match.title, artist: artist, secondaryText: palette.secondaryText)
                        } else {
                            Text(match.title).font(.body.weight(.semibold))
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right")
                            .foregroundStyle(palette.accent)
                            .accessibilityHidden(true)
                    }
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open \(match.artist.map { "\(match.title), \($0)" } ?? match.title) in Apple Music")
                .disabled(opening)
                Divider()
            }
        }
    }

    private func open(_ match: CatalogMatch) {
        guard !opening else { return }
        opening = true
        Task {
            let opened = await discovery.open(match)
            opening = false
            if !opened && discovery.matches.contains(where: { $0.url == match.url }) {
                failedHandoff = match
            }
        }
    }
}
