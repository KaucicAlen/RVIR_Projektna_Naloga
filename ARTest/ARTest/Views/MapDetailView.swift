//
//  MapDetailView.swift
//  ARTest
//
//  Created by Alen Kaucic on 16. 01. 26.
//

import SwiftUI

struct MapDetailView: View {
    @Environment(\.dismiss) var dismiss
    @State var mapData: WorldMapData
    @State private var showingARViewer = false
    @State private var showingClassroomList = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var confirmDelete = false
    
    var onMapDeleted: (() -> Void)?
    var onClose: (() -> Void)?
    
    var body: some View {
        if showingARViewer {
            ZStack {
                ARViewContainer(mode: .viewing, worldMapData: mapData)
                    .ignoresSafeArea()
                
                VStack {
                    HStack {
                        Button(action: { showingARViewer = false }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                        }
                        Spacer()
                    }
                    .padding()
                    
                    Spacer()
                }
            }
        } else {
            VStack(spacing: 0) {
                HStack {
                    Button(action: { onClose?() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Close")
                        }
                        .foregroundColor(.blue)
                    }
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(mapData.name)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Created")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text(mapData.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.subheadline)
                                }
                                
                                Divider()
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Classrooms")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text("\(mapData.classrooms.count)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        
                        VStack(spacing: 12) {
                            Button(action: { showingARViewer = true }) {
                                HStack {
                                    Image(systemName: "arkit")
                                    Text("View in AR")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            
                            Button(action: { showingClassroomList = true }) {
                                HStack {
                                    Image(systemName: "building.2")
                                    Text("Manage Classrooms")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            
                            Button(action: { confirmDelete = true }) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Delete Map")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                        }
                        .padding()
                    }
                }
                
                Spacer()
            }
            .background(Color(.systemBackground))
            .sheet(isPresented: $showingClassroomList) {
                ClassroomListView(classrooms: mapData.classrooms, mapId: mapData.id)
                    .onDisappear {
                        do {
                            mapData = try MapStorageManager.shared.loadWorldMapData(with: mapData.id)
                        } catch {
                            print("Error reloading map data: \(error)")
                        }
                    }
            }
            .alert("Delete Map", isPresented: $confirmDelete) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteMap()
                }
            } message: {
                Text("Are you sure you want to delete this map and all its classrooms? This cannot be undone.")
            }
            .alert("Error", isPresented: $showError, presenting: errorMessage) { _ in
                Button("OK") { }
            } message: { msg in
                Text(msg)
            }
        }
    }
    
    private func deleteMap() {
        do {
            try MapStorageManager.shared.deleteWorldMap(with: mapData.id)
            onMapDeleted?()
            dismiss()
        } catch {
            errorMessage = "Failed to delete map: \(error.localizedDescription)"
            showError = true
        }
    }
}

#Preview {
    MapDetailView(mapData: WorldMapData(
        name: "Main Building",
        mapData: Data()
    ))
}
