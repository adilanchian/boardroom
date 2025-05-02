//
//  SupabaseManager.swift
//  whiteboard
//
//  Created by alec on 4/18/25.
//

import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    private init() {
        // FIXME: - make sure to add diff env stuff.
        client = SupabaseClient(
            supabaseURL: URL(string: "http://127.0.0.1:54321")!,
            supabaseKey: "" // GET API KEY AND STORE.
        )
    }
}
