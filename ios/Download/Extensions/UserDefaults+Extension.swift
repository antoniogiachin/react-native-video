//
//  Keys.swift
//  react-native-video
//
//  Created by Davide Balistreri on 07/03/25.
//

import Foundation

extension UserDefaults {
    private enum Keys {
        static let downloads = "downloads"
    }
    
    func setDownloads(_ downloads: [DownloadModel]) {
        do {
            let encoded = try JSONEncoder().encode(downloads)
            set(encoded, forKey: Keys.downloads)
            synchronize()
        } catch let error {
            debugPrint("\(error)")
        }
    }
    
    func getDownloads() -> [DownloadModel]? {
        guard let savedData = data(forKey: Keys.downloads) else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode([DownloadModel].self, from: savedData)
        } catch let error {
            debugPrint("\(error)")
            return nil
        }
    }
}
