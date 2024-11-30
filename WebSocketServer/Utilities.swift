//
//  Utilities.swift
//  WebSocketServer
//
//  Created by digital on 23/10/2024.
//

import Foundation
import AppKit

class FileHandler {
    
    static func readTextFile(at path:String) -> String? {
        do {
            let fileContent = try String(contentsOfFile: path, encoding: .utf8)
            return fileContent
        } catch {
            print("Erreur lors de la lecture du fichier : \(error)")
            return nil
        }
    }
    
    static func saveImage(from imageData: Data, to filePath: String) -> Bool {
        
        // 2. Créer une image à partir des données (Supposons que les données soient dans un format d'image, ex: PNG, JPEG)
        guard let image = NSImage(data: imageData) else {
            print("Impossible de créer l'image à partir des données fournies.")
            return false
        }
        
        // 3. Convertir NSImage en format de fichier (par exemple, PNG)
        guard let tiffData = image.tiffRepresentation else {
            print("Impossible d'obtenir la représentation TIFF de l'image.")
            return false
        }
        
        // 4. Créer une représentation bitmap pour l'image
        guard let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            print("Impossible de créer une représentation bitmap.")
            return false
        }
        
        // 5. Obtenir les données PNG de la représentation bitmap
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            print("Impossible de convertir l'image en PNG.")
            return false
        }
        
        // 6. Sauvegarder les données PNG dans un fichier
        let fileURL = URL(fileURLWithPath: filePath)
        do {
            try pngData.write(to: fileURL)
            print("Image sauvegardée avec succès à : \(filePath)")
            return true
        } catch {
            print("Erreur lors de la sauvegarde de l'image : \(error)")
            return false
        }
    }
}
