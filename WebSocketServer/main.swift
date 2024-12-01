//
//  main.swift
//  WebSocketServer
//
//  Created by Al on 22/10/2024.
//

import Foundation
import Combine
import Swifter

var serverWS = WebSockerServer()
var cmd = TerminalCommandExecutor()
var cancellable: AnyCancellable? = nil

// Configuration des routes

// Route rpiConnect
serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(
    routeName: "rpiConnect",
    textCode: { session, receivedText in
        serverWS.rpiSession = session
        print("RPI Connecté")
    },
    dataCode: { session, receivedData in
        print("RPI received data: \(receivedData)")
    },
    connectedCode: { session in
        serverWS.rpiSession = session
        print("RPI connected and session set")
    },
    disconnectedCode: { session in
        if serverWS.rpiSession === session {
            serverWS.rpiSession = nil
            print("RPI disconnected and session cleared")
        }
    }
))

// Route iPhoneConnect
serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(
    routeName: "iPhoneConnect",
    textCode: { session, receivedText in
        // Gérer les messages textes si nécessaire
        print("iPhone received text message: \(receivedText)")
    },
    dataCode: { session, receivedData in
        // Gérer les messages binaires si nécessaire
        print("iPhone received data message: \(receivedData.count) bytes")
    },
    connectedCode: { session in
        serverWS.iPhoneSession = session
        print("iPhone connected and session set")
    },
    disconnectedCode: { session in
        if serverWS.iPhoneSession === session {
            serverWS.iPhoneSession = nil
            print("iPhone disconnected and session cleared")
        }
    }
))

// Route windowsConnect
serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(
    routeName: "windowsConnect",
    textCode: { session, receivedText in
        print("Windows text message received: \(receivedText)")
    },
    dataCode: { session, receivedData in
        print("Windows data message received")
    },
    connectedCode: { session in
        serverWS.windowsSession = session
        print("Windows connected and session set")
    },
    disconnectedCode: { session in
        if serverWS.windowsSession === session {
            serverWS.windowsSession = nil
            print("Windows disconnected and session cleared")
        }
    }
))

// Route cursorData
serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(
    routeName: "cursorData",
    textCode: { session, receivedText in
//        print("Données de curseur reçues : \(receivedText)")
        if let windowsSession = serverWS.windowsSession {
            windowsSession.writeText(receivedText)
//            print("Cursor data transmitted to Windows")
        }
    },
    dataCode: { session, receivedData in
        print("Données de curseur reçues")
    },
    connectedCode: { session in
        // Optionnel : Suivi de la session cursorData si nécessaire
        print("cursorData connected")
    },
    disconnectedCode: { session in
        // Optionnel : Gestion de la déconnexion cursorData si nécessaire
        print("cursorData disconnected")
    }
))

// Route videoFeed
serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(
    routeName: "videoFeed",
    textCode: { session, receivedText in
        if let iphoneSession = serverWS.iPhoneSession {
            iphoneSession.writeText(receivedText)
            print("Text data transmitted to iPhone via iPhoneSession")
        }
    },
    dataCode: { session, receivedData in
        print("Received video data from Windows, size: \(receivedData.count) bytes")
        if let iphoneSession = serverWS.iPhoneSession {
            // Convertir `Data` en `[UInt8]` pour `writeBinary`
            let binaryData = [UInt8](receivedData)
            iphoneSession.writeBinary(binaryData)
            print("Transmitted video data to iPhone")
        } else {
            print("iPhoneSession is nil, cannot transmit video data")
        }
    }
))	



serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "testRobot", textCode: { session, receivedText in
    if let rpiSess = serverWS.rpiSession {
        rpiSess.writeText("python3 drive.py")
    } else {
        print("RPI Non connecté")
    }
}, dataCode: { session, receivedData in
    print(receivedData)
}))


serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "moveRobot", textCode: { session, receivedText in
    if let rpiSess = serverWS.rpiSession {
        let components = receivedText.split(separator: " ")
        let command = components.first ?? ""
        
        var speed: String?
        for i in 0..<components.count {
            if components[i] == "--speed", i + 1 < components.count {
                speed = String(components[i + 1])
                break
            }
        }
        
        print("Mouvement du robot \(command) avec vitesse \(speed ?? "non spécifiée")")
        let commandToSend = "python3 \(command).py" + (speed != nil ? " --speed \(speed!)" : "")
        rpiSess.writeText(commandToSend)
        print("Mouvement du robot fini")
    } else {
        print("RPI Non connecté")
    }
}, dataCode: { session, receivedData in
    print(receivedData)
}))


serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "say", textCode: { session, receivedText in
    cmd.say(textToSay: receivedText)
}, dataCode: { session, receivedData in
    print(receivedData)
}))

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "imagePrompting", textCode: { session, receivedText in
    if let jsonData = receivedText.data(using: .utf8),
       let imagePrompting = try? JSONDecoder().decode(ImagePrompting.self, from: jsonData) {
        let dataImageArray = imagePrompting.toDataArray()
        let tmpImagesPath = TmpFileManager.instance.saveImageDataArray(dataImageArray: dataImageArray)
        
        if (tmpImagesPath.count == 1) {
            cmd.imagePrompting(imagePath: tmpImagesPath[0], prompt: imagePrompting.prompt)
        } else {
            print("You are sending too much images.")
        }
    }
}, dataCode: { session, receivedData in
}))

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "imagePromptingToText", textCode: { session, receivedText in
    
    cancellable?.cancel()
    cancellable = cmd.$output.sink { newValue in
        session.writeText(newValue)
    }
    
    if let jsonData = receivedText.data(using: .utf8),
       let imagePrompting = try? JSONDecoder().decode(ImagePrompting.self, from: jsonData) {
        let dataImageArray = imagePrompting.toDataArray()
        let tmpImagesPath = TmpFileManager.instance.saveImageDataArray(dataImageArray: dataImageArray)
        
        if (tmpImagesPath.count == 1) {
            cmd.imagePrompting(imagePath: tmpImagesPath[0], prompt: imagePrompting.prompt)
        } else {
            print("You are sending too much images.")
        }
    }
}, dataCode: { session, receivedData in
}))

// Route sendImage
serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(
    routeName: "sendImage",
    textCode: { session, receivedText in
        print("sendImage received text: \(receivedText)")
    },
    dataCode: { session, receivedData in
        print("sendImage received image data: \(receivedData.count) bytes")
        // Sauvegarder temporairement l'image
        let tempImagePath = TmpFileManager.instance.saveImageDataArray(dataImageArray: [receivedData]).first
        if let imagePath = tempImagePath {
            // Envoyer l'email avec l'image en pièce jointe
            WebSockerServer.instance.sendEmail(with: imagePath)
        } else {
            print("Erreur : Impossible de sauvegarder l'image reçue.")
        }
    },
    connectedCode: { session in
        print("sendImage connected")
    },
    disconnectedCode: { session in
        print("sendImage disconnected")
    }
))

serverWS.start()

RunLoop.main.run()

