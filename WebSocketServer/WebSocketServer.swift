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

class ClientSession {
    var session: WebSocketSession
    var lastPingTime: Date
    var lastPongTime: Date
    
    init(session: WebSocketSession) {
        self.session = session
        self.lastPingTime = Date()
        self.lastPongTime = Date()
    }
}

class WebSockerServer {
    
    static let instance = WebSockerServer()
    let server = HttpServer()
    
    var rpiClient: ClientSession?
    var iPhoneClient: ClientSession?
    var windowsClient: ClientSession?
    var screenCaptureClient: ClientSession?
    var statusSessions: [WebSocketSession] = []
    
    var connectedDevices: [String: Bool] = [
        "iPhone": false,
        "RPi": false,
        "Windows": false,
        "Script cursor_control": false,
        "Script screen_capture": false
    ]
    
    func updateWindowsStatus() {
        connectedDevices["Windows"] = connectedDevices["Script cursor_control"] == true || connectedDevices["Script screen_capture"] == true
    }
    
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
        // Embedded HTML content as a Swift string
        let embeddedHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Connected Devices</title>
            <style>
                body {
                    font-family: Arial, sans-serif;
                }
                .device-list {
                    list-style-type: none;
                    padding: 0;
                }
                .device-list li {
                    padding: 8px;
                    margin: 4px;
                    background-color: #f0f0f0;
                    border-radius: 4px;
                }
                .connected {
                    color: green;
                }
                .disconnected {
                    color: red;
                }
                .script-list {
                    list-style-type: none;
                    padding-left: 20px;
                }
            </style>
        </head>
        <body>
            <h1>Connected Devices</h1>
            <ul id="device-list" class="device-list"></ul>

            <script>
                const wsProtocol = window.location.protocol === 'https:' ? 'wss' : 'ws';
                const wsHost = window.location.host;
                const ws = new WebSocket(`${wsProtocol}://${wsHost}/status`);

                ws.onopen = () => {
                    console.log('Connected to the server');
                };

                ws.onmessage = (event) => {
                    const data = JSON.parse(event.data);
                    const deviceList = document.getElementById('device-list');
                    deviceList.innerHTML = '';

                    // Handle Windows separately
                    const windowsConnected = data['Windows'];
                    const windowsLi = document.createElement('li');
                    windowsLi.textContent = `Windows: ${windowsConnected ? 'Connected' : 'Disconnected'}`;
                    windowsLi.className = windowsConnected ? 'connected' : 'disconnected';

                    // Create a sublist for scripts under Windows
                    const scriptList = document.createElement('ul');
                    scriptList.className = 'script-list';

                    // Script cursor_control
                    const cursorControlConnected = data['Script cursor_control'];
                    const cursorLi = document.createElement('li');
                    cursorLi.textContent = `Script cursor_control: ${cursorControlConnected ? 'Connected' : 'Disconnected'}`;
                    cursorLi.className = cursorControlConnected ? 'connected' : 'disconnected';
                    scriptList.appendChild(cursorLi);

                    // Script screen_capture
                    const screenCaptureConnected = data['Script screen_capture'];
                    const screenLi = document.createElement('li');
                    screenLi.textContent = `Script screen_capture: ${screenCaptureConnected ? 'Connected' : 'Disconnected'}`;
                    screenLi.className = screenCaptureConnected ? 'connected' : 'disconnected';
                    scriptList.appendChild(screenLi);

                    // Append the script list under Windows
                    windowsLi.appendChild(scriptList);
                    deviceList.appendChild(windowsLi);

                    // Handle other devices (iPhone and RPi)
                    const otherDevices = ['iPhone', 'RPi'];
                    for (const device of otherDevices) {
                        const isConnected = data[device];
                        const li = document.createElement('li');
                        li.textContent = `${device}: ${isConnected ? 'Connected' : 'Disconnected'}`;
                        li.className = isConnected ? 'connected' : 'disconnected';
                        deviceList.appendChild(li);
                    }
                };

