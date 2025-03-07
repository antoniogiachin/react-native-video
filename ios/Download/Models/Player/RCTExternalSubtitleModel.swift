//
//  RCTExternalSubtitleModel.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation

public class RCTExternalSubtitleModel: Decodable, ReactDictionaryConvertible {
    var id: String?
    var label: String?
    var url: String?
    
    init() {
        
    }
    
    init(dictionary: NSDictionary) {
        if let id = dictionary["id"] as? String {
            self.id = id
        }
        if let label = dictionary["label"] as? String {
            self.label = label
        }
        if let url = dictionary["url"] as? String {
            self.url = url
        }
    }
}
