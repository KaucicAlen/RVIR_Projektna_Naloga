//
//  Classroom.swift
//  ARTest
//
//  Created by Alen Kaucic on 16. 01. 26.
//

import Foundation
import ARKit

struct Classroom: Identifiable, Codable {
    let id: UUID
    var name: String
    var professor: String
    var description: String
    var position: ClassroomPosition
    let createdAt: Date
    
    init(id: UUID = UUID(), name: String, professor: String = "", description: String = "", position: ClassroomPosition, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.professor = professor
        self.description = description
        self.position = position
        self.createdAt = createdAt
    }
}

struct ClassroomPosition: Codable {
    var x: Float
    var y: Float
    var z: Float
    
    init(x: Float = 0, y: Float = 0, z: Float = 0) {
        self.x = x
        self.y = y
        self.z = z
    }
    
    // Convert to SIMD3
    func toSIMD3() -> SIMD3<Float> {
        return SIMD3<Float>(x, y, z)
    }
    
    // Create from SIMD3
    static func from(_ simd: SIMD3<Float>) -> ClassroomPosition {
        return ClassroomPosition(x: simd.x, y: simd.y, z: simd.z)
    }
}

struct WorldMapData: Identifiable, Codable {
    let id: UUID
    let name: String
    let createdAt: Date
    let mapData: Data
    var classrooms: [Classroom]
    
    init(id: UUID = UUID(), name: String, createdAt: Date = Date(), mapData: Data, classrooms: [Classroom] = []) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.mapData = mapData
        self.classrooms = classrooms
    }
}
