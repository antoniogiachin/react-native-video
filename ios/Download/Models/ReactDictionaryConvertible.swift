//
//  ReactDictionaryConvertible.swift
//  react-native-video
//
//  Created by Davide Balistreri on 07/03/25.
//  Copyright © 2025 Rai - Radiotelevisione Italiana Spa. All rights reserved.
//

import Foundation

/// Helper protocol to convert a model into a dictionary and vice versa
protocol ReactDictionaryConvertible: Codable {
    /// Create a model from a dictionary (from React Native)
    static func from(_ dictionary: [String: Any]) -> Self?
    
    /// Convert a model into a dictionary (to React Native)
    func toDictionary() -> [String: Any]?
}

extension ReactDictionaryConvertible {
    static func from(_ dictionary: [String: Any]) -> Self? {
        do {
            let data = try JSONSerialization.data(
                withJSONObject: dictionary,
                options: .fragmentsAllowed
            )
            let decoder = JSONDecoder()
            let object = try decoder.decode(Self.self, from: data)
            return object
        } catch let error {
            debugPrint(" Error while decoding \(Self.self): \(error)")
            return nil
        }
    }
    
    func toDictionary() -> [String: Any]? {
        do {
            let data = try JSONEncoder().encode(self)
            let dictionary = try JSONSerialization.jsonObject(
                with: data,
                options: []
            ) as? [String: Any]
            return dictionary
        } catch {
            return nil
        }
    }
}
