//
//  OBSWebSocketClient.swift
//  WebSocketServer
//
//  Created by digital on 13/01/2025.
//


import Foundation
import NWWebSocket
import Network

class OBSWebSocketClient: ObservableObject {
    static let instance = OBSWebSocketClient()

    private var obsSocket: NWWebSocket?

    @Published var isConnectedToOBS = false

    // Stocker éventuellement un "requestId" → "callback" si vous voulez gérer la réponse
    private var pendingRequests: [String: (Bool, String) -> Void] = [:]

    /// Se connecter à OBS WebSocket
    func connectOBS(ip: String = "192.168.10.213", port: Int = 4455, password: String? = nil) {
        guard let url = URL(string: "ws://\(ip):\(port)") else { return }
        
        // Init NWWebSocket
        let socket = NWWebSocket(url: url, connectAutomatically: false)
        socket.delegate = self
        socket.connect()
        self.obsSocket = socket
    }

    /// Fermer la connexion proprement
    func disconnectOBS() {
        obsSocket?.disconnect()
        obsSocket = nil
    }

    /// Méthode d'authentification (version OBS WebSocket 5.x)
    private func sendIdentify(password: String? = nil) {
        // On envoie le message "Identify" → op = 1
        // En cas de mot de passe : on doit générer le hash approprié si OBS WebSocket le demande (challenge).
        // Pour un test simple (pas d'auth), on envoie juste la version RPC.
        let identifyPayload: [String: Any] = [
            "op": 1,
            "d": [
                "rpcVersion": 1,
                // "authentication": "token ou hash" si nécessaire
            ]
        ]
        sendDictionaryAsJSON(identifyPayload)
    }

    /// Exemple de fonction pour changer de scène
    func setScene(sceneName: String, completion: ((Bool, String) -> Void)? = nil) {
        // op = 6 => "Request"
        let requestId = UUID().uuidString
        if let completion = completion {
            pendingRequests[requestId] = completion
        }

        let requestPayload: [String: Any] = [
            "op": 6,
            "d": [
                "requestType": "SetCurrentProgramScene",
                "requestId": requestId,
                "requestData": [
                    "sceneName": sceneName
                ]
            ]
        ]
        sendDictionaryAsJSON(requestPayload)
        
        if sceneName == "ecstasy_prise-drogue" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
                self.setScene(sceneName: "ecstasy_retour-rover") { success, message in
                    if success {
                        print("[OBS] Successfully switched to ecstasy_retour-rover after delay.")
                    } else {
                        print("[OBS] Failed to switch to ecstasy_retour-rover: \(message)")
                    }
                }
            }
        }
        
        if sceneName == "lsd_prise-drogue" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
                self.setScene(sceneName: "lsd_retour-windows") { success, message in
                    if success {
                        print("[OBS] Successfully switched to lsd_retour-windows after delay.")
                    } else {
                        print("[OBS] Failed to switch to lsd_retour-windows: \(message)")
                    }
                }
            }
        }
        
        if sceneName == "champi_soundtrack-success" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                self.setScene(sceneName: "the-end") { success, message in
                    if success {
                        print("[OBS] Successfully switched to the-end after delay.")
                    } else {
                        print("[OBS] Failed to switch to the-end: \(message)")
                    }
                }
            }
        }
    }

    private func sendDictionaryAsJSON(_ dict: [String: Any]) {
        guard let socket = obsSocket else { return }
        if let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            socket.send(string: jsonString)
        }
    }
}

// MARK: - WebSocketConnectionDelegate
extension OBSWebSocketClient: WebSocketConnectionDelegate {

    func webSocketDidConnect(connection: WebSocketConnection) {
        print("[OBS] WebSocket connected")
        self.isConnectedToOBS = true
        // Envoyer la requête identify
        sendIdentify()
    }

    func webSocketDidDisconnect(connection: WebSocketConnection, closeCode: NWProtocolWebSocket.CloseCode, reason: Data?) {
        print("[OBS] WebSocket disconnected, code: \(closeCode)")
        self.isConnectedToOBS = false
    }

    func webSocketViabilityDidChange(connection: WebSocketConnection, isViable: Bool) {
        print("[OBS] Viability changed: \(isViable)")
    }

    func webSocketDidAttemptBetterPathMigration(result: Result<WebSocketConnection, NWError>) {
        // Pas forcément utile, laisse vide
    }

    func webSocketDidReceiveError(connection: WebSocketConnection, error: NWError) {
        print("[OBS] Received error: \(error)")
    }

    func webSocketDidReceivePong(connection: WebSocketConnection) {
        print("[OBS] Received pong")
    }

    func webSocketDidReceiveMessage(connection: WebSocketConnection, string: String) {
        print("[OBS] Received message from OBS: \(string)")

        // Tenter de parser la réponse
        guard let jsonData = string.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
            return
        }

        // Regarder l'op code
        if let op = dict["op"] as? Int {
            switch op {
            case 2: // Identify success "Hello/Identified"
                // OBS envoie d’abord "Hello" (op=0), puis "Identified" (op=2)
                print("[OBS] Identified successfully!")
            case 5: // Event
                // OBS envoie un "Event"
                if let eventData = dict["d"] as? [String: Any],
                   let eventType = eventData["eventType"] as? String {
                    print("[OBS] Event \(eventType) reçu")
                }
            case 7: // Response to a request
                if let d = dict["d"] as? [String: Any],
                   let requestId = d["requestId"] as? String,
                   let status = d["requestStatus"] as? [String: Any],
                   let result = status["result"] as? Bool {
                    
                    let msg = status["comment"] as? String ?? ""
                    
                    if let completion = pendingRequests[requestId] {
                        completion(result, msg)
                        pendingRequests.removeValue(forKey: requestId)
                    }
                    print("[OBS] Réponse requestId=\(requestId), success=\(result), msg=\(msg)")
                }
            default:
                break
            }
        }
    }

    func webSocketDidReceiveMessage(connection: WebSocketConnection, data: Data) {
        // OBS n’envoie pas (en général) de binaire, donc vous pouvez laisser vide.
    }
}
