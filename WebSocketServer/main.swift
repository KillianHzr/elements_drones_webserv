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
        } else {
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
            // Handle other messages
            print("iPhone received text message: \(receivedText)")
        }
    },
    dataCode: { session, receivedData in
        print("iPhone received data message: \(receivedData.count) bytes")
    },
    connectedCode: { session in
        let clientSession = ClientSession(session: session)
        serverWS.iPhoneClient = clientSession
        serverWS.connectedDevices["iPhone"] = true
        serverWS.sendStatusUpdate()
        print("iPhone connected and session set")
    },
    disconnectedCode: { session in
        if serverWS.iPhoneClient?.session === session {
            serverWS.iPhoneClient = nil
            serverWS.connectedDevices["iPhone"] = false
            serverWS.sendStatusUpdate()
            print("iPhone disconnected and session cleared")
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

// Start the server
serverWS.start()

RunLoop.main.run()
