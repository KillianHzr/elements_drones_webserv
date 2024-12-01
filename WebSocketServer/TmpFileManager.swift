//
//  TmpFileManager.swift
//  WebSocketServer
//
//  Created by digital on 23/10/2024.
//

import Foundation

class TmpFileManager {
    
    static let instance = TmpFileManager()
    
    private var currentPathArray = [String]()
    
    private func deleteCurrentPathArray() {
        // Supprimer les fichiers temporaires si nécessaire
        self.currentPathArray = []
    }
    
    func saveImageDataArray(dataImageArray: [Data]) -> [String] {
        self.deleteCurrentPathArray()
        var savedImagePath = [String]()
        dataImageArray.enumerated().forEach { (index, element) in
            let currentImageName = "tmp_\(index).png"
            if FileHandler.saveImage(from: element, to: currentImageName) {
                self.currentPathArray.append(currentImageName)
                savedImagePath.append(currentImageName)
            } else {
                print("Erreur lors de la sauvegarde des images.")
            }
        }
        
        return self.currentPathArray
    }
}
