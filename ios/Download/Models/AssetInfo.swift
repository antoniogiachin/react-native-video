//
//  AssetInfo.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation
import AVFoundation
import CommonCrypto

public class AssetInfo {
    public let avUrlAsset: AVURLAsset
    public let licenseData: MediapolisModelLicenceServerMapDRMLicenceUrl?
    public var identifier: String
    public var bitrate: Double?
    
    public init(identifier: String, avUrlAsset: AVURLAsset, licenseData: MediapolisModelLicenceServerMapDRMLicenceUrl? = nil, bitrate: Double? = nil) {
        self.avUrlAsset = avUrlAsset
        self.identifier = identifier
        self.licenseData = licenseData
        self.bitrate = bitrate
    }
    
    public static func ==(lhs: AssetInfo, rhs: AssetInfo) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}

public extension AssetInfo {
    enum RAIAVAssetStatus: String, Codable {
        case Queue = "Queue"
        case Downloading = "Downloading"
        case Paused = "Paused"
        case Completed = "Completed"
    }
}
