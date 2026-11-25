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

## Run the tests

Select an iPhone simulator in Xcode and run Product → Test. The UI tests launch the app with controlled Apple Music responses, so they run without an Apple Music account.
