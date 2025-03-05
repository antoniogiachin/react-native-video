//
//  RCTDownloadProgress.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation

public struct RCTDownloadProgress: Decodable, RCTModelEncodable {
    public let downloaded: Double
    public let total: Double
}
