//
//  Utilities.swift
//  WebSocketServer
//
//  Created by digital on 23/10/2024.
//

import Foundation
import AppKit

class FileHandler {
    
    static func readTextFile(at path: String) -> String? {
        do {
            let fileContent = try String(contentsOfFile: path, encoding: .utf8)
            return fileContent
        } catch {
            print("Erreur lors de la lecture du fichier : \(error)")
            return nil
        }
    }
    
    static func saveImage(from imageData: Data, to filePath: String) -> Bool {
        // Obtenir le chemin absolu
        let documentsDirectory = WebSockerServer.instance.getDocumentsDirectory()
        let fileURL = documentsDirectory.appendingPathComponent(filePath)
        
        // Créer une image à partir des données
        guard let image = NSImage(data: imageData) else {
            print("Impossible de créer l'image à partir des données fournies.")
            return false
        }
        
        // Convertir NSImage en format PNG
        guard let tiffData = image.tiffRepresentation else {
            print("Impossible d'obtenir la représentation TIFF de l'image.")
            return false
        }
        
        guard let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            print("Impossible de créer une représentation bitmap.")
            return false
        }
        
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            print("Impossible de convertir l'image en PNG.")
            return false
        }
        
        // Sauvegarder les données PNG dans un fichier
        do {
            try pngData.write(to: fileURL)
            print("Image sauvegardée avec succès à : \(fileURL.path)")
            return true
        } catch {
            print("Erreur lors de la sauvegarde de l'image : \(error)")
            return false
        }
    }
}
