//
//  Extensions.swift
//  ARTest
//
//  Created by Alen Kaucic on 16. 01. 26.
//

import Foundation
import ARKit

extension WorldMapData {
    /// Load the archived world map data
    func getWorldMap() throws -> ARWorldMap {
        let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: mapData)
        guard let worldMap = worldMap else {
            throw MapStorageError.invalidData
        }
        return worldMap
    }
}
