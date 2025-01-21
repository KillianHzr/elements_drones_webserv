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

struct QteInfo {
    let qte: String
    let amusement: Int
    let badTrip: Int
    let maladieMentale: Int
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
    
    struct BrainStage {
        var name: String
        var started: Bool
        var finished: Bool
    }
    
    var brainStages: [String: BrainStage] = [
        "Synapse": BrainStage(name: "Synapse", started: false, finished: false),
        "LSD": BrainStage(name: "LSD", started: false, finished: false),
        "Ecstasy": BrainStage(name: "Ecstasy", started: false, finished: false),
        "Champi": BrainStage(name: "Champi", started: false, finished: false)
    ]
    
    var joystickState: [String: Int] = ["x": 0, "y": 0]
    var dancePadButtons: [Int: Bool] = [
        1: false,
        2: false,
        3: false,
        4: false
    ]
    
    struct DancePadButtonInfo {
        let titre: String
        let amusement: Int
        let badTrip: Int
        let maladieMentale: Int
    }

    var dancePadButtonProperties: [Int: DancePadButtonInfo] = [
        1: DancePadButtonInfo(titre: "nature", amusement: 3, badTrip: -2, maladieMentale: -1),
        2: DancePadButtonInfo(titre: "confortable", amusement: 2, badTrip: -1, maladieMentale: 0),
        3: DancePadButtonInfo(titre: "foule", amusement: 1, badTrip: 4, maladieMentale: 1),
        4: DancePadButtonInfo(titre: "rue", amusement: -2, badTrip: 6, maladieMentale: 2)
    ]
    
    var activeDancePadButton: Int? = nil

    struct BadgeInfo {
        let titre: String
        let amusement: Int
        let badTrip: Int
        let maladieMentale: Int
    }

    var badgeProperties: [Int: BadgeInfo] = [
        803109171:   BadgeInfo(titre: "Badge A - Partiels", amusement: -1, badTrip: 3,  maladieMentale: 2),
        798528483:   BadgeInfo(titre: "Badge B - Montée d'énergie incontrôlée", amusement: 3, badTrip: 3,  maladieMentale: 2),
        802109907:   BadgeInfo(titre: "Badge C - Sérénité intérieur", amusement: 4, badTrip: -2,  maladieMentale: -1),
        2886461267:  BadgeInfo(titre: "Badge D - Nouvelle promotion", amusement: 4, badTrip: 1,  maladieMentale: 0)
//        2887059987:  BadgeInfo(titre: "Badge E - Montée d'énergie incontrôlée", amusement: 3, badTrip: 3,  maladieMentale: 2)
    ]
    
    var rfidToObsSceneMap: [Int: String] = [
        803109171: "champi_soundtrack-partiels",
        798528483: "champi_soundtrack-energie",
        802109907: "champi_soundtrack-serenite",
        2886461267: "champi_soundtrack-promotion",
    ]
    
    // Variables pour gérer les pressions sur le DancePad
    var lastDancePadButtonPressed: Int? = nil
    var lastDancePadPressTime: Date? = nil
    var lastBuzzersPressed: Int = 0

    // Mapping des boutons DancePad vers les scènes OBS
    var dancePadToObsSceneMap: [Int: String] = [
        1: "champi_soundtrack-nature",
        2: "champi_soundtrack-party",
        3: "champi_soundtrack-festival",
        4: "champi_soundtrack-rue"
    ]
    
    var videoFeedSessions: [WebSocketSession] = []
    
    // Dernières valeurs reçues de la qte des buzzers
    var lastBuzzersAmusement: Int = 0
    var lastBuzzersBadTrip: Int = 0
    var lastBuzzersMaladieMentale: Int = 0

    // Dernières valeurs reçues du RFID
    var lastRfidAmusement: Int = 0
    var lastRfidBadTrip: Int = 0
    var lastRfidMaladieMentale: Int = 0

    // Dernières valeurs reçues du DancePad
    var lastDancePadAmusement: Int = 0
    var lastDancePadBadTrip: Int = 0
    var lastDancePadMaladieMentale: Int = 0

    var hasDispatchedDopamine: Bool = false
    
    var rpiClient: ClientSession?
    var iPhoneClient: ClientSession?
    var windowsClient: ClientSession?
    var screenCaptureClient: ClientSession?
    var dancePadClient: ClientSession?
    var dopamineClient: ClientSession?
    var controllerEspClient: ClientSession?
    var rfidEspClient: ClientSession?
    var buzzersEspClient: ClientSession?
    var jaugeEspClient: ClientSession?
    var statusSessions: [WebSocketSession] = []

    var connectedDevices: [String: Any] = [
        "iPhone": false,
        "RPi": false,
        "Windows": false,
        "Script cursor_control": false,
        "Script screen_capture": false,
        "Spheros": [],
        "DancePad": false,
        "DopamineESP": false,
        "ControllerESP": false,
        "RfidESP": false,
        "jaugeEsp": false,
        "BuzzersESP": false,
        "VideoFeed": false
    ]
    
    func handleOBSChangeScene(session: WebSocketSession, messageDict: [String: Any]) {
        if let action = messageDict["action"] as? String {
            switch action {
            case "changeScene":
                if let sceneName = messageDict["scene"] as? String {
                    print("Demande de changement de scène OBS en '\(sceneName)'")

                    // Vérifier la connexion à OBS et s'y connecter si nécessaire
                    if !OBSWebSocketClient.instance.isConnectedToOBS {
                        OBSWebSocketClient.instance.connectOBS(ip: "192.168.10.213", port: 4455)
                    }

                    // Changer la scène dans OBS
                    OBSWebSocketClient.instance.setScene(sceneName: sceneName) { success, comment in
                        print("Changement de scène terminé. success=\(success), comment=\(comment)")

                        // Préparer la réponse à envoyer au client WebSocket
                        let response: [String: Any] = [
                            "type": "obsResponse",
                            "scene": sceneName,
                            "success": success,
                            "comment": comment
                        ]

                        // Sérialiser et envoyer la réponse
                        if let respData = try? JSONSerialization.data(withJSONObject: response, options: []),
                           let respString = String(data: respData, encoding: .utf8) {
                            session.writeText(respString)
                        }
                    }
                } else {
                    print("Erreur : Nom de scène manquant dans le message JSON.")
                }
            default:
                print("Action OBS inconnue : \(action)")
            }
        } else {
            print("Erreur : Action manquante dans le message JSON.")
        }
    }
    
