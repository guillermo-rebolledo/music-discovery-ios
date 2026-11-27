# Music Discovery

A SwiftUI iPhone app that shows Recently Played from Apple Music. The list stays in memory on the iPhone.

## Run on an iPhone

1. In Apple Developer Certificates, Identifiers & Profiles, register an explicit App ID and enable MusicKit under App Services. MusicKit generates the developer token automatically for the registered bundle identifier. [Apple MusicKit setup](https://developer.apple.com/documentation/musickit/using-automatic-token-generation-for-apple-music-api)
2. Create `Config/Signing.local.xcconfig` using the values from your developer team and App ID. Git ignores this file.

   ```xcconfig
   DEVELOPMENT_TEAM = YOUR_TEAM_ID
   PRODUCT_BUNDLE_IDENTIFIER = your.registered.bundle.identifier
   ```

3. Open `MusicDiscovery.xcodeproj` in Xcode 26 or later, select the MusicDiscovery scheme and an iPhone running iOS 17 or later, then Run. Xcode uses automatic signing.

## Test live Last.fm discovery on an iPhone

1. Confirm the permitted test scope and any provider conditions in [issue #7](https://github.com/guillermo-rebolledo/music-discovery-ios/issues/7).
2. In Xcode, duplicate the MusicDiscovery scheme and leave **Shared** unchecked. In the local scheme’s **Run → Arguments → Environment Variables**, set `LAST_FM_API_KEY` to your Last.fm API key. Run the Debug build from Xcode on your iPhone. Builds launched without the local key use sample Recommendations.
3. Select a real song from Recently Played. Choose a Discovery Mode and review the names in the consent prompt before tapping **Allow**. Open one verified result from each mode and confirm it is the intended Apple Music listing.
4. In **Discovery Settings**, tap **Turn Off Last.fm**. Choose another Discovery Mode and tap **Not Now** to return to Recently Played.

For the personal test, try an M83 or Daft Punk seed. Similar Artists verifies Last.fm’s returned MusicBrainz IDs against a small on-device mapping to Apple Music IDs. The mapping comes from MusicBrainz artist URL relationships, such as [Kavinsky’s relationships](https://musicbrainz.org/artist/eb6de5f6-98f8-4b5a-bfdc-f87fa4936baa/relationships). Artists without a mapped identity are omitted.

## Run the tests

Select an iPhone simulator in Xcode and run Product → Test. The UI tests use controlled Apple Music and Last.fm responses and run without service accounts or credentials.
