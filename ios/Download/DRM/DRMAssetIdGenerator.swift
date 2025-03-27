//
//  DRMAssetIdGenerator.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation

class DRMAssetIdGenerator {
    public func generate(contentKeyIdentifier: String) -> Data? {
        let contentKeyIdentifierURL = URL(string: contentKeyIdentifier)
        let assetIDString = contentKeyIdentifierURL?.host
        let assetIDData = assetIDString?.data(using: .utf8)
        return assetIDData
    }
    
    public class func getInstanceBy(drmOperator: DRMOperator) -> DRMAssetIdGenerator {
        if drmOperator == .nagra {
            return DRMAssetIdGeneratorNagra()
        }
        return DRMAssetIdGenerator()
    }
}

class DRMAssetIdGeneratorNagra: DRMAssetIdGenerator {
    
    override func generate(contentKeyIdentifier: String) -> Data? {
        guard let contentKeyIdentifierURL = URL(string: contentKeyIdentifier) else {
            return nil
        }
        let (contentId, keyId, iVString) =  self.parseSSPLoadingRequest(url: contentKeyIdentifierURL)
        let assetIdDict = ["ContentId": contentId, "KeyId": keyId, "IV": iVString]
        
        return try? JSONSerialization.data(withJSONObject: assetIdDict, options: [])
    }
    
    private func parseSSPLoadingRequest(url: URL) -> (String, String, String) {
      if let jsonResults = jsonFromURL(url: url),
        let contentId = jsonResults["ContentId"] as? String,
        let keyId = jsonResults["KeyId"] as? String,
        let ivString = jsonResults["IV"] as? String {
        
        return (contentId, keyId, ivString)
      }
      
      return ("", "", "")
    }
    
    private func jsonFromURL(url: URL) -> [String: Any]? {
      guard let host = url.host,
        let decodedUrlData = Data(base64Encoded: host, options: NSData.Base64DecodingOptions(rawValue: 0)) else {
          return nil
      }
      
      do {
        let jsonResults = try JSONSerialization.jsonObject(with: decodedUrlData, options: []) as? [String: Any]
        return jsonResults
      } catch {
        return nil
      }
    }
}
