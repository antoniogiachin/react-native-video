//
//  RCTDownloadItem.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation

public struct RCTDownloadItem: ReactDictionaryConvertible {
  let ua: String
  let pathId: String
  let programPathId: String
  let sizeInMb: Float
  let status: String
  let progress: RCTDownloadProgress
  let isDrm: Bool
  
  init(model: DownloadModel) {
      self.pathId = model.pathId
      self.programPathId = model.programPathId
      self.ua = model.ua
      self.sizeInMb = model.getSize() ?? 0
      self.status = model.assetStatus?.rawValue ?? "unknow"
      self.progress = model.progress ?? RCTDownloadProgress(downloaded: 0, total: 0)
      self.isDrm = model.ckcData != nil
  }
}
