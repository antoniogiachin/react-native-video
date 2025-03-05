//
//  MediapolisModel.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation

// MARK: - MediapolisModel
public struct RAIPlayerMediapolisModel: Codable {
    public let video: [String]?
    public let playlist: [RAIPlayerMediapolisModelPlaylistItem]?
    public let ct, bitrate, smooth, isLive: String?
    public let mediapolisModelDescription, geoprotection, category, duration: String?
    public let adsTecnico, adsEditoriale: String?
    public let licenceServerMap: MediapolisModelLicenceServerMap?
    public let thumbsArray: MediapolisModelThumbsArray?
    public let vttPosterThumbsURL: String?

    enum CodingKeys: String, CodingKey {
        case video, playlist, ct, bitrate, smooth
        case isLive = "is_live"
        case mediapolisModelDescription = "description"
        case geoprotection, category, duration
        case adsTecnico = "ads_tecnico"
        case adsEditoriale = "ads_editoriale"
        case licenceServerMap = "licence_server_map"
        case thumbsArray = "thumbs_array"
        case vttPosterThumbsURL = "vtt_poster_thumbs_url"
    }
}

public struct MediapolisModelLicenceServerMap: Codable {
    public var drmLicenseUrlValues : [MediapolisModelLicenceServerMapDRMLicenceUrl]?
    
    enum CodingKeys: String, CodingKey {
        case drmLicenseUrlValues = "drmLicenseUrlValues"
    }
}

open class MediapolisModelLicenceServerMapDRMLicenceUrl: Codable {
    public var drm : String?
    public var licenseUrl : String?
    public var audience: String?
    public var name: String?
    public var operatorDrm: String?
    
    public var fullLicenseUrl : String? {
        get{
            if drmSystemType == .fairplay, let licenseUrl = self.licenseUrl {
                return licenseUrl.replacingOccurrences(of: "skd", with: "https")
            }
            return nil
        }
    }
        
    public var drmOperator: DRMOperator {
        switch operatorDrm?.trimWhitespaces()?.lowercased() {
        case "azure":
            return .azure
        case "verimatrix":
            return .verimatrix
        case "nagra":
            return .nagra
        default:
            return .azure
        }
    }
    
    public var drmSystemType: DRMSystemType {
        switch drm?.trimWhitespaces()?.lowercased() {
        case "fairplay":
            return .fairplay
        case "widevine":
            return .widevine
        case "playready":
            return .playready
        default:
            return .unknown
        }
    }
    
    public init(){
        
    }
    
    enum CodingKeys: String, CodingKey {
        case drm = "drm"
        case licenseUrl = "licenceUrl"
        case audience = "audience"
        case name = "name"
        case operatorDrm = "operator"
    }
}

// MARK: - Playlist
public struct RAIPlayerMediapolisModelPlaylistItem: Codable {
    public let type: String?
    public let url: String?
}

// MARK: - ThumbsArray
public struct MediapolisModelThumbsArray: Codable {
    
    public init(){ }
    
    public var shots, frameHeight, rowsPerStrips, colsPerStrips: Int?
    public var files: [String]?
}

