//
//  CoasterDataManagerImpl+Network.swift
//  Copyright © 2025 Jason Fieldman.
//

import CoasterDataManager
import CombineEx
import Foundation

struct WireParkOwner: Decodable, Sendable {
    let name: String
    let parks: [WirePark]
}

struct WirePark: Decodable, Sendable {
    let id: Int
    let name: String
    let latitude: String
    let longitude: String
}

struct WireParkDetailResponse: Decodable, Sendable {
    let lands: [WireLand]
    let rides: [WireRide]
}

struct WireLand: Decodable, Sendable {
    let name: String
    let rides: [WireRide]
}

struct WireRide: Decodable, Sendable {
    let id: Int
    let name: String
    let is_open: Bool
    let wait_time: Int
    let last_updated: String
}

extension CoasterDataManagerImpl {
    func fetchRemoteParks() -> AnyDeferredFuture<[WireParkOwner], CoasterDataError> {
        DeferredFuture { promise in
            DispatchQueue.global().asyncUnsafe {
                do {
                    let jsonData = try Data(contentsOf: URL(string: "https://queue-times.com/parks.json")!)
                    let parks = try JSONDecoder().decode([WireParkOwner].self, from: jsonData)
                    promise(.success(parks))
                } catch {
                    promise(.failure(.networkError(error)))
                }
            }
        }.eraseToAnyDeferredFuture()
    }

    func fetchRemoteRides(park: Int) -> AnyDeferredFuture<WireParkDetailResponse, CoasterDataError> {
        DeferredFuture { promise in
            DispatchQueue.global().asyncUnsafe {
                do {
                    let jsonData = try Data(contentsOf: URL(string: "https://queue-times.com/parks/\(park)/queue_times.json")!)
                    let details = try JSONDecoder().decode(WireParkDetailResponse.self, from: jsonData)
                    promise(.success(details))
                } catch {
                    promise(.failure(.networkError(error)))
                }
            }
        }.eraseToAnyDeferredFuture()
    }
}
