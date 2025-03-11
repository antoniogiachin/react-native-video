//
//  ConfigManager.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation

public enum ConfigManagerEndpointType {
    case onair
    case epgAllDays
    case epgByDay
}
    
public class ConfigManager {
    public static let shared = ConfigManager()
    private init(){}
    
    public var mediapolisUserAgent: String?
    public var videoRates: [RateModel]?
    
    public var drmCertificates: [DRMSystemType : URL] = [.fairplay: URL(string: "https://www.raiplay.it/dl/video/drm/fairplay.cer")!]
    
    public var endpoints: [ConfigManagerEndpointType:String] = [:]

    public var replaceBaseURLClosure: ((String?) -> String?)? = nil
}
