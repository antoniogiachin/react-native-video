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
    func downloadAndSave(
        from url: String?,
        in directory: String
    ) async -> String? {
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
            
            return save(image, in: directory)
        } catch {
            log(error: "Error downloading image: \(error)")
            return nil
        }
    }
    
    /// Saves given image to the user's document directory, returning its file path.
    func save(_ image: UIImage?, in directory: String) -> String? {
        guard let image else {
            // Nothing to save
            return nil
        }
        
        // Convert the image to JPEG data
        guard let data = image.resizedAndCompressed() else {
            log(error: "Unable to convert image to JPEG")
            return nil
        }
        
        // Create the file path
        let fileName = UUID().uuidString + ".jpg"
        
        return try? FileHelper.shared.save(
            data,
            in: directory,
            fileName: fileName
        )
    }
}

fileprivate extension UIImage {
    func resizedAndCompressed() -> Data? {
        resized(toWidth: 200)?.jpegData(compressionQuality: 0.5)
    }
    
    func resized(
        toWidth width: CGFloat,
        isOpaque: Bool = true
    ) -> UIImage? {
        let canvas = CGSize(
            width: width,
            height: CGFloat(ceil(width / size.width * size.height))
        )
        let format = imageRendererFormat
        format.opaque = isOpaque
        return UIGraphicsImageRenderer(size: canvas, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: canvas))
        }
    }
}
