import Foundation
import Observation

struct LastFMClient {
    private let apiKey: String
    private let transport: (URLRequest) async throws -> (Data, URLResponse)

    init(apiKey: String, transport: @escaping (URLRequest) async throws -> (Data, URLResponse)) {
        self.apiKey = apiKey
        self.transport = transport
    }

    func recommendations(for selection: DiscoverySelection) async throws -> [Recommendation] {
        let method = selection.mode == .songs ? "track.getSimilar" : "artist.getSimilar"
        var query = [
            URLQueryItem(name: "method", value: method),
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "limit", value: selection.mode == .songs ? "10" : "25"),
            URLQueryItem(name: "artist", value: selection.song.artist)
        ]
        if selection.mode == .songs {
            query.append(URLQueryItem(name: "track", value: selection.song.title))
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "ws.audioscrobbler.com"
        components.path = "/2.0/"
        components.queryItems = query
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        guard let url = components.url else { throw LookupError.failed }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("MusicDiscovery-iOS/1.0", forHTTPHeaderField: "User-Agent")

        try Task.checkCancellation()
        let (data, response) = try await transport(request)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode) else { throw LookupError.failed }

        let decoder = JSONDecoder()
        switch selection.mode {
        case .songs:
            let response = try decoder.decode(SimilarTracks.self, from: data)
            return response.similartracks.track.compactMap { track in
                guard !track.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      !track.artist.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                return .song(SongRecommendation(title: track.name, artist: track.artist.name, album: nil))
            }
        case .artists:
            let response = try decoder.decode(SimilarArtists.self, from: data)
            return response.similarartists.artist.compactMap { artist in
                guard let mbid = artist.mbid?.lowercased(),
                      let catalogID = Self.artistCatalogIDs[mbid] else { return nil }
                return .artist(ArtistRecommendation(name: artist.name, catalogID: catalogID))
            }
        }
    }

    private struct SimilarTracks: Decodable {
        struct Tracks: Decodable {
            struct Track: Decodable {
                let name: String
                let artist: ArtistCredit
            }

            let track: [Track]
        }

        let similartracks: Tracks
    }

    private struct SimilarArtists: Decodable {
        struct Artists: Decodable {
            let artist: [ArtistCredit]
        }

        let similarartists: Artists
    }

    private struct ArtistCredit: Decodable {
        let name: String
        let mbid: String?
    }

    // MusicBrainz artist URL relationships supply the Apple Music IDs for the personal test.
    private static let artistCatalogIDs = [
        "cb67438a-7f50-4f2b-a6f1-2bb2729fd538": "5641488",     // Air
        "6a93afbb-257f-4166-b389-9f2a1e5c5df8": "566867492",   // CHVRCHES
        "a0b2868c-22c7-49eb-b227-3c4251a6c88f": "313962807",   // Electric Youth
        "860b2707-6153-4e3a-aa57-74d2b42c55b5": "145072812",   // Justice
        "eb6de5f6-98f8-4b5a-bfdc-f87fa4936baa": "115429828",   // Kavinsky
        "6d7b7cd4-254b-4c25-83f6-dd20f98ceacd": "46086389",    // M83
        "dfe78af2-779e-4137-826a-3073a16e3278": "313208491",   // Phantogram
        "7b75e88a-f211-4886-8c3d-dd9d7171eee5": "1463775970"   // Stardust
    ]

    private enum LookupError: Error {
        case failed
    }
}

@Observable
final class LastFMDiscovery {
    private static let consentKey = "allowsLastFMDiscovery"
    private let client: LastFMClient
    private let defaults: UserDefaults?
    private(set) var isAllowed: Bool
    #if DEBUG
    var fixture: LastFMFixture?
    #endif

    init(client: LastFMClient, defaults: UserDefaults?) {
        self.client = client
        self.defaults = defaults
        isAllowed = defaults?.bool(forKey: Self.consentKey) ?? false
    }

    func setAllowed(_ allowed: Bool) {
        isAllowed = allowed
        defaults?.set(allowed, forKey: Self.consentKey)
    }

    func recommendations(for selection: DiscoverySelection) async throws -> [Recommendation] {
        guard isAllowed else { throw CancellationError() }
        return try await client.recommendations(for: selection)
    }
}

#if DEBUG
@Observable
final class LastFMFixture {
    private let scenario: String
    private(set) var requestCount = 0
    private(set) var responseCount = 0
    private var pendingResponse: CheckedContinuation<Void, Never>?

    var hasPendingResponse: Bool { pendingResponse != nil }

    init(scenario: String) {
        self.scenario = scenario
    }

    func deliverPendingResponse() {
        let response = pendingResponse
        pendingResponse = nil
        response?.resume()
    }

    func respond(to request: URLRequest) async throws -> (Data, URLResponse) {
        requestCount += 1
        let number = requestCount
        defer { responseCount += 1 }
        guard let url = request.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "https",
              components.host == "ws.audioscrobbler.com",
              components.path == "/2.0/",
              let query = components.queryItems else { throw FixtureError.unexpectedRequest }

        let method = query.first { $0.name == "method" }?.value
        let common: Set<URLQueryItem> = [
            URLQueryItem(name: "api_key", value: "test-key"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "artist", value: "M83")
        ]
        let payload: String
        switch method {
        case "track.getSimilar":
            let expected = common.union([
                URLQueryItem(name: "method", value: "track.getSimilar"),
                URLQueryItem(name: "limit", value: "10"),
                URLQueryItem(name: "track", value: "Midnight City")
            ])
            guard query.count == expected.count, Set(query) == expected else { throw FixtureError.unexpectedRequest }
            payload = """
                {"similartracks":{"track":[
                    {"name":"Genesis","artist":{"name":"Justice"}},
                    {"name":"A Real Hero","artist":{"name":"College"}}
                ]}}
                """
        case "artist.getSimilar":
            let expected = common.union([
                URLQueryItem(name: "method", value: "artist.getSimilar"),
                URLQueryItem(name: "limit", value: "25")
            ])
            guard query.count == expected.count, Set(query) == expected else { throw FixtureError.unexpectedRequest }
            payload = """
                {"similarartists":{"artist":[
                    {"name":"Kavinsky","mbid":"eb6de5f6-98f8-4b5a-bfdc-f87fa4936baa"},
                    {"name":"Same Name","mbid":"50000000-0000-4000-8000-000000000001"},
                    {"name":"Purity Ring","mbid":""}
                ]}}
                """
        default:
            throw FixtureError.unexpectedRequest
        }

        if scenario == "late" {
            guard pendingResponse == nil else { throw FixtureError.unexpectedRequest }
            // Let this response arrive even if the view has cancelled its task.
            await withCheckedContinuation { pendingResponse = $0 }
        }
        if scenario == "retry" && number == 1 {
            throw URLError(.timedOut)
        }
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (Data(payload.utf8), response)
    }

    private enum FixtureError: Error {
        case unexpectedRequest
    }
}
#endif
