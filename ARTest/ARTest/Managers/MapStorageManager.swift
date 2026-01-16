//
//  MapStorageManager.swift
//  ARTest
//
//  Created by Alen Kaucic on 16. 01. 26.
//

import Foundation
import ARKit

class MapStorageManager {
    static let shared = MapStorageManager()
    
    private let fileManager = FileManager.default
    private var mapsDirectory: URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        let mapsDir = documentsDirectory.appendingPathComponent("ARMaps", isDirectory: true)
        
        if !fileManager.fileExists(atPath: mapsDir.path) {
            try? fileManager.createDirectory(at: mapsDir, withIntermediateDirectories: true, attributes: nil)
        }
        return mapsDir
    }
    
    private init() {}
    
    // MARK: - Save World Map
    func saveWorldMap(_ worldMap: ARWorldMap, with name: String) throws -> WorldMapData {
        let id = UUID()
        let mapData = try NSKeyedArchiver.archivedData(withRootObject: worldMap, requiringSecureCoding: true)
        
        let worldMapData = WorldMapData(
            id: id,
            name: name,
            createdAt: Date(),
            mapData: mapData,
            classrooms: []
        )
        
        try saveWorldMapData(worldMapData)
        return worldMapData
    }
    
    // MARK: - Load World Map
    func loadWorldMap(with id: UUID) throws -> ARWorldMap {
        let worldMapData = try loadWorldMapData(with: id)
        let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: worldMapData.mapData)
        guard let worldMap = worldMap else {
            throw MapStorageError.invalidData
        }
        return worldMap
    }
    
    // MARK: - Save World Map Data (with metadata)
    private func saveWorldMapData(_ data: WorldMapData) throws {
        let fileURL = mapsDirectory.appendingPathComponent("\(data.id.uuidString).armap")
        let encoded = try JSONEncoder().encode(data)
        try encoded.write(to: fileURL)
    }
    
    // MARK: - Load World Map Data (with metadata)
    func loadWorldMapData(with id: UUID) throws -> WorldMapData {
        let fileURL = mapsDirectory.appendingPathComponent("\(id.uuidString).armap")
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(WorldMapData.self, from: data)
    }
    
    // MARK: - Get All Saved Maps
    func getAllSavedMaps() throws -> [WorldMapData] {
        let fileURLs = try fileManager.contentsOfDirectory(at: mapsDirectory, includingPropertiesForKeys: nil)
        let armapFiles = fileURLs.filter { $0.pathExtension == "armap" }
        
        var maps: [WorldMapData] = []
        for fileURL in armapFiles {
            do {
                let data = try Data(contentsOf: fileURL)
                let mapData = try JSONDecoder().decode(WorldMapData.self, from: data)
                maps.append(mapData)
            } catch {
                print("Error loading map from \(fileURL): \(error)")
            }
        }
        
        return maps.sorted { $0.createdAt > $1.createdAt }
    }
    
    // MARK: - Update World Map Data
    func updateWorldMapData(_ data: WorldMapData) throws {
        try saveWorldMapData(data)
    }
    
    // MARK: - Delete World Map
    func deleteWorldMap(with id: UUID) throws {
        let fileURL = mapsDirectory.appendingPathComponent("\(id.uuidString).armap")
        try fileManager.removeItem(at: fileURL)
    }
    
    // MARK: - Add Classroom to Map
    func addClassroom(_ classroom: Classroom, to mapId: UUID) throws {
        var mapData = try loadWorldMapData(with: mapId)
        mapData.classrooms.append(classroom)
        try saveWorldMapData(mapData)
    }
    
    // MARK: - Remove Classroom from Map
    func removeClassroom(_ classroomId: UUID, from mapId: UUID) throws {
        var mapData = try loadWorldMapData(with: mapId)
        mapData.classrooms.removeAll { $0.id == classroomId }
        try saveWorldMapData(mapData)
    }
    
    // MARK: - Update Classroom
    func updateClassroom(_ classroom: Classroom, in mapId: UUID) throws {
        var mapData = try loadWorldMapData(with: mapId)
        if let index = mapData.classrooms.firstIndex(where: { $0.id == classroom.id }) {
            mapData.classrooms[index] = classroom
            try saveWorldMapData(mapData)
        }
    }
}

enum MapStorageError: LocalizedError {
    case invalidData
    case fileNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Failed to decode the AR world map data."
        case .fileNotFound:
            return "The requested map file was not found."
        }
    }
}
