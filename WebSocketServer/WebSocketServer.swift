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
}
