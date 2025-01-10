//
//  main.swift
//  WebSocketServer
//
//  Created by Al on 22/10/2024.
//

import Foundation
import Combine

var serverWS = WebSockerServer()
var cmd = TerminalCommandExecutor()
var cancellable: AnyCancellable? = nil

var calinsNb = 0

// Configuration of routes

// Route rpiConnect
serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(
    routeName: "rpiConnect",
    textCode: { session, receivedText in
        if receivedText == "pong" {
            if let client = serverWS.rpiClient, client.session === session {
                serverWS.rpiClient?.lastPongTime = Date()
                print("Received pong from RPi")
            }
        }
        else if let data = receivedText.data(using: .utf8),
                let jsonDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                let messageType = jsonDict["type"] as? String,
                messageType == "calins"
        {
            // 🆕 Réception d'un nouveau "câlin" depuis le RPi
            calinsNb += 1
            print("Nouveau câlin reçu, calinsNb = \(calinsNb)")

            // Envoyer la valeur actuelle de calinsNb à l'iPhone
            if let iphoneSession = serverWS.iPhoneClient?.session {
                let msg: [String: Any] = [
                    "type": "calins",
                    "calinsNb": calinsNb
                ]
                if let jsonData = try? JSONSerialization.data(withJSONObject: msg, options: []),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    iphoneSession.writeText(jsonString)
                    print("Message calins envoyé à l'iPhone: \(jsonString)")
                }
            }

            // Si on atteint 3 câlins
            if calinsNb == 3 {
                print("tous les câlins ont été faits")
                serverWS.brainStages["Ecstasy"]?.finished = true
                serverWS.brainStages["Ecstasy"]?.started = false
                serverWS.sendStatusUpdate()
            }
        }
        else {
            // Handle other messages
            print("RPI received text message: \(receivedText)")
        }
    },
    dataCode: { session, receivedData in
        print("RPI received data: \(receivedData)")
    },
    connectedCode: { session in
        let clientSession = ClientSession(session: session)
        serverWS.rpiClient = clientSession
        serverWS.connectedDevices["RPi"] = true
        serverWS.sendStatusUpdate()
        print("RPi connected and session set")
    },
    disconnectedCode: { session in
        if serverWS.rpiClient?.session === session {
            serverWS.rpiClient = nil
            serverWS.connectedDevices["RPi"] = false
            serverWS.sendStatusUpdate()
            print("RPi disconnected and session cleared")
        }
    }
))

// Route iPhoneConnect
serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(
    routeName: "iPhoneConnect",
    textCode: { session, receivedText in
        if receivedText == "pong" {
            if let client = serverWS.iPhoneClient, client.session === session {
                serverWS.iPhoneClient?.lastPongTime = Date()
                print("Received pong from iPhone")
            }
        } else {
            // Traitement des messages autres que "pong"
            print("iPhone received text message: \(receivedText)")
            if let data = receivedText.data(using: .utf8),
               let messageDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let messageType = messageDict["type"] as? String {
                
                // Gestion du statut des Spheros
                if messageType == "spheroStatus",
                   let connectedBolts = messageDict["connectedBolts"] as? [String] {
                    // Mise à jour de la liste des Spheros connectés
                    serverWS.connectedDevices["Spheros"] = connectedBolts
                    serverWS.sendStatusUpdate()
                    print("Mise à jour des Spheros connectés: \(connectedBolts)")
                }
            }
        }
    },
    dataCode: { session, receivedData in
        print("iPhone received data message: \(receivedData.count) bytes")
    },
    connectedCode: { session in
        let clientSession = ClientSession(session: session)
        serverWS.iPhoneClient = clientSession
        serverWS.connectedDevices["iPhone"] = true
        // Réinitialisation de la liste des Spheros connectés
        serverWS.connectedDevices["Spheros"] = []
        serverWS.sendStatusUpdate()
        print("iPhone connecté et session définie")
    },
    disconnectedCode: { session in
        if serverWS.iPhoneClient?.session === session {
            serverWS.iPhoneClient = nil
            serverWS.connectedDevices["iPhone"] = false
            // Réinitialisation de la liste des Spheros connectés
            serverWS.connectedDevices["Spheros"] = []
            serverWS.sendStatusUpdate()
            print("iPhone déconnecté et session effacée")
        }
    }
))

