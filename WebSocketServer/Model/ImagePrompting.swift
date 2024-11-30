//
//  ImagePrompting.swift
//  WebSocketClient
//
//  Created by digital on 23/10/2024.
//

import Foundation

struct ImagePrompting: Codable {
    let prompt: String
    let imagesBase64Data: [String]
    
    func toDataArray() -> [Data] {
        var imageDataArray = [Data]()
        
        for image in imagesBase64Data {
            if let imageData = Data(base64Encoded: image, options: .ignoreUnknownCharacters) {
                imageDataArray.append(imageData)
            }
        }
        
        return imageDataArray
    }
}
