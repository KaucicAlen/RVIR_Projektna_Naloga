//
//  ContentView.swift
//  ARTest
//
import Combine
import SwiftUI
import RealityKit
import ARKit

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {

            UserInfoView()
                .tabItem {
                    Label("Sobe", systemImage: "person")
                }
                .tag(0)

            SettingsView()
                .tabItem {
                    Label("Urejanje", systemImage: "gear")
                }
                .tag(1)

    
            if selectedTab == 2 {
                ARPageView()
                    .tabItem {
                        Label("AR", systemImage: "arkit")
                    }
                    .tag(2)
            } else {
                
                Color.clear
                    .tabItem {
                        Label("AR", systemImage: "arkit")
                    }
                    .tag(2)
            }
        }
    }
}


#Preview {
    ContentView()
}
