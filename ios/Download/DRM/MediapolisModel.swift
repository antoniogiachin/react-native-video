//
//  MediapolisModel.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation

struct MediapolisModelLicenceServerMap: Codable {
    var drmLicenseUrlValues: [MediapolisModelLicenceServerMapDRMLicenceUrl]?
}

public class MediapolisModelLicenceServerMapDRMLicenceUrl: Codable {
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
        switch operatorDrm?.trimWhitespaces().lowercased() {
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
        switch drm?.trimWhitespaces().lowercased() {
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
