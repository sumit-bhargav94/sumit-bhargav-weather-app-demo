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

// Updated model to include optional country returned by Supabase.
// Extended with optional lat/lon so we can place map markers without geocoding.
struct FavoriteCity: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let user_id: UUID
    let city: String
    let country: String
    let created_at: Date?
    let lat: Double?
    let lon: Double?
    
    var userID: UUID { user_id }
}

protocol SupabaseFavoriting {
    func fetchFavorites(for userID: UUID) async throws -> [FavoriteCity]
    func addFavorite(for userID: UUID, city: String, country: String?, lat: Double?, lon: Double?) async throws -> FavoriteCity
    func removeFavorite(id: UUID) async throws
}

// NOTE: This is a minimal PostgREST-based client using URLSession.
// If you add the official Supabase Swift SDK, you can replace this with that client.
final class SupabaseService: SupabaseFavoriting, @unchecked Sendable {
    private let baseURL: URL
    private let apiKey: String
    private let urlSession: URLSession
    
    // Configure with your Supabase project URL and anon key.
    // IMPORTANT: baseURL must point to the PostgREST endpoint (/rest/v1).
    init(
        baseURL: URL = URL(string: "https://gkhjjokrsiuyqcmpjcmw.supabase.co/rest/v1")!,
        apiKey: String = "sb_publishable_kpJ_2UmkDA8QwugO5JTApQ_2GVu-L-0",
        urlSession: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.urlSession = urlSession
    }
    