    func sendJoystickStateToIphone() {
        let joystickMsg: [String: Any] = [
            "type": "joystick",
            "x": joystickState["x"] ?? 0,
            "y": joystickState["y"] ?? 0
        ]

        if let iphoneSession = self.iPhoneClient?.session {
            if let jsonData = try? JSONSerialization.data(withJSONObject: joystickMsg, options: []),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                iphoneSession.writeText(jsonString)
                print("Joystick state sent to iPhone")
            }
        }
    }
    
    func checkSolution() {
        
        guard let champiStage = brainStages["Champi"], champiStage.started else {
            print("checkSolution() ignorée car l'étape 'Champi' n'est pas en cours.")
            return
        }
        
        
        
        // 1) On additionne les amusements
        let totalAmusement = lastBuzzersAmusement + lastRfidAmusement + lastDancePadAmusement
        let totalBadTrip = lastBuzzersBadTrip + lastRfidBadTrip + lastDancePadBadTrip
        let totalMaladie = lastBuzzersMaladieMentale + lastRfidMaladieMentale + lastDancePadMaladieMentale

        // 2) Vérifier les conditions
        let isGoodSolution = (totalAmusement > 10) && (totalBadTrip <= 0) && (totalMaladie <= 1)

        // 3) Construire le JSON pour l'iPhone
        let msg: [String: Any] = [
            "type": "solution",
            "amusement": totalAmusement,
            "badTrip": totalBadTrip,
            "maladieMentale": totalMaladie,
            "verdict": isGoodSolution ? "bonne" : "mauvaise"
        ]

        // 4) Envoyer à l’iPhone
        if let iphoneSession = self.iPhoneClient?.session,
           let jsonData = try? JSONSerialization.data(withJSONObject: msg, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            iphoneSession.writeText(jsonString)
            print("Solution sent to iPhone:", jsonString)
        }

        // 5) Déterminer les couleurs et préparer le message pour jaugeEsp
        let couleurChargement = "(255, 255, 255)"

        let amusementColor = totalAmusement > 10 ? "(0, 255, 0)" : "(255, 0, 0)"
        let badTripColor = totalBadTrip <= 0 ? "(0, 255, 0)" : "(255, 0, 0)"
        let maladieColor = totalMaladie <= 1 ? "(0, 255, 0)" : "(255, 0, 0)"

        let jaugeMsg: [String: Any] = [
            "couleurChargement": couleurChargement,
            "amusement": [
                "couleur": amusementColor,
                "nombreLeds": totalAmusement
            ],
            "badTrip": [
                "couleur": badTripColor,
                "nombreLeds": totalBadTrip
            ],
            "maladie": [
                "couleur": maladieColor,
                "nombreLeds": totalMaladie
            ]
        ]
        
        // 5.1) Envoyer le message "confirmSoluce" à buzzersEsp
        if let buzzersSession = self.buzzersEspClient?.session {
            let confirmMessage: [String: Any] = [
                "type": "confirmSoluce"
            ]
            if let jsonData = try? JSONSerialization.data(withJSONObject: confirmMessage, options: []),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                buzzersSession.writeText(jsonString)
                print("confirmSoluce message sent to buzzersEsp:", jsonString)
            }
        } else {
            print("buzzersEsp non connecté. Le message confirmSoluce n'a pas été envoyé.")
        }

        // 5.2) Envoyer le message "confirmSoluce" à dancePad
        if let dancePadSession = self.dancePadClient?.session {
            let confirmMessage: [String: Any] = [
                "type": "confirmSoluce"
            ]
            if let jsonData = try? JSONSerialization.data(withJSONObject: confirmMessage, options: []),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                dancePadSession.writeText(jsonString)
                print("confirmSoluce message sent to dancePad:", jsonString)
            }
        } else {
            print("dancePad non connecté. Le message confirmSoluce n'a pas été envoyé.")
        }
        
        // 5.3) Envoyer le message "confirmSoluce" à Rfid
        if let rfidSession = self.rfidEspClient?.session {
            let confirmMessage: [String: Any] = [
                "type": "confirmSoluce"
            ]
            if let jsonData = try? JSONSerialization.data(withJSONObject: confirmMessage, options: []),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                rfidSession.writeText(jsonString)
                print("confirmSoluce message sent to Rfid:", jsonString)
            }
        } else {
            print("Rfid non connecté. Le message confirmSoluce n'a pas été envoyé.")
        }

        // 6) Envoyer le message à jaugeEsp si connecté
        if let jaugeSession = self.jaugeEspClient?.session {
            if let jaugeData = try? JSONSerialization.data(withJSONObject: jaugeMsg, options: []),
               let jaugeString = String(data: jaugeData, encoding: .utf8) {
                jaugeSession.writeText(jaugeString)
                print("Message envoyé à jaugeEsp:", jaugeString)
            } else {
                print("Erreur lors de la sérialisation du message pour jaugeEsp.")
            }
        } else {
            print("Client jaugeEsp non connecté. Message non envoyé.")
        }
        
        if !OBSWebSocketClient.instance.isConnectedToOBS {
            OBSWebSocketClient.instance.connectOBS(ip: "192.168.10.213", port: 4455)
        }
        OBSWebSocketClient.instance.setScene(sceneName: "champi_soundtrack-checksoluce") { success, comment in
            if success {
                print("OBS scene changed to 'champi_soundtrack-checksoluce' successfully.")
            } else {
                print("Failed to change OBS scene: \(comment)")
            }
        }
        
        if isGoodSolution {
            DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
                serverWS.brainStages["Champi"]?.finished = true
                serverWS.brainStages["Champi"]?.started = false
                serverWS.sendStatusUpdate()
            }
        }
    }
    
    func sendSendDopamineToBuzzers() {
        let dopamineMessage: [String: Any] = [
            "type": "sendDopamine"
        ]
        
        if let buzzersSession = self.buzzersEspClient?.session {
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: dopamineMessage, options: [])
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    buzzersSession.writeText(jsonString)
                    print("Message 'sendDopamine' envoyé à buzzersEsp: \(jsonString)")
                }
            } catch {
                print("Erreur lors de la sérialisation du message '0 ': \(error)")
            }
        } else {
            print("buzzersEsp non connecté. Le message 'sendDopamine' n'a pas été envoyé.")
        }
    }
    
    func sendFinishDopamineToBuzzers() {
        let dopamineMessage: [String: Any] = [
            "type": "finishDopamine"
        ]
        
        if let buzzersSession = self.buzzersEspClient?.session {
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: dopamineMessage, options: [])
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    buzzersSession.writeText(jsonString)
                    print("Message 'finishDopamine' envoyé à buzzersEsp: \(jsonString)")
                }
            } catch {
                print("Erreur lors de la sérialisation du message '0 ': \(error)")
            }
        } else {
            print("buzzersEsp non connecté. Le message 'finishDopamine' n'a pas été envoyé.")
        }
    }
    
    func sendBuzzersStateToIphone(pressed: Int, total: Int) {
        let qteInfo: QteInfo
        
        switch pressed {
        case 1, 2:
            qteInfo = QteInfo(qte: "qte bas", amusement: 2, badTrip: -2, maladieMentale: 0)
        case 3:
            qteInfo = QteInfo(qte: "qte neutre", amusement: 5, badTrip: 3, maladieMentale: 1)
        case 4, 5:
            qteInfo = QteInfo(qte: "qte haut", amusement: 7, badTrip: 7, maladieMentale: 3)
        default:
            qteInfo = QteInfo(qte: "qte bas", amusement: 2, badTrip: -2, maladieMentale: 0)
        }
        
        self.lastBuzzersAmusement = qteInfo.amusement
        self.lastBuzzersBadTrip = qteInfo.badTrip
        self.lastBuzzersMaladieMentale = qteInfo.maladieMentale
        
        let msg: [String: Any] = [
            "type": "buzzers",
            "buzzersPressed": pressed,
            "buzzersTotal": total,
            "qte": qteInfo.qte,
            "amusement": qteInfo.amusement,
            "badTrip": qteInfo.badTrip,
            "maladieMentale": qteInfo.maladieMentale
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: msg, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8),
           let iphoneSession = self.iPhoneClient?.session {
            iphoneSession.writeText(jsonString)
            print("Buzzers state sent to iPhone:", jsonString)
        }
    }

    func sendRfidDataToIphone(cardId: Int) {
        // Chercher si on a des infos pour ce badge dans le dictionnaire
        if let badgeInfo = badgeProperties[cardId] {
            self.lastRfidAmusement = badgeInfo.amusement
            self.lastRfidBadTrip = badgeInfo.badTrip
            self.lastRfidMaladieMentale = badgeInfo.maladieMentale
            
            // Créer un JSON complet => ex: {"type":"rfid","cardId":12345,"titre":"Période d'examen","amusement":-1,"badTrip":3,"maladieMentale":2}
            let msg: [String: Any] = [
                "type": "rfid",
                "cardId": cardId,
                "titre": badgeInfo.titre,
                "amusement": badgeInfo.amusement,
                "badTrip": badgeInfo.badTrip,
                "maladieMentale": badgeInfo.maladieMentale
            ]

            if let jsonData = try? JSONSerialization.data(withJSONObject: msg, options: []),
               let jsonString = String(data: jsonData, encoding: .utf8),
               let iphoneSession = self.iPhoneClient?.session {
                iphoneSession.writeText(jsonString)
                print("RFID data (avec propriétés) envoyé à l'iPhone: \(jsonString)")
                changeObsScene(for: cardId)
            } else {
                print("iPhone pas connecté, ou erreur JSON")
            }
        } else {
            // Si on ne trouve pas d'info => n'envoyer que l'ID
            let msg: [String: Any] = [
                "type": "rfid",
                "cardId": cardId
            ]
            if let jsonData = try? JSONSerialization.data(withJSONObject: msg, options: []),
               let jsonString = String(data: jsonData, encoding: .utf8),
               let iphoneSession = self.iPhoneClient?.session {
                iphoneSession.writeText(jsonString)
                print("RFID data (SANS propriétés) envoyé à l'iPhone: \(jsonString)")
            }
        }
    }
    
    func changeObsScene(for cardId: Int) {
        // Récupérer le nom de la scène à partir du mapping
        guard let sceneName = rfidToObsSceneMap[cardId] else {
            print("Aucune scène OBS définie pour cardId: \(cardId)")
            return
        }
        
        print("Changement de la scène OBS vers '\(sceneName)' pour cardId: \(cardId)")
        
        
        if !OBSWebSocketClient.instance.isConnectedToOBS {
            OBSWebSocketClient.instance.connectOBS(ip: "192.168.10.213", port: 4455)
        }
        
        setObsScene(sceneName: sceneName)
    }

    func setObsScene(sceneName: String) {
        OBSWebSocketClient.instance.setScene(sceneName: sceneName) { success, comment in
            if success {
                print("Scène OBS changée avec succès vers '\(sceneName)'.")
            } else {
                print("Échec du changement de scène OBS: \(comment)")
            }
        }
    }

    
    func sendDancePadStateToIphone() {
        if let activeButton = self.activeDancePadButton,
           let buttonInfo = self.dancePadButtonProperties[activeButton] {
            print(activeButton)
            self.lastDancePadAmusement = buttonInfo.amusement
            self.lastDancePadBadTrip = buttonInfo.badTrip
            self.lastDancePadMaladieMentale = buttonInfo.maladieMentale
            
            let msg: [String: Any] = [
                "type": "dancePad",
                "button": [
                    "titre": buttonInfo.titre,
                    "amusement": buttonInfo.amusement,
                    "badTrip": buttonInfo.badTrip,
                    "maladieMentale": buttonInfo.maladieMentale
                ]
            ]

            if let jsonData = try? JSONSerialization.data(withJSONObject: msg, options: []),
               let jsonString = String(data: jsonData, encoding: .utf8),
               let iphoneSession = self.iPhoneClient?.session {
                iphoneSession.writeText(jsonString)
                print("DancePad state sent to iPhone: \(jsonString)")
            } else {
                print("DancePad state envoyé à l'iPhone: aucun bouton actif")
            }
        } else {
            // Aucun bouton actif, envoyer un état vide ou spécifique
            let msg: [String: Any] = [
                "type": "dancePad",
                "button": NSNull()
            ]
            if let jsonData = try? JSONSerialization.data(withJSONObject: msg, options: []),
               let jsonString = String(data: jsonData, encoding: .utf8),
               let iphoneSession = self.iPhoneClient?.session {
                iphoneSession.writeText(jsonString)
                print("DancePad state envoyé à l'iPhone: aucun bouton actif")
            }
        }
    }
    
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
        // Updated embeddedHTML in WebSocketServer.swift
        
        let videoFeedHTML = """
            <!DOCTYPE html>
            <html lang="en">
            <head>
                <meta charset="UTF-8">
                <title>Flux Vidéo</title>
                <style>
                    body { 
                        background-color: #141414; 
                        color: white; 
                        display: flex; 
                        justify-content: center; 
                        align-items: center; 
                        height: 100vh; 
                        margin: 0;
                    }
                    #video-container {
                        width: 95%;
                        height: 95%;
                        border: 2px solid #37f037;
                        padding: 10px;
                        background-color: #1e1e1e;
                        border-radius: 8px;
                    }
                    #video {
                        width: 100%;
                        height: auto;
                        display: block;
                    }
                    #status {
                        margin-top: 10px;
                        text-align: center;
                        font-size: 1.2em;
                        color: #37f037;
                    }
                </style>
            </head>
            <body>
                <div id="video-container">
                    <img id="video" src="" alt="Flux Vidéo">
                    <div id="status">Connexion au flux vidéo...</div>
                </div>
                <script>
                    const wsProtocol = window.location.protocol === 'https:' ? 'wss' : 'ws';
                    const wsHost = window.location.host;
                    const ws = new WebSocket(`${wsProtocol}://${wsHost}/videoFeed`);

                    ws.binaryType = 'arraybuffer';

                    ws.onopen = () => {
                        console.log('Connecté au flux vidéo WebSocket');
                        document.getElementById('status').textContent = 'Connecté au flux vidéo';
                    };

                    ws.onmessage = (event) => {
                        if (typeof event.data === 'string') {
                            // Gérer les données textuelles si nécessaire
                            console.log('Données textuelles reçues:', event.data);
                        } else {
                            // Supposer que les données binaires sont des images JPEG
                            const blob = new Blob([event.data], { type: 'image/jpeg' });
                            const url = URL.createObjectURL(blob);
                            const img = document.getElementById('video');
                            img.src = url;

                            // Libérer l'URL de l'objet après le chargement de l'image
                            img.onload = () => {
                                URL.revokeObjectURL(url);
                            };
                        }
                    };

                    ws.onclose = () => {
                        console.log('Déconnecté du flux vidéo WebSocket');
                        document.getElementById('status').textContent = 'Déconnecté du flux vidéo';
                    };

                    ws.onerror = (error) => {
                        console.error('Erreur WebSocket:', error);
                        document.getElementById('status').textContent = 'Erreur de connexion au flux vidéo';
                    };
                </script>
            </body>
            </html>
            """

        let embeddedHTML = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Connected Devices</title>
            <style>
                body {
                    font-family: Arial, sans-serif;
                    background: #141414;
                    color: white;
                    display: flex;
                }
                section {
                    padding: 20px;
                    width: 65%;
                }
                .section2 {
                    width: 35%;
                }
                h1, h2 {
                    color: #37f037;
                }
                table {
                    width: 100%;
                    border-collapse: collapse;
                    margin-bottom: 20px;
                }
                th, td {
                    padding: 10px;
                    text-align: left;
                    border: 1px solid #3b3b3b;
                }
                th {
                    background-color: #333;
                }
                .connected {
                    color: #37f037;
                }
                .disconnected {
                    color: #ff3737;
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
                .sub-list {
                    list-style-type: none;
                    padding-left: 20px;
                }
                button {
                    margin: 5px;
                    padding: 5px 10px;
                    border: none;
                    border-radius: 3px;
                    cursor: pointer;
                    background-color: #555;
                    color: white;
                }
                button:hover {
                    background-color: #777;
                }
                label {
                    display: inline-block;
                    margin-right: 15px;
                }
                input[type="number"] {
                    width: 60px;
                }
            </style>
        </head>
        <body>
            <section>
                <h1>Connected Devices</h1>
                <ul id="device-list" class="device-list"></ul>

                <!-- Nouveau bloc : 3 inputs + bouton -->
                <h2>Test checkSoluce</h2>
                <div>
                    <label>Amusement: 
                        <input type="number" id="amusementInput" value="0">
                    </label>
                    <label>BadTrip: 
                        <input type="number" id="badTripInput" value="0">
                    </label>
                    <label>Maladie Mentale: 
                        <input type="number" id="maladieInput" value="0">
                    </label>
                    <button id="checkSoluceBtn">Check Soluce</button>
                </div>
            </section>
            
            <section class="section2">
                <h2>Brain Stages</h2>
                <table id="brain-stages-table" border="1">
                    <thead>
                        <tr>
                            <th>Stage</th>
                            <th>Started</th>
                            <th>Finished</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody></tbody>
                </table>
            </section>

            <script>
                const wsProtocol = window.location.protocol === 'https:' ? 'wss' : 'ws';
                const wsHost = window.location.host;
                // Concaténation classique pour éviter les backticks
                const ws = new WebSocket(wsProtocol + "://" + wsHost + "/status");

                ws.onopen = () => {
                    console.log('Connected to the server');
                };

                ws.onmessage = (event) => {
                    const data = JSON.parse(event.data);

                    // --- MÀJ de la liste des devices ---
                    const deviceList = document.getElementById('device-list');
                    deviceList.innerHTML = '';

                    const appendDevice = (name, isConnected) => {
                        const li = document.createElement('li');
                        li.textContent = name + ': ' + (isConnected ? 'Connected' : 'Disconnected');
                        li.className = isConnected ? 'connected' : 'disconnected';
                        deviceList.appendChild(li);
                        return li;
                    };

                    // iPhone + Spheros
                    const iPhoneLi = appendDevice('iPhone', data['iPhone']);
                    if (data['Spheros'] && Array.isArray(data['Spheros']) && data['Spheros'].length > 0) {
                        const spheroList = document.createElement('ul');
                        spheroList.className = 'sub-list';

                        for (const spheroName of data['Spheros']) {
                            const spheroItem = document.createElement('li');
                            spheroItem.textContent = 'Sphero: ' + spheroName;
                            spheroItem.className = 'connected';
                            spheroList.appendChild(spheroItem);
                        }
                        iPhoneLi.appendChild(spheroList);
                    }

                    // Autres devices
                    appendDevice('RPi', data['RPi']);
                    appendDevice('Windows', data['Windows']);
                    appendDevice('DancePad', data['DancePad']);
                    appendDevice('DopamineESP', data['DopamineESP']);
                    appendDevice('ControllerESP', data['ControllerESP']);
                    appendDevice('RfidESP', data['RfidESP']);
                    appendDevice('BuzzersESP', data['BuzzersESP']);
                    appendDevice('jaugeEsp', data['jaugeEsp']);

                    // Scripts sous Windows
                    const windowsLi = appendDevice('Windows', data['Windows']);
                    const scriptList = document.createElement('ul');
                    scriptList.className = 'sub-list';

                    const cursorControlConnected = data['Script cursor_control'];
                    const cursorLi = document.createElement('li');
                    cursorLi.textContent = 'Script cursor_control: ' + (cursorControlConnected ? 'Connected' : 'Disconnected');
                    cursorLi.className = cursorControlConnected ? 'connected' : 'disconnected';
                    scriptList.appendChild(cursorLi);

                    const screenCaptureConnected = data['Script screen_capture'];
                    const screenLi = document.createElement('li');
                    screenLi.textContent = 'Script screen_capture: ' + (screenCaptureConnected ? 'Connected' : 'Disconnected');
                    screenLi.className = screenCaptureConnected ? 'connected' : 'disconnected';
                    scriptList.appendChild(screenLi);

                    windowsLi.appendChild(scriptList);

                    // --- MÀJ du tableau Brain Stages ---
                    const brainStagesTable = document.getElementById('brain-stages-table').getElementsByTagName('tbody')[0];
                    brainStagesTable.innerHTML = '';

                    if (data['brainStages']) {
                        for (const [stageName, stageData] of Object.entries(data['brainStages'])) {
                            const row = brainStagesTable.insertRow();
                            row.insertCell(0).textContent = stageName;
                            row.insertCell(1).textContent = stageData.started ? 'Yes' : 'No';
                            row.insertCell(2).textContent = stageData.finished ? 'Yes' : 'No';

                            const actionsCell = row.insertCell(3);
                            const startBtn = document.createElement('button');
                            startBtn.textContent = 'Start';
                            startBtn.onclick = () => updateBrainStage(stageName, 'start');

                            const finishBtn = document.createElement('button');
                            finishBtn.textContent = 'Finish';
                            finishBtn.onclick = () => updateBrainStage(stageName, 'finish');

                            const resetStartedBtn = document.createElement('button');
                            resetStartedBtn.textContent = 'Reset Started';
                            resetStartedBtn.onclick = () => resetBrainStage(stageName, 'started');

                            const resetFinishedBtn = document.createElement('button');
                            resetFinishedBtn.textContent = 'Reset Finished';
                            resetFinishedBtn.onclick = () => resetBrainStage(stageName, 'finished');

                            actionsCell.appendChild(startBtn);
                            actionsCell.appendChild(finishBtn);
                            actionsCell.appendChild(resetStartedBtn);
                            actionsCell.appendChild(resetFinishedBtn);
                        }
                    }
                };

                ws.onclose = () => {
                    console.log('Disconnected from the server');
                };

                // Envoi de commandes d'update / reset
                function updateBrainStage(stage, action) {
                    const msg = {
                        type: 'updateStage',
                        stage: stage,
                        action: action
                    };
                    ws.send(JSON.stringify(msg));
                    console.log('Sent update command for ' + action + ' of ' + stage);
                }

                function resetBrainStage(stage, state) {
                    const msg = {
                        type: 'resetStage',
                        stage: stage,
                        state: state
                    };
                    ws.send(JSON.stringify(msg));
                    console.log('Sent reset command for ' + state + ' of ' + stage);
                }

                // Au clic du bouton "Check Soluce", on envoie nos 3 valeurs
                document.getElementById('checkSoluceBtn').addEventListener('click', () => {
                    const amusement = parseInt(document.getElementById('amusementInput').value);
                    const badTrip = parseInt(document.getElementById('badTripInput').value);
                    const maladie = parseInt(document.getElementById('maladieInput').value);

                    const msg = {
                        type: "calcSolution",
                        amusement: amusement,
                        badTrip: badTrip,
                        maladieMentale: maladie
                    };

                    ws.send(JSON.stringify(msg));
                    console.log("Envoi du message calcSolution avec ", msg);
                });
            </script>
        </body>
        </html>
        """

        // Serve the embedded HTML content when accessing the root URL
        server["/"] = { request in
            return HttpResponse.ok(.html(embeddedHTML))
        }
        
        server["/videoFeedPage"] = { request in
            return HttpResponse.ok(.html(videoFeedHTML))
        }

        // Serve the status updates at /status
        server["/status"] = websocket(
            text: { session, text in
                if let data = text.data(using: .utf8),
                   let messageDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let type = messageDict["type"] as? String {
                    
                    if type == "calcSolution" {
                        let customAmusement = messageDict["amusement"] as? Int ?? 0
                        let customBadTrip = messageDict["badTrip"] as? Int ?? 0
                        let customMaladie = messageDict["maladieMentale"] as? Int ?? 0
                        self.lastBuzzersAmusement = customAmusement
                        self.lastBuzzersBadTrip   = customBadTrip
                        self.lastBuzzersMaladieMentale = customMaladie

                        print("Reçu calcSolution => amusement=\(customAmusement), badTrip=\(customBadTrip), maladie=\(customMaladie)")
                        
                        self.checkSolution()
                    }
                        
                    
                    if type == "resetStage",
                       let stage = messageDict["stage"] as? String,
                       let state = messageDict["state"] as? String {
                        
                        if var brainStage = self.brainStages[stage] {
                            if state == "started" {
                                brainStage.started = false
                            } else if state == "finished" {
                                brainStage.finished = false
                            }
                            self.brainStages[stage] = brainStage
                            self.sendStatusUpdate()
                            print("\(state.capitalized) state of \(stage) reset to false")
                        } else {
                            print("Unknown stage: \(stage)")
                        }
                    }
                    
                    // Handle updateStage messages
                    if type == "updateStage",
                       let stage = messageDict["stage"] as? String,
                       let action = messageDict["action"] as? String {
                        
                        if var brainStage = self.brainStages[stage] {
                            switch action {
                            case "start":
                                brainStage.started = true
                                brainStage.finished = false
                                print("Stage \(stage) forcée à commencer")
                                
                                if stage.lowercased() == "synapse" {
                                    self.sendSendDopamineToBuzzers()
                                    print("Dopamine envoyée à l'esp buzzers")
                                }
                            case "finish":
                                brainStage.started = false
                                brainStage.finished = true
                                print("Stage \(stage) forcée à terminer")
                                
                                if stage.lowercased() == "synapse" {
                                    self.sendFinishDopamineToBuzzers()
                                    print("FinishDopamine envoyée à l'esp buzzers")
                                }
                            default:
                                print("Action inconnue pour l'étape \(stage): \(action)")
                            }
                            self.brainStages[stage] = brainStage
                            self.sendStatusUpdate()
                        } else {
                            print("Étape \(stage) inconnue pour updateStage")
                        }
                    }
                }
            },
            binary: { session, binary in
                // Handle binary data if necessary
            },
            connected: { session in
                print("Client connected to /status")
                self.statusSessions.append(session)
                self.sendStatusUpdate()
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

                    switch messageType {
                    case "calcSolution":
                        // Aucune data reçue, on fait tout côté serveur
                        self.checkSolution()
                        
                    case "calcSolution":
                        // Aucune data reçue, on fait tout côté serveur
                        self.checkSolution()

//                    case "joystick":
//                        if let x = messageDict["x"] as? Int,
//                           let y = messageDict["y"] as? Int {
//                            // Mise à jour de l'état du joystick
//                            self.joystickState["x"] = x
//                            self.joystickState["y"] = y
//                            // Envoi de l'état mis à jour au client iPhone
//                            self.sendJoystickStateToIphone()
//                        }

                    case "spheroStatus":
                        if let connectedBolts = messageDict["connectedBolts"] as? [String] {
                            self.connectedDevices["Spheros"] = connectedBolts
                            self.sendStatusUpdate()
                            print("Mise à jour des Spheros connectés: \(connectedBolts)")
                        }

                    // AJOUT : Gérer le message "updateStage"
                    case "updateStage":
                        if let stage = messageDict["stage"] as? String,
                           let action = messageDict["action"] as? String {
                            // Vérifier si l'étape existe dans le dictionnaire brainStages
                            if var brainStage = self.brainStages[stage] {
                                switch action {
                                case "start":
                                    brainStage.started = true
                                    brainStage.finished = false
                                    print("\(stage) lancé (demande iPhone)")
                                    
                                    if stage.lowercased() == "synapse" {
                                        self.sendSendDopamineToBuzzers()
                                        print("Dopamine envoyée à l'esp buzzers")
                                    }
                                    
                                    if stage.lowercased() == "lsd" {
                                        if !OBSWebSocketClient.instance.isConnectedToOBS {
                                            OBSWebSocketClient.instance.connectOBS(ip: "192.168.10.213", port: 4455)
                                        }
                                        OBSWebSocketClient.instance.setScene(sceneName: "lsd_prise-drogue") { success, comment in
                                            if success {
                                                print("OBS scene changed to 'lsd_prise-drogue' successfully.")
                                            } else {
                                                print("Failed to change OBS scene: \(comment)")
                                            }
                                        }
                                    }
                                    
                                    if stage.lowercased() == "champi" {
                                        if !OBSWebSocketClient.instance.isConnectedToOBS {
                                            OBSWebSocketClient.instance.connectOBS(ip: "192.168.10.213", port: 4455)
                                        }
                                        OBSWebSocketClient.instance.setScene(sceneName: "champi_prise-drogue") { success, comment in
                                            if success {
                                                print("OBS scene changed to 'champi_prise-drogue' successfully.")
                                            } else {
                                                print("Failed to change OBS scene: \(comment)")
                                            }
                                        }
                                    }
                                case "finish":
                                    brainStage.started = false
                                    brainStage.finished = true
                                    print("\(stage) terminé (demande iPhone)")
                                    
                                    if stage.lowercased() == "synapse" {
                                        self.sendFinishDopamineToBuzzers()
                                        print("FinishDopamine envoyée à l'esp buzzers")
                                        
                                        let targetScene = "ecstasy_prise-drogue"
                                        if !OBSWebSocketClient.instance.isConnectedToOBS {
                                            OBSWebSocketClient.instance.connectOBS(ip: "192.168.10.213", port: 4455)
                                        }
                                        OBSWebSocketClient.instance.setScene(sceneName: targetScene) { success, comment in
                                            if success {
                                                print("Scène OBS changée avec succès à '\(targetScene)'.")
                                            } else {
                                                print("Échec du changement de scène OBS : \(comment)")
                                            }
                                        }
                                    }
                                    
                                    if stage.lowercased() == "champi" {
                                        self.sendFinishDopamineToBuzzers()
                                        print("The End envoyée à l'esp buzzers")
                                        
                                        let targetScene = "champi_soundtrack-success"
                                        if !OBSWebSocketClient.instance.isConnectedToOBS {
                                            OBSWebSocketClient.instance.connectOBS(ip: "192.168.10.213", port: 4455)
                                        }
                                        OBSWebSocketClient.instance.setScene(sceneName: targetScene) { success, comment in
                                            if success {
                                                print("Scène OBS changée avec succès à '\(targetScene)'.")
                                            } else {
                                                print("Échec du changement de scène OBS : \(comment)")
                                            }
                                        }
                                    }
                                default:
                                    print("Action inconnue: \(action)")
                                }
                                self.brainStages[stage] = brainStage
                                // Diffuse l'état mis à jour (commencé / terminé) à tous les clients
                                self.sendStatusUpdate()
                            } else {
                                print("Étape \(stage) inconnue pour updateStage (demande iPhone)")
                            }
                        }
                        
                    case "resetStage":
                        // On récupère "stage" et "state" (ex: "started" ou "finished")
                        if let stage = messageDict["stage"] as? String,
                           let state = messageDict["state"] as? String {
                            
                            // Vérifier si l’étape existe
                            if var brainStage = self.brainStages[stage] {
                                if state == "started" {
                                    brainStage.started = false
                                    print("\(stage) resetStarted (demande iPhone)")
                                } else if state == "finished" {
                                    brainStage.finished = false
                                    print("\(stage) resetFinished (demande iPhone)")
                                }
                                // On replace l'objet dans le dictionnaire
                                self.brainStages[stage] = brainStage
                                
                                // Diffuse l’état mis à jour à tous les clients
                                self.sendStatusUpdate()
                            } else {
                                print("Étape \(stage) inconnue pour resetStage (demande iPhone)")
                            }
                        }
                        
                    case "dessin":
                        if let action = messageDict["action"] as? String {
                            print("Message de type 'dessin' reçu avec action : \(action)")

                            // Transmettre le message à l'iPhone (si nécessaire)
                            if let iphoneSession = self.iPhoneClient?.session {
                                iphoneSession.writeText(receivedText)
                                print("Message 'dessin' forwardé à l'iPhone : \(receivedText)")
                            } else {
                                print("iPhone non connecté. Message 'dessin' ignoré.")
                            }
                        } else {
                            print("Message 'dessin' reçu sans action.")
                        }
                        
                    case "pinceau":
                        if let brush = messageDict["brush"] as? String {
                            print("Message 'selectBrush' reçu avec le pinceau : \(brush)")

                            // Créer un message JSON pour Windows
                            let forwardMsg: [String: Any] = [
                                "type": "brush",
                                "action": "selectBrush",
                                "brush": brush
                            ]

                            // Convertir le message en JSON
                            if let jsonData = try? JSONSerialization.data(withJSONObject: forwardMsg, options: []),
                               let jsonString = String(data: jsonData, encoding: .utf8) {

                                // Envoyer au client Windows s'il est connecté
                                if let windowsSession = self.windowsClient?.session {
                                    windowsSession.writeText(jsonString)
                                    print("Message 'selectBrush' forwardé au client Windows : \(jsonString)")
                                } else {
                                    print("Aucun client Windows connecté. Message 'selectBrush' ignoré.")
                                }
                            }
                        } else {
                            print("Message 'selectBrush' mal formé ou pinceau non spécifié.")
                        }
                    
                    case "obs":
                        // On s'attend à un JSON du genre :
                        // {
                        //   "type": "obs",
                        //   "action": "changeScene",
                        //   "scene": "NomDeLaScene"
                        // }
                        if let action = messageDict["action"] as? String {
                            switch action {
                            case "changeScene":
                                if let sceneName = messageDict["scene"] as? String {
                                    print("Demande iPhone de changer la scène OBS en '\(sceneName)'")
                                    if !OBSWebSocketClient.instance.isConnectedToOBS {
                                        OBSWebSocketClient.instance.connectOBS(ip: "192.168.10.213", port: 4455)
                                    }
                                    // Exemple : appeler un client OBS local
                                    // (Assurez-vous d’avoir votre client OBSWebSocketClient défini)
                                    OBSWebSocketClient.instance.setScene(sceneName: sceneName) { success, comment in
                                        print("Changement de scène terminé. success=\(success), comment=\(comment)")
                                        
                                        // Renvoyer éventuellement une réponse à l’iPhone
                                        let response: [String: Any] = [
                                            "type": "obsResponse",
                                            "scene": sceneName,
                                            "success": success,
                                            "comment": comment
                                        ]
                                        if let respData = try? JSONSerialization.data(withJSONObject: response, options: []),
                                           let respString = String(data: respData, encoding: .utf8) {
                                            session.writeText(respString)
                                        }
                                    }
                                }
                            default:
                                print("Action OBS inconnue : \(action)")
                            }
                        }

                    default:
                        print("Message iPhone de type \(messageType) non géré.")
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
                OBSWebSocketClient.instance.connectOBS(ip: "192.168.10.213", port: 4455)
                print("iPhone connecté et session définie")
            },
            disconnectedCode: { session in
                if self.iPhoneClient?.session === session {
                    self.iPhoneClient = nil
                    self.connectedDevices["iPhone"] = false
                    self.connectedDevices["Spheros"] = []
                    self.sendStatusUpdate()
                    print("iPhone déconnecté et session effacée")
                }
            }
        ))


        // Route controllerEsp
        setupWithRoutesInfos(routeInfos: RouteInfos(
            routeName: "controllerEsp",
            textCode: { session, receivedText in
                print("ControllerESP a envoyé : \(receivedText)")
                
                // Parse the JSON received
                if let data = receivedText.data(using: .utf8),
                   let messageDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {

                    // Vérifiez si c'est un message de joystick
                    if let x = messageDict["x"] as? Int,
                       let y = messageDict["y"] as? Int,
                       let button = messageDict["button"] as? Int {

                        // Mise à jour de l'état du joystick
                        self.joystickState["x"] = x
                        self.joystickState["y"] = y

                        // Créer un message pour l'iPhone
                        let joystickMsg: [String: Any] = [
                            "type": "joystick",
                            "x": x,
                            "y": y,
                            "button": button
                        ]

                        if let jsonData = try? JSONSerialization.data(withJSONObject: joystickMsg, options: []),
                           let jsonString = String(data: jsonData, encoding: .utf8),
                           let iphoneSession = self.iPhoneClient?.session {
                            iphoneSession.writeText(jsonString)
                            print("Joystick state envoyé à l'iPhone depuis ControllerESP : \(jsonString)")
                        } else {
                            print("Erreur : Impossible d'envoyer l'état du joystick à l'iPhone.")
                        }
                    }

                    // Gestion des autres types de messages
                    if let action = messageDict["action"] as? String {
                        if action == "confirmSoluce" {
                            print("Action 'confirmSoluce' reçue.")
                            if let champiStage = self.brainStages["Champi"], champiStage.started {
                                print("Étape 'Champi' est en mode 'started'. Vérification de la solution...")
                                self.checkSolution()
                            }
                            else if let lsdStage = self.brainStages["LSD"], lsdStage.started {
                                print("Étape 'LSD' est en mode 'started'. Envoi de 'confirmDrawing' à l'iPhone...")
                                
                                if !OBSWebSocketClient.instance.isConnectedToOBS {
                                    OBSWebSocketClient.instance.connectOBS(ip: "192.168.10.213", port: 4455)
                                }
                                OBSWebSocketClient.instance.setScene(sceneName: "lsd_idle")
                                
                                // Préparer le message à envoyer
                                let confirmDrawingMsg: [String: Any] = [
                                    "type": "drawing",
                                    "action": "confirmDrawing"
                                ]

                                // Convertir le message en JSON
                                if let jsonData = try? JSONSerialization.data(withJSONObject: confirmDrawingMsg, options: []),
                                   let jsonString = String(data: jsonData, encoding: .utf8),
                                   let iphoneSession = self.iPhoneClient?.session {
                                    // Envoyer le message à l'iPhone
                                    iphoneSession.writeText(jsonString)
                                    print("Message 'confirmDrawing' envoyé à l'iPhone : \(jsonString)")
                                    serverWS.brainStages["LSD"]?.finished = true
                                    serverWS.brainStages["LSD"]?.started = false
                                    serverWS.sendStatusUpdate()
                                } else {
                                    print("Erreur : Impossible de créer ou d'envoyer le message 'confirmDrawing'.")
                                }
                            }
                            else {
                                print("Aucune étape pertinente ('Champi' ou 'LSD') n'est en mode 'started'. Action ignorée.")
                            }
                        }

                        // Forward "mouseDown" and "mouseUp" actions to the iPhone
                        if action == "mouseDown" || action == "mouseUp" {
                            if let iphoneSession = self.iPhoneClient?.session {
                                iphoneSession.writeText(receivedText)
                                print("Action \(action) forwardée à l'iPhone.")
                            } else {
                                print("iPhone non connecté. Action \(action) ignorée.")
                            }
                            if let windowsSession = self.windowsClient?.session {
                                windowsSession.writeText(receivedText)
                                print("Action \(action) forwardée au Windows.")
                            } else {
                                print("Windows non connecté. Action \(action) ignorée.")
                            }
                        }

                        // Handle "selectBrush" action
                        if action == "selectBrush",
                           let brush = messageDict["brush"] as? String {

                            // Forward the brush selection to the Windows client
                            let forwardMsg: [String: Any] = [
                                "type": "brush",
                                "action": action,
                                "brush": brush
                            ]

                            if let jsonData = try? JSONSerialization.data(withJSONObject: forwardMsg, options: []),
                               let jsonString = String(data: jsonData, encoding: .utf8) {

                                if let windowsSession = self.windowsClient?.session {
                                    windowsSession.writeText(jsonString)
                                    print("Brush selection forwarded to Windows: \(jsonString)")
                                } else {
                                    print("No Windows client connected. Brush selection not sent.")
                                }
                            }
                        }

                        // Handle stage actions
                        if let stage = messageDict["stage"] as? String {
                            if var brainStage = self.brainStages[stage] {
                                switch action {
                                case "start":
                                    brainStage.started = true
                                    brainStage.finished = false
                                    print("\(stage) commencée")
                                case "finish":
                                    brainStage.started = false
                                    brainStage.finished = true
                                    print("\(stage) terminée")
                                default:
                                    print("Action inconnue pour l'étape \(stage)")
                                }
                                self.brainStages[stage] = brainStage
                                self.sendStatusUpdate()
                            } else {
                                print("Étape \(stage) inconnue")
                            }
                        }
                    }
                }
                 
            },
            dataCode: { session, receivedData in
                print("ControllerESP a envoyé des données binaires sur controllerEsp")
            },
            connectedCode: { session in
                let clientSession = ClientSession(session: session)
                self.controllerEspClient = clientSession
                self.connectedDevices["ControllerESP"] = true
                self.sendStatusUpdate()
                print("ControllerESP connecté")
            },
            disconnectedCode: { session in
                if self.controllerEspClient?.session === session {
                    self.controllerEspClient = nil
                    self.connectedDevices["ControllerESP"] = false
                    self.sendStatusUpdate()
                    print("ControllerESP déconnecté")
                }
            }
        ))
        
        // Route jaugeEsp
        setupWithRoutesInfos(routeInfos: RouteInfos(
            routeName: "jaugeEsp",
            textCode: { session, receivedText in
                print("jaugeEsp a envoyé : \(receivedText)")
                
                // Parse the JSON received
                if let data = receivedText.data(using: .utf8),
                   let messageDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let action = messageDict["action"] as? String {
                    
                    switch action {
                    case "allume":
                        if let color = messageDict["couleur"] as? [Int], color.count == 3 {
                            print("jaugeEsp : bandeaux allumés avec la couleur \(color)")
                        }
                    case "eteint":
                        print("jaugeEsp : bandeaux éteints")
                    default:
                        print("Action inconnue reçue de jaugeEsp : \(action)")
                    }
                }
            },
            dataCode: { session, receivedData in
                print("jaugeEsp a envoyé des données binaires")
            },
            connectedCode: { session in
                let clientSession = ClientSession(session: session)
                self.jaugeEspClient = clientSession
                self.connectedDevices["jaugeEsp"] = true
                self.sendStatusUpdate()
                print("jaugeEsp connecté")
            },
            disconnectedCode: { session in
                if self.jaugeEspClient?.session === session {
                    self.jaugeEspClient = nil
                    self.connectedDevices["jaugeEsp"] = false
                    self.sendStatusUpdate()
                    print("jaugeEsp déconnecté")
                }
            }
        ))
        
        // Route buzzersEsp
        setupWithRoutesInfos(routeInfos: RouteInfos(
            routeName: "buzzersEsp",
            textCode: { session, receivedText in
                print("buzzersEsp a envoyé : \(receivedText)")

                // Exemple de JSON: {"buzzersPressed":2,"buzzersTotal":2}
                if let data = receivedText.data(using: .utf8),
                   let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let pressed = dict["buzzersPressed"] as? Int,
                   let total = dict["buzzersTotal"] as? Int {
                       self.sendBuzzersStateToIphone(pressed: pressed, total: total)
                       
                       // Vérifier si le nombre de buzzers pressés a augmenté
                       if pressed > self.lastBuzzersPressed {
                           let sceneName = "champi_soundtrack-champi\(pressed)"
                           
                           print("Nombre de buzzers pressés a augmenté de \(self.lastBuzzersPressed) à \(pressed). Changement de scène OBS.")

                           if !OBSWebSocketClient.instance.isConnectedToOBS {
                               OBSWebSocketClient.instance.connectOBS(ip: "192.168.10.213", port: 4455)
                           }
                           
                           OBSWebSocketClient.instance.setScene(sceneName: sceneName) { success, comment in
                               print("Scene changed to \(sceneName). success=\(success), comment=\(comment)")
                               
                               // Vous pouvez ajouter ici la logique pour déclencher le son si nécessaire
                           }
                       } else {
                           print("Nombre de buzzers pressés n'a pas augmenté (Pressed: \(pressed), Last: \(self.lastBuzzersPressed)). Aucun changement de scène OBS.")
                       }

                       // Toujours mettre à jour lastBuzzersPressed
                       self.lastBuzzersPressed = pressed
                }
            },
            dataCode: { session, binary in },
            connectedCode: { session in
                let clientSession = ClientSession(session: session)
                self.buzzersEspClient = clientSession
                self.connectedDevices["BuzzersESP"] = true
                self.sendStatusUpdate()
                print("buzzersEsp connecté")
            },
            disconnectedCode: { session in
                if self.buzzersEspClient?.session === session {
                    self.buzzersEspClient = nil
                    self.connectedDevices["BuzzersESP   "] = false
                    self.sendStatusUpdate()
                    print("buzzersEsp déconnecté")
                }
            }
        ))

        // Route rfidEsp : reçoit l’ID de badge
        setupWithRoutesInfos(routeInfos: RouteInfos(
            routeName: "rfidEsp",
            textCode: { session, receivedText in
                print("rfidEsp a envoyé : \(receivedText)")

                // JSON: {"card_id":12345}
                if let data = receivedText.data(using: .utf8),
                   let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let cardId = dict["card_id"] as? Int {

                    // Envoyer vers l'iPhone
                    self.sendRfidDataToIphone(cardId: cardId)
                }
            },
            dataCode: { session, binary in },
            connectedCode: { session in
                let clientSession = ClientSession(session: session)
                self.rfidEspClient = clientSession
                self.connectedDevices["RfidESP"] = true
                self.sendStatusUpdate()
                print("rfidEsp connecté")
            },
            disconnectedCode: { session in
                if self.rfidEspClient?.session === session {
                    self.rfidEspClient = nil
                    self.connectedDevices["RfidESP"] = false
                    self.sendStatusUpdate()
                    print("rfidEsp déconnecté")
                }
            }
        ))
        
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
                                
                                self.sendFinishDopamineToBuzzers()
                                print("FinishDopamine envoyée à l'esp buzzers")
                                
                                if !self.hasDispatchedDopamine {
                                    self.hasDispatchedDopamine = true
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
                                        self.sendSendDopamineToBuzzers()
                                        print("Dopamine envoyée à l'esp buzzers")
                                    }
                                }
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
    }
    
    func sendStatusUpdate() {
        do {
            var dataToSend = connectedDevices
            dataToSend["brainStages"] = brainStages.mapValues { [
                "started": $0.started,
                "finished": $0.finished
            ]}
            
            let jsonData = try JSONSerialization.data(withJSONObject: dataToSend, options: [])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                for session in statusSessions {
                    session.writeText(jsonString)
                }
            }
        } catch {
            print("Error serializing status data to JSON: \(error)")
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
