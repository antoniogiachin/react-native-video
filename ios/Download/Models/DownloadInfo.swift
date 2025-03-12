//
//  DownloadInfo.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation
import AVFoundation

class DownloadInfo: NSObject {
    let asset: AVURLAsset
    let licenseData: MediapolisModelLicenceServerMapDRMLicenceUrl?
    var identifier: String
    var bitrate: Double?
    
    init(
        identifier: String,
        asset: AVURLAsset,
        licenseData: MediapolisModelLicenceServerMapDRMLicenceUrl? = nil,
        bitrate: Double? = nil
    ) {
        self.asset = asset
        self.identifier = identifier
        self.licenseData = licenseData
        self.bitrate = bitrate
    }
    
    static func ==(lhs: DownloadInfo, rhs: DownloadInfo) -> Bool {
        return lhs.identifier == rhs.identifier
    }
    
    var task: AVAggregateAssetDownloadTask?
    var state: DownloadState?
}
