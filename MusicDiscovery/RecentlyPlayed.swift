import Foundation
import MusicKit
import Observation

@Observable
final class RecentlyPlayed {
    enum State {
        case checkingAccess
        case requestingAccess
        case needsPermission
        case denied
        case restricted
        case loading(UUID)
        case songs([RecentSong])
        case failed
    }

    private(set) var state = State.checkingAccess
    private let appleMusic: any AppleMusic

    init(appleMusic: any AppleMusic) {
        self.appleMusic = appleMusic
    }

    func recheckAccess() async {
        if case .requestingAccess = state { return }
        guard applyAuthorization(appleMusic.authorization) else { return }

        switch state {
        case .checkingAccess, .needsPermission, .denied, .restricted:
            await reload()
        case .requestingAccess, .loading, .songs, .failed:
            break
        }
    }

    func requestAccess() async {
        guard case .needsPermission = state else { return }
        state = .requestingAccess
        if applyAuthorization(await appleMusic.requestAuthorization()) {
            await reload()
        }
    }

    func reload() async {
        guard applyAuthorization(appleMusic.authorization) else { return }
        if case .loading = state { return }
        let load = UUID()
        state = .loading(load)

        let result: State
        do {
            result = .songs(try await appleMusic.recentlyPlayed())
        } catch {
            result = .failed
        }

        // A foreground access check may have invalidated this request while it was running.
        guard case .loading(let activeLoad) = state, activeLoad == load,
              applyAuthorization(appleMusic.authorization) else { return }
        state = result
    }

    func openSettings() {
        appleMusic.openSettings()
    }

    private func applyAuthorization(_ status: MusicAuthorization.Status) -> Bool {
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            state = .needsPermission
        case .denied:
            state = .denied
        case .restricted:
            state = .restricted
        @unknown default:
            state = .restricted
        }
        return false
    }
}
