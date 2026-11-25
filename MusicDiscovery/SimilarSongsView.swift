import SwiftUI

struct SimilarSongsView: View {
    @State var discovery: SimilarSongs

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var opening = false
    @State private var failedHandoff: CatalogMatch?

    private var palette: JournalPalette { JournalPalette(colorScheme: colorScheme) }

    var body: some View {
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
                    Text("Similar Songs")
                        .font(.largeTitle.monospaced().weight(.bold))
                        .accessibilityAddTraits([.isHeader, .isSelected])
                    SongCredit(title: discovery.seed.title, artist: discovery.seed.artist, secondaryText: palette.secondaryText)
                }
                Divider()

                switch discovery.phase {
                case .loading:
                    ProgressView("Loading similar songs…")
                case .failed:
                    Text("Couldn’t finish loading similar songs")
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
        .background(palette.background.ignoresSafeArea())
        .task(id: discovery.attempt) { await discovery.load() }
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
                        SongCredit(title: match.title, artist: match.artist, secondaryText: palette.secondaryText)
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right")
                            .foregroundStyle(palette.accent)
                            .accessibilityHidden(true)
                    }
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open \(match.title), \(match.artist) in Apple Music")
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
            if !opened { failedHandoff = match }
        }
    }
}
