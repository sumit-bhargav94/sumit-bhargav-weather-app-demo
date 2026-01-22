//
//  SupabaseManager.swift
//  Glasscast-A Minimal Weather App
//
//  Created by Sam's Mac on 21/01/26.
//

import Foundation
import Supabase
import Combine

@MainActor
final class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()
    
    // Configure with your Supabase project URL and anon key.
    // NOTE: For production, consider moving secrets into configuration.
    private let supabaseURL = URL(string: "https://gkhjjokrsiuyqcmpjcmw.supabase.co")!
    private let supabaseAnonKey = "sb_publishable_kpJ_2UmkDA8QwugO5JTApQ_2GVu-L-0"
    
    let client: SupabaseClient
    
    // Expose current session user id for convenience
    @Published private(set) var currentUserID: UUID?
    @Published private(set) var isAuthenticated: Bool = false
    
    private init() {
        // Build options with explicit auth flow type and default keychain storage for auth.
        let options = SupabaseClientOptions(
            db: .init(),
//            auth: .init(
//                redirectToURL: nil,
//                storageKey: nil,
//                flowType: .implicit, // Switched to .implicit; try .pkce if your project requires it
//                encoder: .init(),
//                decoder: .init(),
//                autoRefreshToken: AuthClient.Configuration.defaultAutoRefreshToken,
//                emitLocalSessionAsInitialSession: true,
//                accessToken: nil
//            ),
            auth: .init(
                redirectToURL: nil,
                storageKey: nil,
                flowType: .implicit,
                autoRefreshToken: AuthClient.Configuration.defaultAutoRefreshToken,
                emitLocalSessionAsInitialSession: true
            ),

            global: .init(),
            functions: .init(),
            realtime: .init(),
            storage: .init()
        )
        
        client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseAnonKey,
            options: options
        )
        
        // Listen to auth state changes and publish user id/auth flag
        Task {
            for await (event, session) in client.auth.authStateChanges {
                // Log event + user info
                if let s = session {
                    print("[Supabase] authStateChanges event=\(event.rawValue)")
                    Self.logSession(prefix: "Auth Event \(event.rawValue)", session: s)
                } else {
                    print("[Supabase] authStateChanges event=\(event.rawValue), session=nil")
                }
                
                await MainActor.run {
                    self.currentUserID = session?.user.id
                    self.isAuthenticated = (session != nil) && !(session?.isExpired ?? true)
                }
                
                // Summarize current auth flags
                print("[Supabase] isAuthenticated=\(self.isAuthenticated), currentUserID=\(self.currentUserID?.uuidString ?? "nil")")
            }
        }
        
        // Try to load any existing session immediately
        Task {
            print("[Supabase] Checking initial session…")
            if let session = try? await client.auth.session {
                Self.logSession(prefix: "Initial session", session: session)
                await MainActor.run {
                    self.currentUserID = session.user.id
                    self.isAuthenticated = !session.isExpired
                }
                print("[Supabase] Initial isAuthenticated=\(self.isAuthenticated)")
            } else {
                print("[Supabase] Initial session: none")
                await MainActor.run {
                    self.currentUserID = nil
                    self.isAuthenticated = false
                }
            }
        }
    }
    
    // Helper to get the best token available (user access token if logged in, else anon key)
    func authorizationHeader() async -> String {
        // Try to use user access token
        if let token = try? await client.auth.session.accessToken {
            return "Bearer \(token)"
        }
        // Fallback to anon key
        return "Bearer \(supabaseAnonKey)"
    }
    
    // Convenience sign-in / sign-out wrappers (call these from Login/Settings screens)
    func signIn(email: String, password: String) async throws {
        print("[Supabase] signIn started for email=\(email)")
        do {
            let session = try await client.auth.signIn(email: email, password: password)
            Self.logSession(prefix: "Sign in response", session: session)
            print("[Supabase] signIn success. isExpired=\(session.isExpired)")
        } catch {
            let ns = error as NSError
            print("[Supabase] signIn failed: \(error.localizedDescription) domain=\(ns.domain) code=\(ns.code) userInfo=\(ns.userInfo)")
            throw error
        }
        // authStateChanges will update currentUserID/isAuthenticated
    }
    
    // Fallback sign-in: use REST password grant, then set session into SDK.
    func signInFallback(email: String, password: String) async throws {
        print("[Supabase] signInFallback started for email=\(email)")
        let (accessToken, refreshToken) = try await fetchTokensViaREST(email: email, password: password)
        do {
            try await client.auth.setSession(accessToken: accessToken, refreshToken: refreshToken)
            print("[Supabase] signInFallback setSession succeeded")
            // authStateChanges will update currentUserID/isAuthenticated
        } catch {
            print("[Supabase] signInFallback setSession failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func fetchTokensViaREST(email: String, password: String) async throws -> (String, String) {
        let url = supabaseURL.appendingPathComponent("auth/v1/token")
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "grant_type", value: "password")]
        guard let finalURL = comps.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: finalURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        
        guard (200..<300).contains(status) else {
            let text = String(data: data, encoding: .utf8) ?? "<non-UTF8 body, \(data.count) bytes>"
            print("[Supabase Fallback] HTTP \(status) body=\(text)")
            throw NSError(domain: "SupabaseFallback", code: status, userInfo: [NSLocalizedDescriptionKey: "Sign-in failed (HTTP \(status))."])
        }
        
        struct TokenResponse: Decodable {
            let access_token: String
            let refresh_token: String
        }
        do {
            let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
            return (decoded.access_token, decoded.refresh_token)
        } catch {
            // As a last resort, try to parse minimally
            if
                let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                let at = json["access_token"] as? String,
                let rt = json["refresh_token"] as? String
            {
                return (at, rt)
            }
            throw error
        }
    }
    
    func signOut() async throws {
        print("[Supabase] signOut started")
        do {
            try await client.auth.signOut()
            print("[Supabase] Signed out successfully.")
        } catch {
            print("[Supabase] signOut failed: \(error.localizedDescription)")
            throw error
        }
        // authStateChanges will update currentUserID/isAuthenticated
    }
    
    // MARK: - Diagnostics
    
    // Raw REST probe to inspect backend JSON for password grant.
    // Returns the raw JSON string (success or error) for debugging.
    func rawSignInProbe(email: String, password: String) async throws -> String {
        let url = supabaseURL.appendingPathComponent("auth/v1/token")
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "grant_type", value: "password")]
        guard let finalURL = comps.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: finalURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        
        let text = String(data: data, encoding: .utf8) ?? "<non-UTF8 body, \(data.count) bytes>"
        print("[Supabase Probe] status=\(status) body=\(text)")
        
        // Surface both status and body to caller
        return "HTTP \(status)\n\(text)"
    }
    
    // Call this from anywhere to print current auth status and session snippet.
    func printAuthStatus() {
        Task {
            do {
                if let session = try? await client.auth.session {
                    Self.logSession(prefix: "Current session", session: session)
                    print("[Supabase] isAuthenticated=\(!session.isExpired)")
                } else {
                    print("[Supabase] No current session. isAuthenticated=false")
                }
            }
        }
    }
    
    // MARK: - Logging helpers
    
    private static func logSession(prefix: String, session: Session) {
        let user = session.user
        let email = user.email ?? "(no email)"
        let expiresAt = Date(timeIntervalSince1970: session.expiresAt)
        print("""
        [Supabase] \(prefix):
          user.id: \(user.id.uuidString)
          user.email: \(email)
          tokenType: \(session.tokenType)
          accessToken (first 16): \(String(session.accessToken.prefix(16)))…
          expiresAt: \(expiresAt)  expired? \(session.isExpired)
        """)
    }
    
    // Raw anon key if ever needed
    var anonKey: String { supabaseAnonKey }
    var projectURL: URL { supabaseURL }
}
