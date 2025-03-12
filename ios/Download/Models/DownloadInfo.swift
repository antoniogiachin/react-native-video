//
//  DownloadInfo.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation
import AVFoundation

public class DownloadInfo {
    public let asset: AVURLAsset
    public let licenseData: MediapolisModelLicenceServerMapDRMLicenceUrl?
    public var identifier: String
    public var bitrate: Double?
    
    public init(identifier: String, avUrlAsset: AVURLAsset, licenseData: MediapolisModelLicenceServerMapDRMLicenceUrl? = nil, bitrate: Double? = nil) {
        self.asset = avUrlAsset
        self.identifier = identifier
        self.licenseData = licenseData
        self.bitrate = bitrate
    }
    
    public static func ==(lhs: DownloadInfo, rhs: DownloadInfo) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}

public extension DownloadInfo {
    enum RAIAVAssetStatus: String, Codable {
        case Queue = "Queue"
        case Downloading = "Downloading"
        case Paused = "Paused"
        case Completed = "Completed"
    }
}
