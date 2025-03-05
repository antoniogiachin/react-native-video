//
//  RCTExternalSubtitlesCacheManager.swift
//  react-native-video
//
//  Created by Valerio CARMINE IENCO (KINETON) on 19/11/24.
//

import Foundation

class RCTExternalSubtitlesCacheManager {
    
    public static let shared = RCTExternalSubtitlesCacheManager()
    
    private static let SUBTITLES_PATH = "subtitles"
    
    public func downloadSubtitles(videoId: String, subtitles: [RCTExternalSubtitleModel]?, completion: @escaping (_ subtitles: [RCTExternalSubtitleModel]?, _ err: Error?) -> Void) {
        guard let subtitles else {
            completion(nil, nil)
            return
        }
        var cachedSubtitles: [RCTExternalSubtitleModel] = []
        var localError: Error?
        let group = DispatchGroup()
        subtitles.forEach { subtitle in
            group.enter()
          if let url = URL(string: subtitle.url!), let subtitleId = subtitle.id {
                downloadData(url: url) { data, error in
                    if let error = error {
                        localError = error
                        group.leave()
                        return
                    }
                    let diskUrl = DownloadMetadataCacheManager.createDirectoryIfNotExists(withName: "\(DownloadMetadataCacheManager.MEDIA_CACHE_KEY)/\(videoId)/\(RCTExternalSubtitlesCacheManager.SUBTITLES_PATH)/\(subtitleId)")
                    if let error = diskUrl.error {
                        localError = error
                        group.leave()
                        return
                    }
                    let cachedSubtitle = RCTExternalSubtitleModel()
                    cachedSubtitle.id = subtitle.id
                    cachedSubtitle.label = subtitle.label
                    cachedSubtitle.url = diskUrl.url?.absoluteString
                    cachedSubtitles.append(cachedSubtitle)
                    group.leave()
                }
            } else {
                localError = NSError(domain: "url or subtitle id not valid", code: 500)
                group.leave()
            }
        }
        if let localError {
            group.notify(queue: .main, execute: {
                completion(nil, localError)
            })
            return
        }
        group.notify(queue: .main, execute: {
            completion(cachedSubtitles, nil)
        })
    }
    
    private func downloadData(url: URL, completion: @escaping (Data?, Error?) -> Void) {
        let session = URLSession(configuration: URLSessionConfiguration.default, delegate: nil, delegateQueue: nil)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let task = session.dataTask(with: request, completionHandler: { data, response, error in
            
            if error == nil {
                
                if let response = response as? HTTPURLResponse {
                    if response.statusCode == 200 {
                        if let data = data {
                            completion(data, error)
                        } else {
                            completion(nil, error)
                        }
                    }
                }
            } else {
                completion(nil, error)
            }
        })
        task.resume()
    }
}
