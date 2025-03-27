//
//  DownloadAssetTaskModel.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//  Copyright © 2025 Rai - Radiotelevisione Italiana Spa. All rights reserved.
//

import Foundation
import AVFoundation

class DownloadAssetTaskModel {
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
    
    var task: AVAggregateAssetDownloadTask?
}

extension DownloadAssetTaskModel: Equatable {
    static func ==(lhs: DownloadAssetTaskModel, rhs: DownloadAssetTaskModel) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}

extension DownloadAssetTaskModel: CustomDebugStringConvertible {
    var debugDescription: String {
        "\(identifier.prefix(9))"
    }
}
