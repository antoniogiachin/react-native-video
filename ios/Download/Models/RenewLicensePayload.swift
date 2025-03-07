//
//  RenewLicensePayload.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation

struct RenewLicensePayload: ReactDictionaryConvertible {
  let item: RCTDownloadItem
  let result: Bool
}
