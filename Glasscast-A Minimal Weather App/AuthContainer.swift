//
//  AuthContainer.swift
//  Glasscast-A Minimal Weather App
//
//  Created by Sam's Mac on 21/01/26.
//

import SwiftUI

struct AuthContainer: View {
    // Observe Supabase auth state
    @StateObject private var auth = SupabaseManager.shared

    var body: some View {
        NavigationStack {
            Group {
                if auth.isAuthenticated {
                    // Already signed in -> go to main app
                    TabContainerView()
                        .navigationBarBackButtonHidden(true)
                } else {
                    // Not signed in -> show login
                    LoginView()
                }
            }
        }
    }
}

#Preview {
    AuthContainer()
}
