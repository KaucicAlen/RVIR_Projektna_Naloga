//
//  CoordinateSystemManager.swift
//  ARTest
//
//  Created by Alen Kaucic on 16. 01. 26.
//

import ARKit
import RealityKit
import Foundation

class CoordinateSystemManager {
    static let shared = CoordinateSystemManager()
    
    private init() {}

    func getOriginAnchor(from worldMap: ARWorldMap) -> AnchorEntity? {
        
        return nil
    }
    
    func getLocalCoordinates(worldPosition: SIMD3<Float>, relativeTo mapOrigin: SIMD3<Float>) -> ClassroomPosition {
        let local = worldPosition - mapOrigin
        return ClassroomPosition(x: local.x, y: local.y, z: local.z)
    }
    
    func getWorldPosition(localCoordinates: ClassroomPosition, relativeTo mapOrigin: SIMD3<Float>) -> SIMD3<Float> {
        let local = localCoordinates.toSIMD3()
        return local + mapOrigin
    }
    
    func distance(from: ClassroomPosition, to: ClassroomPosition) -> Float {
        let fromSIMD = from.toSIMD3()
        let toSIMD = to.toSIMD3()
        return distance(fromSIMD, toSIMD)
    }
    
    private func distance(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        let diff = a - b
        return sqrt(diff.x * diff.x + diff.y * diff.y + diff.z * diff.z)
    }
}

extension ARCamera {
    var worldPosition: SIMD3<Float> {
        return SIMD3<Float>(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )
    }
}
