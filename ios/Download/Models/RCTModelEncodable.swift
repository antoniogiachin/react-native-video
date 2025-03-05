//
//  RCTModelEncodable.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation

public protocol RCTModelEncodable: Encodable {
  static var decoder: JSONEncoder { get }
  
  func toDictionary() -> [String: Any]
}

public extension RCTModelEncodable {
  
  static var decoder: JSONEncoder {
    return JSONEncoder()
  }
  
  func toDictionary() -> [String: Any] {
    do {
      let data = try Self.decoder.encode(self)
      guard let dictionary = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else { throw NSError() }
      return dictionary
    } catch {
      return [onErrorType.error.rawValue: "something went wrong during event mapping"]
    }
  }
  
}
