// WebSocketServer.swift

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
    var dancePadClient: ClientSession?
    var dopamineClient: ClientSession?
    var statusSessions: [WebSocketSession] = []

    var connectedDevices: [String: Any] = [
        "iPhone": false,
        "RPi": false,
        "Windows": false,
        "Script cursor_control": false,
        "Script screen_capture": false,
        "Spheros": [],
        "DancePad": false,
        "DopamineESP": false // Ajout de DopamineESP
    ]
    
    func updateWindowsStatus() {
        connectedDevices["Windows"] = (connectedDevices["Script cursor_control"] as? Bool == true) || (connectedDevices["Script screen_capture"] as? Bool == true)
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
                    background: #141414;
                    color: white;
                }
                .device-list {
                    list-style-type: none;
                    padding: 0;
                }
                .device-list li {
                    padding: 8px;
                    margin: 4px;
                    background-color: #3b3b3b;
                    border-radius: 4px;
                }
                .connected {
                    color: #37f037;
                }
                .disconnected {
                    color: #ff3737;
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
        
                    // Handle DancePad
                    const dancePadConnected = data['DancePad'];
                    const dancePadLi = document.createElement('li');
                    dancePadLi.textContent = `DancePad: ${dancePadConnected ? 'Connected' : 'Disconnected'}`;
                    dancePadLi.className = dancePadConnected ? 'connected' : 'disconnected';
                    deviceList.appendChild(dancePadLi);

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

                    // Handle iPhone
                    const iPhoneConnected = data['iPhone'];
                    const iPhoneLi = document.createElement('li');
                    iPhoneLi.textContent = `iPhone: ${iPhoneConnected ? 'Connected' : 'Disconnected'}`;
                    iPhoneLi.className = iPhoneConnected ? 'connected' : 'disconnected';

                    // Add Spheros under iPhone
                    const spheroList = document.createElement('ul');
                    spheroList.className = 'script-list'; // Use a class for nested lists
                    const spheros = data['Spheros'];
                    if (spheros && spheros.length > 0) {
                        for (const spheroName of spheros) {
                            const spheroItem = document.createElement('li');
                            spheroItem.textContent = spheroName;
                            spheroItem.className = 'connected';
                            spheroList.appendChild(spheroItem);
                        }
                        iPhoneLi.appendChild(spheroList);
                    }
                    deviceList.appendChild(iPhoneLi);

                    // Handle RPi
                    const rpiConnected = data['RPi'];
                    const rpiLi = document.createElement('li');
                    rpiLi.textContent = `RPi: ${rpiConnected ? 'Connected' : 'Disconnected'}`;
                    rpiLi.className = rpiConnected ? 'connected' : 'disconnected';
                    deviceList.appendChild(rpiLi);

                    // Handle DopamineESP
                    const dopamineConnected = data['DopamineESP'];
                    const dopamineLi = document.createElement('li');
                    dopamineLi.textContent = `DopamineESP: ${dopamineConnected ? 'Connected' : 'Disconnected'}`;
                    dopamineLi.className = dopamineConnected ? 'connected' : 'disconnected';
                    deviceList.appendChild(dopamineLi);
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

        // Serve the status updates at /status
        server["/status"] = websocket(
            text: { session, text in
                // Vous pouvez gérer les messages spécifiques reçus sur /status si nécessaire
                // Pour l'instant, ce websocket est uniquement utilisé pour envoyer des mises à jour
            },
            binary: { session, binary in
                // Gestion des messages binaires si nécessaire
            },
            connected: { session in
                print("Client connected to /status")
                self.statusSessions.append(session)
            },
            disconnected: { session in
                print("Client disconnected from /status")
                if let index = self.statusSessions.firstIndex(where: { $0 === session }) {
                    self.statusSessions.remove(at: index)
                }
            }
        )

        // Configurez les autres routes ici (comme iPhoneConnect, dopamineConnect, etc.)
        configureRoutes()

        // Start the server
        do {
            try server.start(8080, forceIPv4: true)
            print("Server has started (port = \(try server.port())). Try to connect now...")
        } catch {
            print("Server failed to start: \(error.localizedDescription)")
        }
    }
    
    func configureRoutes() {
        // Route dopamineConnect
        setupWithRoutesInfos(routeInfos: RouteInfos(
            routeName: "dopamineConnect",
            textCode: { session, receivedText in
                print("DopamineESP a envoyé : \(receivedText)")
                
                // On parse le JSON reçu
                if let data = receivedText.data(using: .utf8),
                   let messageDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let action = messageDict["action"] as? String,
                   let state = messageDict["state"] as? String {
                    
                    if action == "dopamine" && state == "pressed" {
                        // Déclencher l'action pour vider la dopamine du Sphero actuel
                        // Envoyer un message à l'iPhone via iPhoneConnect
                        if let iphoneSession = self.iPhoneClient?.session {
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
                print("DopamineESP a envoyé des données binaires sur dopamineConnect")
            },
            connectedCode: { session in
                let clientSession = ClientSession(session: session)
                self.dopamineClient = clientSession
                self.connectedDevices["DopamineESP"] = true
                self.sendStatusUpdate()
                print("DopamineESP connecté")
            },
            disconnectedCode: { session in
                if self.dopamineClient?.session === session {
                    self.dopamineClient = nil
                    self.connectedDevices["DopamineESP"] = false
                    self.sendStatusUpdate()
                    print("DopamineESP déconnecté")
                }
            }
        ))

        // Route iPhoneConnect
        setupWithRoutesInfos(routeInfos: RouteInfos(
            routeName: "iPhoneConnect",
            textCode: { session, receivedText in
                // Traitement des pings
                if receivedText == "pong" {
                    if let client = self.iPhoneClient, client.session === session {
                        self.iPhoneClient?.lastPongTime = Date()
                        print("Received pong from iPhone")
                    }
                    return
                }

                // Traitement des autres messages
                print("iPhone received text message: \(receivedText)")
                if let data = receivedText.data(using: .utf8),
                   let messageDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let messageType = messageDict["type"] as? String {
                    
                    // Gestion du statut des Spheros
                    if messageType == "spheroStatus",
                       let connectedBolts = messageDict["connectedBolts"] as? [String] {
                        // Mise à jour de la liste des Spheros connectés
                        self.connectedDevices["Spheros"] = connectedBolts
                        self.sendStatusUpdate()
                        print("Mise à jour des Spheros connectés: \(connectedBolts)")
                    }
                    
                    // Gestion des commandes servo
                    if messageType == "servo",
                       let action = messageDict["action"] as? String,
                       action == "start" {
                        // Envoyer la commande servo à l'ESP32 via dopamineConnect
                        let servoMsg = ["action": "servo"]
                        if let jsonData = try? JSONSerialization.data(withJSONObject: servoMsg, options: []),
                           let jsonString = String(data: jsonData, encoding: .utf8) {
                            
                            if let espSession = self.dopamineClient?.session {
                                espSession.writeText(jsonString)
                                print("Commande servo envoyée à l'ESP32: \(jsonString)")
                            } else {
                                print("Erreur: DopamineESP n'est pas connecté.")
                            }
                        }
                    }
                }
            },
            dataCode: { session, receivedData in
                print("iPhone received data message: \(receivedData.count) bytes")
            },
            connectedCode: { session in
                let clientSession = ClientSession(session: session)
                self.iPhoneClient = clientSession
                self.connectedDevices["iPhone"] = true
                self.connectedDevices["Spheros"] = []
                self.sendStatusUpdate()
                print("iPhone connecté et session définie")
            },
            disconnectedCode: { session in
                if self.iPhoneClient?.session === session {
                    self.iPhoneClient = nil
                    self.connectedDevices["iPhone"] = false
                    // Réinitialisation de la liste des Spheros connectés
                    self.connectedDevices["Spheros"] = []
                    self.sendStatusUpdate()
                    print("iPhone déconnecté et session effacée")
                }
            }
        ))

        // Ajoutez ici d'autres routes si nécessaire (par exemple, /cursorData, /sendImage, /controlData, etc.)
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
        // Fonction de ping pour chaque client pour vérifier la connectivité
        // Ajoutez ici des pings pour DopamineESP si nécessaire
        if let dopamineClient = self.dopamineClient {
            dopamineClient.session.writeText("ping")
            dopamineClient.lastPingTime = Date()
            
            let timeSinceLastPong = Date().timeIntervalSince(dopamineClient.lastPongTime)
            if timeSinceLastPong > 6.0 {
                connectedDevices["DopamineESP"] = false
                self.dopamineClient = nil
                sendStatusUpdate()
                print("DopamineESP n'a pas répondu au ping. Marqué comme déconnecté.")
            }
        } else {
            connectedDevices["DopamineESP"] = false
        }

        // Continuez à ping les autres clients (iPhone, RPi, etc.) comme déjà implémenté
        // ...
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
