//
//  HomeView.swift
//  Glasscast-A Minimal Weather App
//
//  Created by Sam's Mac on 21/01/26.
//

import SwiftUI

struct TabContainerView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            
            SearchCityView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
            
            RadarView()
                .tabItem {
                    Label("Radar", systemImage: "map")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .navigationBarBackButtonHidden(true)
    }
}


#Preview {
    NavigationStack {
        TabContainerView()
    }
}
