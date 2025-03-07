//
//  RCTDictionaryEncodable.swift
//  react-native-video
//
//  Created by Davide Balistreri on 07/03/25.
//

import Foundation

/// Helper protocol to convert a model into a dictionary and vice versa
public protocol ReactDictionaryConvertible: Codable {
    /// Create a model from a dictionary (from React Native)
    static func from(_ dictionary: [String: Any]) -> Self?
    
    /// Convert a model into a dictionary (to React Native)
    func toDictionary() -> [String: Any]?
}

public extension ReactDictionaryConvertible {
    static func from(_ dictionary: [String: Any]) -> Self? {
        do {
            let data = try JSONSerialization.data(
                withJSONObject: dictionary,
                options: .fragmentsAllowed
            )
            let decoder = JSONDecoder()
            let object = try decoder.decode(Self.self, from: data)
            return object
        } catch {
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
