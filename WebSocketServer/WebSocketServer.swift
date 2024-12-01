//
//  WebSocketServer.swift
//  WebSocketServer
//
//  Created by digital on 22/10/2024.
//

import Swifter
import SwiftUI

struct RouteInfos {
    var routeName: String
    var textCode: (WebSocketSession, String) -> ()
    var dataCode: (WebSocketSession, Data) -> ()
    var connectedCode: ((WebSocketSession) -> ())? = nil
    var disconnectedCode: ((WebSocketSession) -> ())? = nil
}

class WebSockerServer {
    
    static let instance = WebSockerServer()
    let server = HttpServer()
    
    var rpiSession: WebSocketSession?
    var iPhoneSession: WebSocketSession?
    var windowsSession: WebSocketSession?
    
    func setupWithRoutesInfos(routeInfos: RouteInfos) {
        server["/" + routeInfos.routeName] = websocket(
            text: { session, text in
                routeInfos.textCode(session, text)
            },
            binary: { session, binary in
                routeInfos.dataCode(session, Data(binary))
            },
            connected: { session in
                print("Client connected to route: /\(routeInfos.routeName)")
                routeInfos.connectedCode?(session)
            },
            disconnected: { session in
                print("Client disconnected from route: /\(routeInfos.routeName)")
                routeInfos.disconnectedCode?(session)
            }
        )
    }
    
    func start() {
        do {
            try server.start()
            print("Server has started (port = \(try server.port())). Try to connect now...")
        } catch {
            print("Server failed to start: \(error.localizedDescription)")
        }
    }
    
    /// Fonction pour envoyer un email avec une image en pièce jointe
    func sendEmail(with imagePath: String) {
        // Obtenir le chemin absolu de l'image
        let fullPath = getDocumentsDirectory().appendingPathComponent(imagePath).path
        
        let script = """
        tell application "Mail"
            set newMessage to make new outgoing message with properties {subject:"Dessin Validé", content:"Voici le dessin validé.", visible:true}
            tell newMessage
                make new to recipient at end of to recipients with properties {address:"killianherzer@gmail.com"}
                make new attachment with properties {file name:(POSIX file "\(fullPath)")} at after the last paragraph
            end tell
            send newMessage
        end tell
        """
        
        let process = Process()
        process.launchPath = "/usr/bin/osascript"
        process.arguments = ["-e", script]
        
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                print("Email envoyé avec succès avec l'image \(fullPath).")
            } else {
                print("Erreur lors de l'envoi de l'email.")
            }
        } catch {
            print("Erreur lors de l'exécution du script AppleScript : \(error)")
        }
    }

    
    func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
