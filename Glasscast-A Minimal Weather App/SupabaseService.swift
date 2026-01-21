//
//  SupabaseService.swift
//  Glasscast-A Minimal Weather App
//
//  Created by Sam's Mac on 21/01/26.
//

import Foundation
import Combine

// Minimal session holder. Replace with real auth integration later.
final class AppSession: ObservableObject, @unchecked Sendable {
    @Published var currentUserID: UUID
    
    init(currentUserID: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!) {
        self.currentUserID = currentUserID
    }
}

struct FavoriteCity: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let user_id: UUID
    let city: String
    let created_at: Date?
    
    var userID: UUID { user_id }
}

protocol SupabaseFavoriting {
    func fetchFavorites(for userID: UUID) async throws -> [FavoriteCity]
    func addFavorite(for userID: UUID, city: String) async throws -> FavoriteCity
    func removeFavorite(id: UUID) async throws
}

// NOTE: This is a minimal PostgREST-based client using URLSession.
// If you add the official Supabase Swift SDK, you can replace this with that client.
final class SupabaseService: SupabaseFavoriting, @unchecked Sendable {
    private let baseURL: URL
    private let apiKey: String
    private let urlSession: URLSession
    
    // Configure with your Supabase project URL and anon key.
    
    //    let supabase = SupabaseClient(
    //      supabaseURL: URL(string: "https://gkhjjokrsiuyqcmpjcmw.supabase.co")!,
    //      supabaseKey: "sb_publishable_kpJ_2UmkDA8QwugO5JTApQ_2GVu-L-0"
    //    )
    init(
        baseURL: URL = URL(string: "https://gkhjjokrsiuyqcmpjcmw.supabase.co.supabase.co/rest/v1")!,
        apiKey: String = "sb_publishable_kpJ_2UmkDA8QwugO5JTApQ_2GVu-L-0",
        urlSession: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.urlSession = urlSession
    }
    
    private func request(path: String, method: String, query: [URLQueryItem] = [], body: Data? = nil, prefer: String? = nil) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query
        }
        var req = URLRequest(url: components.url!)
        req.httpMethod = method
        req.addValue(apiKey, forHTTPHeaderField: "apikey")
        req.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.addValue("application/json", forHTTPHeaderField: "Accept")
        if let prefer {
            req.addValue(prefer, forHTTPHeaderField: "Prefer")
        }
        req.httpBody = body
        return req
    }
    
    func fetchFavorites(for userID: UUID) async throws -> [FavoriteCity] {
        let filter = "user_id=eq.\(userID.uuidString.lowercased())"
        let req = try request(
            path: "favorites",
            method: "GET",
            query: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "order", value: "created_at.desc"),
                URLQueryItem(name: "user_id", value: nil), // placeholder to keep structure
            ] + [URLQueryItem(name: "user_id", value: "eq.\(userID.uuidString.lowercased())")]
        )
        let (data, resp) = try await urlSession.data(for: req)
        try SupabaseService.ensureOK(resp: resp, data: data)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([FavoriteCity].self, from: data)
    }
    
    func addFavorite(for userID: UUID, city: String) async throws -> FavoriteCity {
        struct Insert: Codable { let user_id: UUID; let city: String }
        let payload = try JSONEncoder().encode([Insert(user_id: userID, city: city)])
        let req = try request(
            path: "favorites",
            method: "POST",
            body: payload,
            prefer: "return=representation"
        )
        let (data, resp) = try await urlSession.data(for: req)
        try SupabaseService.ensureOK(resp: resp, data: data)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let inserted = try decoder.decode([FavoriteCity].self, from: data)
        guard let first = inserted.first else {
            throw NSError(domain: "SupabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Insert returned no rows"])
        }
        return first
    }
    
    func removeFavorite(id: UUID) async throws {
        let req = try request(
            path: "favorites",
            method: "DELETE",
            query: [
                URLQueryItem(name: "id", value: "eq.\(id.uuidString.lowercased())")
            ],
            prefer: "return=minimal"
        )
        let (data, resp) = try await urlSession.data(for: req)
        try SupabaseService.ensureOK(resp: resp, data: data)
    }
    
    private static func ensureOK(resp: URLResponse, data: Data) throws {
        guard let http = resp as? HTTPURLResponse else { return }
        if (200...299).contains(http.statusCode) { return }
        let body = String(data: data, encoding: .utf8) ?? ""
        throw NSError(domain: "SupabaseService", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(body)"])
    }
}

