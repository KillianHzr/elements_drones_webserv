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
        
//        Suppress tmp files
        
        self.currentPathArray = []
    }
    
    func saveImageDataArray(dataImageArray:[Data]) -> [String]{
        self.deleteCurrentPathArray()
        var savedImagePath = [String]()
        dataImageArray.enumerated().forEach { (index, element) in
            var currentImageName = "tmp_\(index).png"
            if FileHandler.saveImage(from: element, to: currentImageName) {
                self.currentPathArray.append(currentImageName)
            }else{
                print("Error saving images.")
            }
        }
        
        return self.currentPathArray
    }
    
}
