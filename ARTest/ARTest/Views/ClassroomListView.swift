//
//  ClassroomListView.swift
//  ARTest
//
//  Created by Alen Kaucic on 16. 01. 26.
//

import SwiftUI

struct ClassroomListView: View {
    @State var classrooms: [Classroom]
    @State var mapId: UUID
    @State private var showingAddClassroom = false
    @State private var selectedClassroom: Classroom?
    @State private var showingEditSheet = false
    @State private var editingClassroom: Classroom?
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            ZStack {
                if classrooms.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "building.2")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No Classrooms Yet")
                            .font(.headline)
                        Text("Tap the + button to add your first classroom")
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    List {
                        ForEach(classrooms) { classroom in
                            ClassroomRowView(classroom: classroom)
                                .onTapGesture {
                                    selectedClassroom = classroom
                                    editingClassroom = classroom
                                    showingEditSheet = true
                                }
                        }
                        .onDelete(perform: deleteClassroom)
                    }
                }
            }
            .navigationTitle("Classrooms")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddClassroom = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddClassroom) {
                AddClassroomView(
                    mapId: mapId,
                    onClassroomAdded: { newClassroom in
                        classrooms.append(newClassroom)
                        showingAddClassroom = false
                    }
                )
            }
            .sheet(isPresented: $showingEditSheet) {
                if let classroom = editingClassroom {
                    EditClassroomView(
                        classroom: classroom,
                        mapId: mapId,
                        onClassroomUpdated: { updated in
                            if let index = classrooms.firstIndex(where: { $0.id == updated.id }) {
                                classrooms[index] = updated
                            }
                            showingEditSheet = false
                        }
                    )
                }
            }
            .alert("Error", isPresented: $showError, presenting: errorMessage) { _ in
                Button("OK") { }
            } message: { msg in
                Text(msg)
            }
        }
    }
    
    private func deleteClassroom(at offsets: IndexSet) {
        let toDelete = offsets.map { classrooms[$0] }
        
        for classroom in toDelete {
            do {
                try MapStorageManager.shared.removeClassroom(classroom.id, from: mapId)
                classrooms.removeAll { $0.id == classroom.id }
            } catch {
                errorMessage = "Failed to delete classroom: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}

struct ClassroomRowView: View {
    let classroom: Classroom
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(classroom.name)
                        .font(.headline)
                    
                    if !classroom.professor.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "person.fill")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(classroom.professor)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            
            if !classroom.description.isEmpty {
                Text(classroom.description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
            
            HStack(spacing: 12) {
                Label(String(format: "X: %.2f", classroom.position.x), systemImage: "cube.fill")
                    .font(.caption2)
                    .foregroundColor(.blue)
                Label(String(format: "Y: %.2f", classroom.position.y), systemImage: "cube.fill")
                    .font(.caption2)
                    .foregroundColor(.blue)
                Label(String(format: "Z: %.2f", classroom.position.z), systemImage: "cube.fill")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ClassroomListView(
        classrooms: [
            Classroom(
                name: "Room 101",
                professor: "Prof. Smith",
                description: "Mathematics classroom",
                position: ClassroomPosition(x: 1, y: 0, z: -2)
            )
        ],
        mapId: UUID()
    )
}
