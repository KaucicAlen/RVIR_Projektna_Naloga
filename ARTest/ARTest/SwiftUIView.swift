import SwiftUI

struct SwiftUIView: View {
    
    @State private var selectedRoom: String = "Izberi destinacijo"
    @State private var sobe: [Soba] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            VStack(alignment: .leading, spacing: 4) {
                Text("School Navigator")
                    .font(.title)
                    .bold()
                
                HStack {
                    Text("Made by Alen & Liam")
                        .font(.subheadline)
                    Spacer()
                    Text("FERI")
                        .font(.subheadline)
                        .bold()
                }
            }
            
            Divider()
            
            Text("Izberi destinacijo:")
                .font(.headline)
            
            Menu {
                if sobe.isEmpty {
                    Text("Ni shranjenih sob")
                } else {
                    ForEach(sobe) { soba in
                        Button("\(soba.nazivSobe) - \(soba.imeProfesorja)") {
                            selectedRoom = "\(soba.nazivSobe) - \(soba.imeProfesorja)"
                        }
                    }
                }
            } label: {
                HStack {
                    Text(selectedRoom)
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.blue.opacity(0.7))
                .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding()
        .cornerRadius(12)
        .foregroundColor(.white)
        .shadow(radius: 5)
        .onAppear {
            naloziSobe()
        }
    }
    
    //MARK: - Funkcija za nalaganje sob iz UserDefaults
    private func naloziSobe() {
        if let data = UserDefaults.standard.data(forKey: "sobe"),
           let decoded = try? JSONDecoder().decode([Soba].self, from: data) {
            sobe = decoded
        }
    }
}