// Route windowsConnect
serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(
    routeName: "windowsConnect",
    textCode: { session, receivedText in
        if receivedText == "pong" {
            if let client = serverWS.windowsClient, client.session === session {
                serverWS.windowsClient?.lastPongTime = Date()
                print("Received pong from Windows")
            }
        } else {
            // Handle other messages
            print("Windows text message received: \(receivedText)")
        }
    },
    dataCode: { session, receivedData in
        print("Windows data message received")
    },
    connectedCode: { session in
        let clientSession = ClientSession(session: session)
        serverWS.windowsClient = clientSession
        serverWS.connectedDevices["Script cursor_control"] = true
        serverWS.updateWindowsStatus()
        serverWS.sendStatusUpdate()
        print("Script cursor_control connected and session set")
    },
    disconnectedCode: { session in
        if serverWS.windowsClient?.session === session {
            serverWS.windowsClient = nil
            serverWS.connectedDevices["Script cursor_control"] = false
            serverWS.updateWindowsStatus()
            serverWS.sendStatusUpdate()
            print("Script cursor_control disconnected and session cleared")
        }
    }
))

// Route cursorData
serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(
    routeName: "cursorData",
    textCode: { session, receivedText in
        // Forward cursor data to Windows client
        if let windowsSession = serverWS.windowsClient?.session {
            windowsSession.writeText(receivedText)
        }
    },
    dataCode: { session, receivedData in
        print("Cursor data received")
    },
    connectedCode: { session in
        print("cursorData connected")
    },
    disconnectedCode: { session in
        print("cursorData disconnected")
    }
))

// Route videoFeed
serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(
    routeName: "videoFeed",
    textCode: { session, receivedText in
        if let iphoneSession = serverWS.iPhoneClient?.session {
            iphoneSession.writeText(receivedText)
            print("Text data transmitted to iPhone via iPhoneSession")
        }
    },
    dataCode: { session, receivedData in
        print("Received video data from Windows, size: \(receivedData.count) bytes")
        if let iphoneSession = serverWS.iPhoneClient?.session {
            let binaryData = [UInt8](receivedData)
            iphoneSession.writeBinary(binaryData)
            print("Transmitted video data to iPhone")
        } else {
            print("iPhoneSession is nil, cannot transmit video data")
        }
    },
    connectedCode: { session in
            let clientSession = ClientSession(session: session)
            serverWS.screenCaptureClient = clientSession
            serverWS.connectedDevices["Script screen_capture"] = true
            serverWS.updateWindowsStatus()
            serverWS.sendStatusUpdate()
            print("Script screen_capture connected and session set")
        },
        disconnectedCode: { session in
            if serverWS.screenCaptureClient?.session === session {
                serverWS.screenCaptureClient = nil
                serverWS.connectedDevices["Script screen_capture"] = false
                serverWS.updateWindowsStatus()
                serverWS.sendStatusUpdate()
                print("Script screen_capture disconnected and session cleared")
            }
        }
))

// Route testRobot
serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(
    routeName: "testRobot",
    textCode: { session, receivedText in
        if let rpiSession = serverWS.rpiClient?.session {
            rpiSession.writeText("python3 drive.py")
        } else {
            print("RPi not connected")
        }
    },
    dataCode: { session, receivedData in
        print(receivedData)
    }
))

// Route moveRobot
serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(
    routeName: "moveRobot",
    textCode: { session, receivedText in
        if let rpiSession = serverWS.rpiClient?.session {
            let components = receivedText.split(separator: " ")
            let command = components.first ?? ""
            
            var speed: String?
            for i in 0..<components.count {
                if components[i] == "--speed", i + 1 < components.count {
                    speed = String(components[i + 1])
                    break
                }
            }
            
            print("Moving robot \(command) with speed \(speed ?? "not specified")")
            let commandToSend = "python3 \(command).py" + (speed != nil ? " --speed \(speed!)" : "")
            rpiSession.writeText(commandToSend)
            print("Robot movement finished")
        } else {
            print("RPi not connected")
        }
    },
    dataCode: { session, receivedData in
        print(receivedData)
    }
))

// Route say
serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(
    routeName: "say",
    textCode: { session, receivedText in
        cmd.say(textToSay: receivedText)
    },
    dataCode: { session, receivedData in
        print(receivedData)
    }
))

