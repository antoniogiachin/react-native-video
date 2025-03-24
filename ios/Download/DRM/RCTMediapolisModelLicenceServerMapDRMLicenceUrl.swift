//
//  RCTMediapolisModelLicenceServerMapDRMLicenceUrl.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation

public class RCTMediapolisModelLicenceServerMapDRMLicenceUrl: MediapolisModelLicenceServerMapDRMLicenceUrl {
    
    init(operatorDrm: String, licenseUrl: String) {
        super.init()
        self.operatorDrm = operatorDrm
        self.licenseUrl = licenseUrl
        self.drm = "FAIRPLAY"
    }
    
    init?(dictionary: NSDictionary) {
        super.init()
        guard let op = dictionary["operator"] as? String else {
            return nil
        }
        guard let lic =  dictionary["licenceUrl"] as? String ?? dictionary["url"] as? String else {
            return nil
        }
        self.operatorDrm = op
        self.licenseUrl = lic
        self.drm = "FAIRPLAY"
    }
    
    required init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }
}