    private func request(path: String, method: String, query: [URLQueryItem] = [], body: Data? = nil, prefer: String? = nil) throws -> URLRequest {
        // path should be a table path relative to /rest/v1, e.g. "favorite_cities"
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query
        }
        var req = URLRequest(url: components.url!)
        req.httpMethod = method
        // Default headers use anon key. We'll override Authorization below with user token if available.
        req.addValue(apiKey, forHTTPHeaderField: "apikey")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.addValue("application/json", forHTTPHeaderField: "Accept")
        if let prefer {
            req.addValue(prefer, forHTTPHeaderField: "Prefer")
        }
        req.httpBody = body
        return req
    }

    // Inject Authorization after building the request, preferring the authenticated token.
    private func authorize(_ request: URLRequest) async -> URLRequest {
        var req = request
        // Ask SupabaseManager for the best Authorization header (user token if exists, else anon)
        let authHeader = await SupabaseManager.shared.authorizationHeader()
        req.setValue(authHeader, forHTTPHeaderField: "Authorization")
        return req
    }
    
    func fetchFavorites(for userID: UUID) async throws -> [FavoriteCity] {
        // Include lat/lon in the select.
        let select = "id,user_id,city:city_name,country,created_at,lat,lon"
        let req = try request(
            path: "favorite_cities",
            method: "GET",
            query: [
                URLQueryItem(name: "select", value: select),
                URLQueryItem(name: "order", value: "created_at.desc"),
                URLQueryItem(name: "user_id", value: "eq.\(userID.uuidString.lowercased())")
            ]
        )
        let authorized = await authorize(req)
        logRequest(authorized, label: "FETCH favorites")
        do {
            let (data, resp) = try await urlSession.data(for: authorized)
            try SupabaseService.ensureOK(resp: resp, data: data, context: "FETCH favorites")
            logResponse(resp, data: data, label: "FETCH favorites OK")
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([FavoriteCity].self, from: data)
        } catch {
            logError(error, label: "FETCH favorites FAILED")
            throw error
        }
    }
    
    func addFavorite(for userID: UUID, city: String, country: String?, lat: Double?, lon: Double?) async throws -> FavoriteCity {
        // Insert using city_name, country, lat, lon; return with alias for city and include all fields.
        struct Insert: Codable {
            let user_id: UUID
            let city_name: String
            let country: String?
            let lat: Double?
            let lon: Double?
        }
        let payload = try JSONEncoder().encode([Insert(user_id: userID, city_name: city, country: country, lat: lat, lon: lon)])
        let req = try request(
            path: "favorite_cities",
            method: "POST",
            query: [
                URLQueryItem(name: "select", value: "id,user_id,city:city_name,country,created_at,lat,lon")
            ],
            body: payload,
            prefer: "return=representation"
        )
        let authorized = await authorize(req)
        logRequest(authorized, label: "ADD favorite", bodyPreview: payload)
        do {
            let (data, resp) = try await urlSession.data(for: authorized)
            try SupabaseService.ensureOK(resp: resp, data: data, context: "ADD favorite")
            logResponse(resp, data: data, label: "ADD favorite OK")
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let inserted = try decoder.decode([FavoriteCity].self, from: data)
            guard let first = inserted.first else {
                let err = NSError(domain: "SupabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Insert returned no rows"])
                logError(err, label: "ADD favorite decode FAILED")
                throw err
            }
            return first
        } catch {
            logError(error, label: "ADD favorite FAILED")
            throw error
        }
    }
    
    func removeFavorite(id: UUID) async throws {
        let req = try request(
            path: "favorite_cities",
            method: "DELETE",
            query: [
                URLQueryItem(name: "id", value: "eq.\(id.uuidString.lowercased())")
            ],
            prefer: "return=minimal"
        )
        let authorized = await authorize(req)
        logRequest(authorized, label: "REMOVE favorite")
        do {
            let (data, resp) = try await urlSession.data(for: authorized)
            try SupabaseService.ensureOK(resp: resp, data: data, context: "REMOVE favorite")
            logResponse(resp, data: data, label: "REMOVE favorite OK")
        } catch {
            logError(error, label: "REMOVE favorite FAILED")
            throw error
        }
    }
    
    private static func ensureOK(resp: URLResponse, data: Data) throws {
        // kept for backward compat; calls the contextual version with a default label
        try ensureOK(resp: resp, data: data, context: "HTTP")
    }
    
    private static func ensureOK(resp: URLResponse, data: Data, context: String) throws {
        guard let http = resp as? HTTPURLResponse else { return }
        if (200...299).contains(http.statusCode) { return }
        let body = String(data: data, encoding: .utf8) ?? ""
        print("[SupabaseService] \(context) ERROR status=\(http.statusCode) body=\(body)")
        throw NSError(domain: "SupabaseService", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(body)"])
    }
    
    // MARK: - Logging helpers
    
    private func logRequest(_ req: URLRequest, label: String, bodyPreview: Data? = nil) {
        let urlStr = req.url?.absoluteString ?? "<nil url>"
        let method = req.httpMethod ?? "GET"
        let auth = req.value(forHTTPHeaderField: "Authorization") ?? "<none>"
        let apiKeyHeader = req.value(forHTTPHeaderField: "apikey") != nil
        var msg = "[SupabaseService] \(label) REQUEST \(method) \(urlStr)\n  apikeyHeader=\(apiKeyHeader) authPrefix=\(auth.prefix(16))…"
        if let bodyPreview, let bodyText = String(data: bodyPreview, encoding: .utf8) {
            msg += "\n  body=\(bodyText)"
        }
        print(msg)
    }
    
    private func logResponse(_ resp: URLResponse, data: Data, label: String) {
        guard let http = resp as? HTTPURLResponse else {
            print("[SupabaseService] \(label) RESPONSE non-HTTP")
            return
        }
        let body = String(data: data, encoding: .utf8) ?? "<non-UTF8 body, \(data.count) bytes>"
        print("[SupabaseService] \(label) RESPONSE status=\(http.statusCode) body=\(body)")
    }
    
    private func logError(_ error: Error, label: String) {
        let ns = error as NSError
        print("[SupabaseService] \(label): \(ns.domain) code=\(ns.code) message=\(ns.localizedDescription) userInfo=\(ns.userInfo)")
    }
}

