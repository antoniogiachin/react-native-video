//
//  DownloadMetadataProtocol.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation

public protocol DownloadMetadataProtocol {
  var identifier: String { get }
  
  func getSize() -> Float?
  
  var ckcData: Data? { get set }
  
  var assetStatus: AssetInfo.RAIAVAssetStatus? { get set }
  
  var progress: RCTDownloadProgress? { get set }
  
  var location: URL? { get set }
  
  var externalSubtitles: [RCTExternalSubtitleModel]? { get set }
  
  var bitrate: Double? { get set }
}

public extension DownloadMetadataProtocol {
  
  func getSize() -> Float? {
      
      guard let url = location else { return nil }
      
      let properties: [URLResourceKey] = [.isRegularFileKey,
                                          .totalFileAllocatedSizeKey]
      
      guard let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: url.relativePath),
                                                            includingPropertiesForKeys: properties,
                                                            options: .skipsHiddenFiles,
                                                            errorHandler: nil) else {
          
          return nil
      }
      
      let urls: [URL] = enumerator
          .compactMap { $0 as? URL }
          .filter { $0.absoluteString.contains(".frag") }
      
      let regularFileResources: [URLResourceValues] = urls
          .compactMap { try? $0.resourceValues(forKeys: Set(properties)) }
          .filter { $0.isRegularFile == true }
      
      let sizes: [Int64] = regularFileResources
          .compactMap { $0.totalFileAllocatedSize }
          .compactMap { Int64($0) }
      
      
      let raw = sizes.reduce(0, +)
      
      let mb = raw / (1024 * 1024)
      
      return Float(mb)
  }
  
}
