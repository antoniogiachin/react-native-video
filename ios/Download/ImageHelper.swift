//
//  ImageHelper.swift
//  react-native-video
//
//  Created by Davide Balistreri on 21/03/25.
//  Copyright © 2025 Rai - Radiotelevisione Italiana Spa. All rights reserved.
//

import UIKit

class ImageHelper: DownloadLogging {
    static var shared = ImageHelper()
    
    /// Downloads an image from the given URL and saves it to the user's document directory, returning its file path.
    func downloadAndSaveImage(url: String?) async -> String? {
        guard let url, let imageUrl = URL(string: url) else {
            log(verbose: "Invalid or missing image URL")
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: imageUrl)
            
            guard let image = UIImage(data: data) else {
                log(error: "Invalid image data")
                return nil
            }
            
            return saveImage(image: image)
        } catch {
            log(error: "Error downloading image: \(error)")
            return nil
        }
    }
    
    /// Saves given image to the user's document directory, returning its file path.
    func saveImage(image: UIImage?) -> String? {
        guard let image else {
            // Nothing to save
            return nil
        }
        
        // Get the user's document directory
        guard let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            log(error: "Unable to get documents directory")
            return nil
        }
        
        // Create the full file path
        let fileName = UUID().uuidString + ".jpg"
        let fileURL = documents.appendingPathComponent(fileName)
        
        // Convert the image to JPEG data
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            log(error: "Unable to convert image to JPEG")
            return nil
        }
        
        // Write the image data to the file
        do {
            try imageData.write(to: fileURL)
            return fileURL.path
        } catch {
            log(error: "Error writing file JPEG image data: \(error)")
            return nil
        }
    }
}
