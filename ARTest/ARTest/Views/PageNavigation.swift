//
//  PageNavigation.swift
//  ARTest
//
//  Created by Alen Kaucic on 16. 01. 26.
//

import SwiftUI

struct PageNavigation: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            MapManagementView()
                .tabItem {
                    Label("Maps", systemImage: "map.fill")
                }
                .tag(1)
            
            InfoView()
                .tabItem {
                    Label("Info", systemImage: "info.circle.fill")
                }
                .tag(2)
        }
    }
}

struct HomeView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Indoor Navigation AR")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Map buildings and find classrooms using AR")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemBlue).opacity(0.1))
                .cornerRadius(12)
                .padding()
                
                VStack(spacing: 12) {
                    QuickStartCard(
                        title: "Scan Building",
                        description: "Use AR to scan and map a building's interior",
                        icon: "arkit",
                        color: .blue,
                        destination: {
                            MapManagementView()
                        }
                    )
                    
                    QuickStartCard(
                        title: "Add Classrooms",
                        description: "Mark classroom locations within the building",
                        icon: "building.2",
                        color: .green,
                        destination: {
                            Text("Navigate to maps first")
                        }
                    )
                    
                    QuickStartCard(
                        title: "View in AR",
                        description: "See all classrooms displayed in augmented reality",
                        icon: "eye",
                        color: .purple,
                        destination: {
                            MapManagementView()
                        }
                    )
                }
                .padding()
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tips for Best Results")
                        .font(.headline)
                    
                    TipRow(icon: "lightbulb.fill", text: "Scan large areas with varied features for better tracking")
                    TipRow(icon: "lightbulb.fill", text: "Ensure adequate lighting when scanning buildings")
                    TipRow(icon: "lightbulb.fill", text: "Place classrooms accurately for consistent AR display")
                    TipRow(icon: "lightbulb.fill", text: "World coordinates remain consistent across sessions")
                }
                .padding()
                .background(Color(.systemYellow).opacity(0.1))
                .cornerRadius(12)
                .padding()
                
                Spacer()
            }
            .navigationTitle("FERI" )
        }
    }
}

struct QuickStartCard<Destination: View>: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    @ViewBuilder let destination: () -> Destination
    
    var body: some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(color)
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

struct TipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.orange)
                .frame(width: 24)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct InfoView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("About This App")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Indoor Navigation AR is designed to help you:")
                            .font(.subheadline)
                        BulletPoint(text: "Scan and save building maps using Apple's WorldMap technology")
                        BulletPoint(text: "Mark and manage classroom locations within buildings")
                        BulletPoint(text: "View classrooms in augmented reality and get the quickest route")
                        BulletPoint(text: "Store professor information and classroom descriptions")
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("How It Works")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        StepView(number: 1, title: "Scan", description: "Select the buidling in which you are in and scan the interior using AR")
                        
                        Divider()
                        
                        StepView(number: 2, title: "Save", description: "After the map is synched you can select the classroom you are looking for")
                        
                        Divider()
                        
                        StepView(number: 3, title: "Add Classrooms", description: "A* algorithem will find the quickest route to the classroom and display the path in AR")
                        
                        Divider()
                        
                        StepView(number: 4, title: "View", description: "Follow the trail and find your classroom easily")
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Features")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        FeatureItem(icon: "map", text: "Multiple building maps")
                        FeatureItem(icon: "building.2", text: "Unlimited classrooms per map")
                        FeatureItem(icon: "arkit", text: "AR visualization")
                        FeatureItem(icon: "square.and.pencil", text: "Edit classroom information")
                        FeatureItem(icon: "doc.text", text: "Professor and description storage")
                        FeatureItem(icon: "checkmark.circle", text: "Persistent coordinate system")
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Spacer()
            }
            .navigationTitle("Information")
        }
    }
}

struct BulletPoint: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 4))
                .padding(.top, 6)
            Text(text)
                .font(.caption)
        }
    }
}

struct StepView: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack {
                Text("\(number)")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.blue)
                    .cornerRadius(16)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

struct FeatureItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(text)
                .font(.caption)
        }
    }
}

#Preview {
    PageNavigation()
}