                ws.onclose = () => {
                    console.log('Disconnected from the server');
                };
            </script>
        </body>
        </html>

        """

        // Serve the embedded HTML content when accessing the root URL
        server["/"] = { request in
            return HttpResponse.ok(.html(embeddedHTML))
        }

        // Other routes remain the same (e.g., /status, /cursorData, etc.)

        do {
            try server.start(8080, forceIPv4: true)
            print("Server has started (port = \(try server.port())). Try to connect now...")
        } catch {
            print("Server failed to start: \(error.localizedDescription)")
        }
    }
    
    func startPingTimer() {
        let timer = DispatchSource.makeTimerSource()
        timer.schedule(deadline: .now(), repeating: 3.0)
        timer.setEventHandler { [weak self] in
            self?.pingDevices()
        }
        timer.resume()
    }
    
    func pingDevices() {
        if let cursorControlClient = self.windowsClient {
            cursorControlClient.session.writeText("ping")
            cursorControlClient.lastPingTime = Date()
            
            let timeSinceLastPong = Date().timeIntervalSince(cursorControlClient.lastPongTime)
            if timeSinceLastPong > 6.0 {
                connectedDevices["Script cursor_control"] = false
                self.windowsClient = nil
                updateWindowsStatus()
                sendStatusUpdate()
                print("Script cursor_control did not respond to ping. Marked as disconnected.")
            }
        } else {
            connectedDevices["Script cursor_control"] = false
        }
        
        // For Script screen_capture
        if let screenCaptureClient = self.screenCaptureClient {
            screenCaptureClient.session.writeText("ping")
            screenCaptureClient.lastPingTime = Date()
            
            let timeSinceLastPong = Date().timeIntervalSince(screenCaptureClient.lastPongTime)
            if timeSinceLastPong > 6.0 {
                connectedDevices["Script screen_capture"] = false
                self.screenCaptureClient = nil
                updateWindowsStatus()
                sendStatusUpdate()
                print("Script screen_capture did not respond to ping. Marked as disconnected.")
            }
        } else {
            connectedDevices["Script screen_capture"] = false
        }
        // For iPhone
        if let iPhoneClient = self.iPhoneClient {
            iPhoneClient.session.writeText("ping")
            iPhoneClient.lastPingTime = Date()
            
            let timeSinceLastPong = Date().timeIntervalSince(iPhoneClient.lastPongTime)
            if timeSinceLastPong > 6.0 {
                // Consider client disconnected
                connectedDevices["iPhone"] = false
                self.iPhoneClient = nil
                sendStatusUpdate()
                print("iPhone client did not respond to ping. Marked as disconnected.")
            }
        } else {
            connectedDevices["iPhone"] = false
        }
        
        // For Windows
        if let windowsClient = self.windowsClient {
            windowsClient.session.writeText("ping")
            windowsClient.lastPingTime = Date()
            
            let timeSinceLastPong = Date().timeIntervalSince(windowsClient.lastPongTime)
            if timeSinceLastPong > 6.0 {
                connectedDevices["Windows"] = false
                self.windowsClient = nil
                sendStatusUpdate()
                print("Windows client did not respond to ping. Marked as disconnected.")
            }
        } else {
            connectedDevices["Windows"] = false
        }
        
        // For RPi
        if let rpiClient = self.rpiClient {
            rpiClient.session.writeText("ping")
            rpiClient.lastPingTime = Date()
            
            let timeSinceLastPong = Date().timeIntervalSince(rpiClient.lastPongTime)
            if timeSinceLastPong > 6.0 {
                connectedDevices["RPi"] = false
                self.rpiClient = nil
                sendStatusUpdate()
                print("RPi client did not respond to ping. Marked as disconnected.")
            }
        } else {
            connectedDevices["RPi"] = false
        }
    }
    
    func sendStatusUpdate() {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: connectedDevices, options: [])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                for session in statusSessions {
                    session.writeText(jsonString)
                }
            }
        } catch {
            print("Error serializing connectedDevices to JSON: \(error)")
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
