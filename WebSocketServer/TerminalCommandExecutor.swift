//
//  TerminalCommandExecutor.swift
//  WebSocketServer
//
//  Created by Al on 22/10/2024.
//

import SwiftUI
import Combine

class TerminalCommandExecutor: ObservableObject {
    @Published var output: String = ""
    
    // Fonction pour exécuter la commande dans le terminal
    func executeCommand(_ command: String, callBack:@escaping (String)->()) {
        DispatchQueue.global().async {
            let task = Process()
            let pipe = Pipe()
            
            task.standardOutput = pipe
            task.standardError = pipe
            task.arguments = ["-c", command]
            task.launchPath = "/bin/zsh"
            
            do {
                try task.run()
            } catch {
                DispatchQueue.main.async {
                    self.output = "Erreur lors de l'exécution de la commande: \(error.localizedDescription)"
                }
                return
            }
            
            let outputHandle = pipe.fileHandleForReading
            let outputData = outputHandle.readDataToEndOfFile()
            let outputString = String(data: outputData, encoding: .utf8) ?? ""
            
            DispatchQueue.main.async {
                callBack(outputString)
            }
        }
    }
}


extension TerminalCommandExecutor {
    
    func say(textToSay:String) {
        self.executeCommand("say \(textToSay)") {cmdOutput in
            self.output = cmdOutput
        }
    }
    
    func imagePrompting(imagePath:String, prompt:String) {
        self.executeCommand("./llama-minicpmv-cli -m ggml-model-Q3_K_M.gguf --mmproj mmproj-model-f16.gguf --image \"./\(imagePath)\" -p \"\(prompt)\" > tmp.txt") { cmdOutput in
            if let content = FileHandler.readTextFile(at: "./tmp.txt") {
                self.output = content
            }
        }
        
    }
}
