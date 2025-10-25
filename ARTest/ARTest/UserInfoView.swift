//
//  UserInfoView.swift
//  ARTest
//
//  Created by Alen Kaucic on 24. 10. 25.
//

import SwiftUI

struct Soba: Identifiable, Codable {
    let id: UUID
    var tipSobe: String
    var nadstropje: String
    var nazivSobe: String
    var imeProfesorja: String
    var emailProfesorja: String
    
    init(id: UUID = UUID(), tipSobe: String, nadstropje: String, nazivSobe: String, imeProfesorja: String, emailProfesorja: String) {
            self.id = id
            self.tipSobe = tipSobe
            self.nadstropje = nadstropje
            self.nazivSobe = nazivSobe
            self.imeProfesorja = imeProfesorja
            self.emailProfesorja = emailProfesorja
        }
}

struct UserInfoView: View {
    //Seznam sob
    @State private var sobe: [Soba] = []
    
    //podatki iz obrazcaa
    @State private var tipSobe = ""
    @State private var nadstropje = ""
    @State private var nazivSobe = ""
    @State private var imeProfesorja = ""
    @State private var emailProfesorja = ""
    
    //error msg
    @State private var error = ""
    
    //prikaz obrazca
    @State private var prikaziObrazec = false
    
    //Podrobnosti sobe
    @State private var izbranaSoba: Soba?
    
    
    

    var body: some View {
        NavigationView {
            VStack {
                //Seznam sob
                List{
                    ForEach(sobe) { soba in
                        Button(action: {
                            izbranaSoba = soba
                        }){
                            HStack{
                                VStack(alignment: .leading){
                                    Text("Naziv sobe \(soba.nazivSobe)")
                                    Text(soba.imeProfesorja)
                                    
                                }
                                Spacer()
                                Text(soba.emailProfesorja)
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                Button(action: {
                    dodajTestneSobe()
                }){
                    Text("Dodaj testno sobo")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                    
                }
                Button(action: {
                    prikaziObrazec.toggle()
                    pocistiObrazec()
                }){
                    Text("Dodaj sobo")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                .sheet(isPresented: $prikaziObrazec){
                    dodajObrazec()
                }
            }
            
            .navigationTitle("Sobe")
            .onAppear{
                naloziIzUserDefaults()
            }
            .sheet(item: $izbranaSoba){soba in
                prikaziPodrobnosti(soba: soba)
            }
        }
        
    }
    
    // MARK: - obrazec za dodajanje sobe
    @ViewBuilder
    private func dodajObrazec() -> some View{
        NavigationView {
            Form{
                Section(header: Text("Informacije o sobi")){
                    TextField("Tip sobe", text: $tipSobe)
                    TextField("Nadstropje", text: $nadstropje)
                    TextField("Naziv sobe", text: $nazivSobe)
                    TextField("Ime Profesorja", text: $imeProfesorja)
                    TextField("Email Profesorja", text: $emailProfesorja)
                }
                if !error.isEmpty{
                    Text(error)
                        .foregroundColor(.red)
                }
                Button("Shrani sobo"){
                    shraniSobo()
                }
            }
            .navigationTitle("Dodaj sobo")
            .navigationBarItems(trailing: Button("Zapri"){
                prikaziObrazec = false
            })
        }
    }
    
    //MARK: - Dodajanje testne sobe
    private func dodajTestneSobe(){
        let testneSobe = [
            Soba(tipSobe: "Kabinet", nadstropje: "3", nazivSobe: "002", imeProfesorja: "Marko", emailProfesorja: "Marko@gmail.com"),
            Soba(tipSobe: "Kabinet", nadstropje: "1", nazivSobe: "001", imeProfesorja: "Tilen", emailProfesorja: "Tilen@gmail.com"),
            Soba(tipSobe: "Kabinet", nadstropje: "2", nazivSobe: "014", imeProfesorja: "Uros", emailProfesorja: "Uros@gmail.com"),
            Soba(tipSobe: "Kabinet", nadstropje: "3", nazivSobe: "003", imeProfesorja: "Bostjan", emailProfesorja: "Bostjan@gmail.com")
        ]
        sobe.append(contentsOf: testneSobe)
        shraniVUserDefaults()
    }

    //MARK: - Brisanje forme
    private func pocistiObrazec(){
        tipSobe = ""
        nadstropje = ""
        nazivSobe = ""
        imeProfesorja = ""
        emailProfesorja = ""
        error = ""
        
    }
    //MARK: - Shranjevanje podatko
    private func shraniSobo(){
        
        
        guard tipSobe != "" else {
            error = "Polje nemore biti prazno"
            return
        }
        guard nadstropje != "" else {
            error = "Polje nemore biti prazno"
            return
        }
        guard nazivSobe != "" else {
            error = "Polje nemore biti prazno"
            return
        }
        guard imeProfesorja != "" else {
            error = "Polje nemore biti prazno"
            return
        }
        guard emailProfesorja.contains("@") && emailProfesorja.contains(".") else {
            error = "Neveljaven email"
            return
        }
        
        
        let novaSoba = Soba(tipSobe: tipSobe, nadstropje: nadstropje, nazivSobe: nazivSobe, imeProfesorja: imeProfesorja, emailProfesorja: emailProfesorja)
        sobe.append(novaSoba)
        shraniVUserDefaults()
        prikaziObrazec = false
    }
    
    //MARK: - Prikazovanje podrobnosti
    private func prikaziPodrobnosti(soba: Soba) -> some View{
        VStack(spacing: 20){
            Text("Naziv sobe \(soba.nazivSobe)")
                .font(.title)
            Text("Nadstropje \(soba.nadstropje)")
                .font(.title)
            Text("Ime profesorja \(soba.imeProfesorja)")
                .font(.title)
            Text("Email profesorja \(soba.emailProfesorja)")
                .font(.title)
            
            
        }
    }
    
    //MARK: -Trajno shranjevanje v UserDefaults
    private func shraniVUserDefaults(){
        if let encoded = try? JSONEncoder().encode(sobe){
            UserDefaults.standard.set(encoded, forKey: "sobe")
        }
    }
    
    //MARK: - Branje iz UserDefaulst
    private func naloziIzUserDefaults(){
        if let savedData = UserDefaults.standard.data(forKey: "sobe"),
           let decoded = try? JSONDecoder().decode([Soba].self, from:savedData){
            sobe = decoded
        }
    }
}










#Preview{
    UserInfoView()
}


