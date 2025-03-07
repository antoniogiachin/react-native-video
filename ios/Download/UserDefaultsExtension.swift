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
    
    func setDownloads(_ downloads: [NewDownloadModel]) {
        do {
            let encoded = try JSONEncoder().encode(downloads)
            set(encoded, forKey: Keys.downloads)
            synchronize()
        } catch let error {
            logger.error("\(error)")
        }
    }
    
    func getDownloads() -> [NewDownloadModel]? {
        guard let savedData = data(forKey: Keys.downloads) else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode([NewDownloadModel].self, from: savedData)
        } catch let error {
            logger.error("\(error)")
            return nil
        }
    }
}
