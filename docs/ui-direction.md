# V1 UI direction

A text-led listening journal for iPhone. Recently Played is easy to scan, and each results screen makes clear which song or artist started the discovery. Teenage Engineering is the visual reference for the gray, black, and red-orange palette, monospaced headings, and restrained hardware cues. [V1 build spec](https://github.com/guillermo-rebolledo/music-discovery-ios/issues/1)

## Visual language

- Follow the iPhone’s appearance setting. Use light gray surfaces and near-black text in light mode, and graphite surfaces with light text in dark mode. Use red-orange for primary actions and selected controls in both appearances.
- Use monospace for screen headings and Discovery Mode labels. Use proportional type for song titles, artist names, and explanatory copy. Give rows enough room for a long title and a secondary artist line.
- Use thin dividers, consistent alignment, and generous spacing. Give the accent a clear job so the active mode and primary action stand out.
- Design complete layouts with text alone. Treat artwork as an optional enhancement once its use is confirmed for the Apple Music handoff.

## Screen flow

### Recently Played

Open on Recently Played. Show songs in the order Apple Music returns them, with title first and credited artist second. Tapping a row opens the choice sheet. Support refresh and keep the list available when the listener declines Last.fm consent.

Before the first Apple Music permission request, explain why the app needs access. If access is denied, explain how to enable it in Settings when available. With an empty list, guide the listener to play music in Apple Music and offer refresh. Give load failures a retry action.

### Discovery choice sheet

Show the selected song and credited artist above two actions, **Similar Songs** and **Similar Artists**. The listener chooses a mode before the lookup starts. Dismissing the sheet returns to Recently Played.

### Results

Open a full screen with the active Discovery Seed visible. Use a compact two-option control for **Similar Songs** and **Similar Artists**. Switching modes keeps the same recent song in context and makes the active mode clear while its results load. Similar Songs uses the song as the seed. Similar Artists uses its artist.

Show only Recommendations with a confident Catalog Match. Label the list **Opens in Apple Music** once. Make each row tappable and give it a trailing outward arrow. A song row shows its title and artist. An artist row shows the artist name. VoiceOver identifies the destination, for example, “Open [song name] in Apple Music.”

Keep the seed and mode visible during loading, when there are no matches, and when a lookup fails. For no matches, offer a way back to Recently Played to choose another song. For a failed lookup or handoff, give the listener a way to retry the action that failed.

## Last.fm consent

Ask at the first live lookup. Explain that Last.fm receives the selected artist name for Similar Artists, or the artist name and song title for Similar Songs. Offer **Allow** and **Not Now** before any live request. Provide a way to withdraw consent in Settings. The personal prototype uses sample Recommendations, so this prompt begins with the live milestone. [Recently Played data-sharing decision](adr/0001-keep-recently-played-on-device.md)

## Accessibility

Support Dynamic Type and VoiceOver across the list, sheet, mode control, and results. Identify the selected mode through text and accessibility state as well as color. Keep both mode labels usable at larger text sizes, and check text, dividers, and controls in both appearances.