// Route imagePrompting
serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(
    routeName: "imagePrompting",
    textCode: { session, receivedText in
        if let jsonData = receivedText.data(using: .utf8),
           let imagePrompting = try? JSONDecoder().decode(ImagePrompting.self, from: jsonData) {
            let dataImageArray = imagePrompting.toDataArray()
            let tmpImagesPath = TmpFileManager.instance.saveImageDataArray(dataImageArray: dataImageArray)
            
            if tmpImagesPath.count == 1 {
                cmd.imagePrompting(imagePath: tmpImagesPath[0], prompt: imagePrompting.prompt)
            } else {
                print("You are sending too many images.")
            }
        }
    },
    dataCode: { session, receivedData in
    }
))

// Route imagePromptingToText
serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(
    routeName: "imagePromptingToText",
    textCode: { session, receivedText in
        cancellable?.cancel()
        cancellable = cmd.$output.sink { newValue in
            session.writeText(newValue)
        }
        
        if let jsonData = receivedText.data(using: .utf8),
           let imagePrompting = try? JSONDecoder().decode(ImagePrompting.self, from: jsonData) {
            let dataImageArray = imagePrompting.toDataArray()
            let tmpImagesPath = TmpFileManager.instance.saveImageDataArray(dataImageArray: dataImageArray)
            
            if tmpImagesPath.count == 1 {
                cmd.imagePrompting(imagePath: tmpImagesPath[0], prompt: imagePrompting.prompt)
            } else {
                print("You are sending too many images.")
            }
        }
    },
    dataCode: { session, receivedData in
    }
))

// Route sendImage
serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(
    routeName: "sendImage",
    textCode: { session, receivedText in
        print("sendImage received text: \(receivedText)")
    },
    dataCode: { session, receivedData in
        print("sendImage received image data: \(receivedData.count) bytes")
        // Temporarily save the image
        let tempImagePath = TmpFileManager.instance.saveImageDataArray(dataImageArray: [receivedData]).first
        if let imagePath = tempImagePath {
            // Send the email with the image attachment
            WebSockerServer.instance.sendEmail(with: imagePath)
        } else {
            print("Error: Unable to save the received image.")
        }
    },
    connectedCode: { session in
        print("sendImage connected")
    },
    disconnectedCode: { session in
        print("sendImage disconnected")
    }
))

// Route controlData (iPhone to Mac)
serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(
    routeName: "controlData",
    textCode: { session, receivedText in
        print("Control data received from iPhone: \(receivedText)")
        if let rpiSession = serverWS.rpiClient?.session {
            rpiSession.writeText(receivedText)
            print("Control data transmitted to Raspberry Pi")
        } else {
            print("Raspberry Pi session not available")
        }
    },
    dataCode: { session, receivedData in
        print("Control data received in binary format")
    },
    connectedCode: { session in
        print("iPhone client connected to controlData route")
    },
    disconnectedCode: { session in
        print("iPhone client disconnected from controlData route")
    }
))

// Route status
serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(
    routeName: "status",
    textCode: { session, receivedText in
        // No need to handle received text for this route
    },
    dataCode: { session, receivedData in
        // No need to handle received data for this route
    },
    connectedCode: { session in
        // Add session to statusSessions
        serverWS.statusSessions.append(session)
        print("Client connected to /status route")
        // Send the current status immediately
        serverWS.sendStatusUpdate()
    },
    disconnectedCode: { session in
        // Remove session from statusSessions
        serverWS.statusSessions.removeAll { $0 === session }
        print("Client disconnected from /status route")
    }
))

