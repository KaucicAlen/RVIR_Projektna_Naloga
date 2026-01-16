//
//  EditClassroomView.swift
//  ARTest
//
//  Created by Alen Kaucic on 16. 01. 26.
//

import SwiftUI

struct EditClassroomView: View {
    @Environment(\.dismiss) var dismiss
    @State private var classroomName: String
    @State private var professor: String
    @State private var description: String
    @State private var positionX: String
    @State private var positionY: String
    @State private var positionZ: String
    @State private var errorMessage: String?
    @State private var showError = false
    
    let classroom: Classroom
    let mapId: UUID
    var onClassroomUpdated: (Classroom) -> Void
    
    init(classroom: Classroom, mapId: UUID, onClassroomUpdated: @escaping (Classroom) -> Void) {
        self.classroom = classroom
        self.mapId = mapId
        self.onClassroomUpdated = onClassroomUpdated
        
        _classroomName = State(initialValue: classroom.name)
        _professor = State(initialValue: classroom.professor)
        _description = State(initialValue: classroom.description)
        _positionX = State(initialValue: String(classroom.position.x))
        _positionY = State(initialValue: String(classroom.position.y))
        _positionZ = State(initialValue: String(classroom.position.z))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Classroom Information")) {
                    TextField("Classroom Name", text: $classroomName)
                        .textContentType(.none)
                    TextField("Professor Name (optional)", text: $professor)
                        .textContentType(.none)
                    TextField("Description (optional)", text: $description)
                        .textContentType(.none)
                }
                
                Section(header: Text("Position")) {
                    HStack {
                        Text("X:")
                            .frame(width: 30)
                        TextField("0", text: $positionX)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Text("Y:")
                            .frame(width: 30)
                        TextField("0", text: $positionY)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Text("Z:")
                            .frame(width: 30)
                        TextField("0", text: $positionZ)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                
                Section {
                    Button(action: updateClassroom) {
                        HStack {
                            Spacer()
                            Text("Update Classroom")
                                .foregroundColor(.white)
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.blue)
                }
            }
            .navigationTitle("Edit Classroom")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError, presenting: errorMessage) { _ in
                Button("OK") { }
            } message: { msg in
                Text(msg)
            }
        }
    }
    
    private func updateClassroom() {
        guard !classroomName.isEmpty else {
            errorMessage = "Please enter a classroom name"
            showError = true
            return
        }
        
        guard let x = Float(positionX),
              let y = Float(positionY),
              let z = Float(positionZ) else {
            errorMessage = "Please enter valid coordinates"
            showError = true
            return
        }
        
        var updated = classroom
        updated.name = classroomName
        updated.professor = professor
        updated.description = description
        updated.position = ClassroomPosition(x: x, y: y, z: z)
        
        do {
            try MapStorageManager.shared.updateClassroom(updated, in: mapId)
            onClassroomUpdated(updated)
            dismiss()
        } catch {
            errorMessage = "Failed to update classroom: \(error.localizedDescription)"
            showError = true
        }
    }
}

#Preview {
    EditClassroomView(
        classroom: Classroom(
            name: "Room 101",
            professor: "Prof. Smith",
            description: "Math classroom",
            position: ClassroomPosition(x: 1, y: 0, z: -2)
        ),
        mapId: UUID()
    ) { _ in }
}
