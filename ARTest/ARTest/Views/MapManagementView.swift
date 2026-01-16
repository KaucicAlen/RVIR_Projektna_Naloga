//
//  MapManagementView.swift
//  ARTest
//
//  Created by Alen Kaucic on 16. 01. 26.
//

import SwiftUI
import ARKit

struct MapManagementView: View {
    @State private var savedMaps: [WorldMapData] = []
    @State private var showingNewMapOptions = false
    @State private var showingARScanning = false
    @State private var selectedMap: WorldMapData?
    @State private var showingMapDetail = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ZStack {
                if savedMaps.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "map")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No Maps Yet")
                            .font(.headline)
                        Text("Create a new building map by scanning with AR")
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        
                        Button(action: { showingNewMapOptions = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Create New Map")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                    }
                } else {
                    List {
                        ForEach(savedMaps) { mapData in
                            MapRowView(mapData: mapData)
                                .onTapGesture {
                                    selectedMap = mapData
                                    showingMapDetail = true
                                }
                        }
                        .onDelete(perform: deleteMap)
                    }
                }
            }
            .navigationTitle("Building Maps")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewMapOptions = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingARScanning) {
                ARViewContainer(
                    mode: .scanning,
                    onMapSaved: { worldMap in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.loadSavedMaps()
                        }
                    }
                )
            }
            .sheet(isPresented: $showingMapDetail) {
                if let map = selectedMap {
                    MapDetailView(
                        mapData: map,
                        onMapDeleted: {
                            if let index = savedMaps.firstIndex(where: { $0.id == map.id }) {
                                savedMaps.remove(at: index)
                            }
                            showingMapDetail = false
                        },
                        onClose: {
                            showingMapDetail = false
                        }
                    )
                }
            }
            .actionSheet(isPresented: $showingNewMapOptions) {
                ActionSheet(
                    title: Text("Create New Map"),
                    message: Text("How would you like to create a new building map?"),
                    buttons: [
                        .default(Text("Scan with AR")) {
                            showingARScanning = true
                        },
                        .cancel()
                    ]
                )
            }
            .alert("Error", isPresented: $showError, presenting: errorMessage) { _ in
                Button("OK") { }
            } message: { msg in
                Text(msg)
            }
            .onAppear {
                loadSavedMaps()
            }
        }
    }
    
    private func loadSavedMaps() {
        do {
            savedMaps = try MapStorageManager.shared.getAllSavedMaps()
        } catch {
            errorMessage = "Failed to load maps: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func deleteMap(at offsets: IndexSet) {
        let toDelete = offsets.map { savedMaps[$0] }
        
        for mapData in toDelete {
            do {
                try MapStorageManager.shared.deleteWorldMap(with: mapData.id)
                savedMaps.removeAll { $0.id == mapData.id }
            } catch {
                errorMessage = "Failed to delete map: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}

struct MapRowView: View {
    let mapData: WorldMapData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mapData.name)
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        Label("\(mapData.classrooms.count) classrooms", systemImage: "building.2")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Label(mapData.createdAt.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MapManagementView()
}