// Route dancePadConnect
serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(
    routeName: "dancePadConnect",
    textCode: { session, receivedText in
        // Traiter les données reçues de l'ESP32
        print("DancePad a envoyé : \(receivedText)")

        // Parse le JSON {"button":1,"state":"pressed"} ou {"button":3,"state":"released"}, etc.
        if let data = receivedText.data(using: .utf8),
           let messageDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let buttonNumberValue = messageDict["button"],
           let state = messageDict["state"] as? String {
            // Convertir le buttonNumber en Int
            var buttonNumber: Int?
            if let number = buttonNumberValue as? NSNumber {
                buttonNumber = number.intValue
            } else if let numberString = buttonNumberValue as? String, let number = Int(numberString) {
                buttonNumber = number
            }

            if let buttonNumber = buttonNumber {
                // Correspondance entre numéro de bouton (1..4) et commande RPi
                let actionMap = [
                    1: "forward",
                    2: "backward",
                    3: "left",
                    4: "right"
                ]

                if let action = actionMap[buttonNumber] {
                    let isPressed = (state == "pressed")

                    // Envoyer les données au RPi uniquement si l'étape "Ecstasy" est en mode "started"
                    if let ecstasyStage = serverWS.brainStages["Ecstasy"], ecstasyStage.started {
                        let messageToSend: [String: Any] = [
                            "action": action,
                            "isPressed": isPressed
                        ]
                        if let jsonData = try? JSONSerialization.data(withJSONObject: messageToSend, options: []),
                           let jsonString = String(data: jsonData, encoding: .utf8) {

                            if let rpiSession = serverWS.rpiClient?.session {
                                rpiSession.writeText(jsonString)
                                print("Message envoyé au Raspberry Pi : \(jsonString)")
                            } else {
                                print("Raspberry Pi n'est pas connecté")
                            }
                        }
                    } else {
                        print("L'étape 'Ecstasy' n'est pas en mode 'started'. Données ignorées.")
                    }

                    // Gestion des données pour l'iPhone
                    if isPressed {
                        serverWS.activeDancePadButton = buttonNumber
                        print("DancePad bouton \(buttonNumber) pressé et défini comme actif")
                        serverWS.sendDancePadStateToIphone()
                    } else {
                        if serverWS.activeDancePadButton == buttonNumber {
                            serverWS.activeDancePadButton = nil
                            print("DancePad bouton \(buttonNumber) relâché et désactivé")

                            if let nextPressedButton = (1...4).first(where: { serverWS.dancePadButtons[$0] ?? false }) {
                                serverWS.activeDancePadButton = nextPressedButton
                                print("DancePad bouton \(nextPressedButton) défini comme actif")
                            }

                            serverWS.sendDancePadStateToIphone()
                        }
                    }
                } else {
                    print("Bouton inconnu : \(buttonNumber)")
                }
            } else {
                print("Impossible de lire le numéro de bouton")
            }
        } else {
            print("Format de message invalide")
        }
    },
    dataCode: { session, receivedData in
        print("DancePad a envoyé des données binaires (\(receivedData.count) bytes).")
    },
    connectedCode: { session in
        let clientSession = ClientSession(session: session)
        serverWS.dancePadClient = clientSession
        serverWS.connectedDevices["DancePad"] = true
        serverWS.sendStatusUpdate()
        print("DancePad connecté")
    },
    disconnectedCode: { session in
        if serverWS.dancePadClient?.session === session {
            serverWS.dancePadClient = nil
            serverWS.connectedDevices["DancePad"] = false
            serverWS.sendStatusUpdate()
            print("DancePad déconnecté")
        }
    }
))

// Route dopamineConnect
serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(
    routeName: "dopamineConnect",
    textCode: { session, receivedText in
        print("ESP a envoyé : \(receivedText)")
        
        // On parse le JSON reçu
        if let data = receivedText.data(using: .utf8),
           let messageDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let action = messageDict["action"] as? String,
           let state = messageDict["state"] as? String {
            
            if action == "dopamine" && state == "pressed" {
                // Ici, on déclenche l'action pour vider la dopamine du sphero actuel.
                // Comme votre code de pilotage est sur l'iPhone, il faut renvoyer un message à l'iPhone (via la route iPhoneConnect)
                // Par exemple, envoyer un message JSON: {"type": "dopamine", "command": "start"}
                
                if let iphoneSession = serverWS.iPhoneClient?.session {
                    let dopMsg = ["type": "dopamine", "command": "start"]
                    if let jsonData = try? JSONSerialization.data(withJSONObject: dopMsg, options: []),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        iphoneSession.writeText(jsonString)
                        print("Message dopamine envoyé à l'iPhone")
                    }
                }
            }
        }
    },
    dataCode: { session, receivedData in
        print("ESP a envoyé des données binaires sur dopamineConnect")
    },
    connectedCode: { session in
        let clientSession = ClientSession(session: session)
        serverWS.dopamineClient = clientSession
        serverWS.connectedDevices["DopamineESP"] = true
        serverWS.sendStatusUpdate()
        print("DopamineESP connecté")
    },
    disconnectedCode: { session in
        if serverWS.dopamineClient?.session === session {
            serverWS.dopamineClient = nil
            serverWS.connectedDevices["DopamineESP"] = false
            serverWS.sendStatusUpdate()
            print("DopamineESP déconnecté")
        }
    }
))

// Start the server
serverWS.start()

RunLoop.main.run()
