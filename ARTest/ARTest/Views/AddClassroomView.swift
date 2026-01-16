//
//  AddClassroomView.swift
//  ARTest
//
//  Created by Alen Kaucic on 16. 01. 26.
//

import SwiftUI

struct AddClassroomView: View {
    @Environment(\.dismiss) var dismiss
    @State private var classroomName = ""
    @State private var professor = ""
    @State private var description = ""
    @State private var selectedMethod: SelectionMethod = .arPlacement
    @State private var showARPlacement = false
    @State private var manualX = "0"
    @State private var manualY = "0"
    @State private var manualZ = "0"
    @State private var selectedPosition: SIMD3<Float>?
    @State private var errorMessage: String?
    @State private var showError = false
    
    let mapId: UUID
    var onClassroomAdded: (Classroom) -> Void
    
    enum SelectionMethod {
        case arPlacement
        case manualCoordinates
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
                
                Section(header: Text("Position Selection")) {
                    Picker("Method", selection: $selectedMethod) {
                        Text("AR Placement").tag(SelectionMethod.arPlacement)
                        Text("Manual Coordinates").tag(SelectionMethod.manualCoordinates)
                    }
                    .pickerStyle(.segmented)
                    
                    if selectedMethod == .arPlacement {
                        Button(action: { showARPlacement = true }) {
                            HStack {
                                Image(systemName: "arkit")
                                Text(selectedPosition == nil ? "Place in AR" : "Position set ✓")
                                Spacer()
                                if selectedPosition != nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    } else {
                        VStack(spacing: 12) {
                            HStack {
                                Text("X:")
                                    .frame(width: 30)
                                TextField("0", text: $manualX)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                            }
                            HStack {
                                Text("Y:")
                                    .frame(width: 30)
                                TextField("0", text: $manualY)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                            }
                            HStack {
                                Text("Z:")
                                    .frame(width: 30)
                                TextField("0", text: $manualZ)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                    }
                }
                
                Section {
                    Button(action: saveClassroom) {
                        HStack {
                            Spacer()
                            if classroomName.isEmpty {
                                Text("Enter classroom name")
                                    .foregroundColor(.gray)
                            } else if selectedMethod == .arPlacement && selectedPosition == nil {
                                Text("Place in AR first")
                                    .foregroundColor(.gray)
                            } else {
                                Text("Save Classroom")
                                    .foregroundColor(.white)
                            }
                            Spacer()
                        }
                    }
                    .disabled(classroomName.isEmpty || (selectedMethod == .arPlacement && selectedPosition == nil))
                    .listRowBackground(Color.blue)
                }
            }
            .navigationTitle("Add Classroom")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showARPlacement) {
                ARViewContainer(
                    mode: .placing,
                    onClassroomPositionSelected: { position in
                        selectedPosition = position
                        showARPlacement = false
                    }
                )
            }
            .alert("Error", isPresented: $showError, presenting: errorMessage) { _ in
                Button("OK") { }
            } message: { msg in
                Text(msg)
            }
        }
    }
    
    private func saveClassroom() {
        guard !classroomName.isEmpty else {
            errorMessage = "Please enter a classroom name"
            showError = true
            return
        }
        
        let position: ClassroomPosition
        
        if selectedMethod == .arPlacement {
            guard let selectedPosition = selectedPosition else {
                errorMessage = "Please place the classroom in AR"
                showError = true
                return
            }
            position = ClassroomPosition.from(selectedPosition)
        } else {
            guard let x = Float(manualX),
                  let y = Float(manualY),
                  let z = Float(manualZ) else {
                errorMessage = "Please enter valid coordinates"
                showError = true
                return
            }
            position = ClassroomPosition(x: x, y: y, z: z)
        }
        
        let classroom = Classroom(
            name: classroomName,
            professor: professor,
            description: description,
            position: position
        )
        
        do {
            try MapStorageManager.shared.addClassroom(classroom, to: mapId)
            onClassroomAdded(classroom)
            dismiss()
        } catch {
            errorMessage = "Failed to save classroom: \(error.localizedDescription)"
            showError = true
        }
    }
}

#Preview {
    AddClassroomView(mapId: UUID()) { _ in }
}
