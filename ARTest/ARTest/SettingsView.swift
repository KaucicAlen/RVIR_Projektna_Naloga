//
//  SettingsView.swift
//  ARTest
//
//  Created by Alen Kaucic on 24. 10. 25.
//

import SwiftUI

struct SettingsView: View {
    
    @State private var sobe: [Soba] = []
        
    // Trenutno urejana soba
    @State private var izbranaSoba: Soba?
        
    // Obrazec za urejanje
    @State private var prikaziObrazec = false
    
    
    var body: some View {
        NavigationView {
            List {
                ForEach(sobe) { soba in
                    Button(action: {
                        izbranaSoba = soba
                        prikaziObrazec = true
                    }) {
                        VStack(alignment: .leading) {
                            Text("Naziv sobe: \(soba.nazivSobe)")
                                .font(.headline)
                            Text("Profesor: \(soba.imeProfesorja)")
                            Text("Email: \(soba.emailProfesorja)")
                                .foregroundColor(.blue)
                        }
                        .padding(.vertical, 5)
                    }
                }
                .onDelete(perform: izbrisiSobo)
            }
            
            .navigationTitle("Uredi sobe")
            .onAppear {
                naloziIzUserDefaults()
            }
            .sheet(isPresented: $prikaziObrazec) {
                if let soba = izbranaSoba {
                    urejanjeObrazec(soba: soba)
                }
            }
        }
        
    }
    
    // MARK: - Funkcija za branje iz UserDefaults
        private func naloziIzUserDefaults() {
            if let savedData = UserDefaults.standard.data(forKey: "sobe"),
               let decoded = try? JSONDecoder().decode([Soba].self, from: savedData) {
                sobe = decoded
            }
        }
        
    // MARK: - Funkcija za shranjevanje v UserDefaults
        private func shraniVUserDefaults() {
            if let encoded = try? JSONEncoder().encode(sobe) {
                UserDefaults.standard.set(encoded, forKey: "sobe")
            }
        }
    
    //MARK: - Obrazec za urejanje podatkov
    @ViewBuilder
    private func urejanjeObrazec(soba: Soba) -> some View{
        Form{
            TextField("Tip sobe", text: bindingFor(soba.id, keyPath: \.tipSobe))
            TextField("Nadstropje", text: bindingFor(soba.id, keyPath: \.nadstropje))
            TextField("Naziv sobe", text: bindingFor(soba.id, keyPath: \.nazivSobe))
            TextField("Ime Profesorja", text: bindingFor(soba.id, keyPath: \.imeProfesorja))
            TextField("Email Profesorja", text: bindingFor(soba.id, keyPath: \.emailProfesorja))
            
            Button("Shrani Spremembe"){
                shraniVUserDefaults()
                prikaziObrazec = false
            }
            
        }
        .navigationTitle("Uredi podatke sobe")
        .navigationBarItems(trailing: Button("Zapri"){
            prikaziObrazec = false
        })
    }
    
    //MARK: -Binding funkcija
    private func bindingFor(_ id: UUID, keyPath: WritableKeyPath<Soba, String>) -> Binding<String> {
        guard let index = sobe.firstIndex(where: {$0.id == id}) else {
            return .constant("")
        }
        return Binding(
            get: {sobe[index][keyPath: keyPath]},
            set: {sobe[index][keyPath: keyPath] = $0}
        )
    }
    
    //MARK: - Brisanje sobe
    private func izbrisiSobo(at offsets: IndexSet){
        sobe.remove(atOffsets: offsets)
        shraniVUserDefaults()
    }
    
}

#Preview {
    SettingsView()
}

