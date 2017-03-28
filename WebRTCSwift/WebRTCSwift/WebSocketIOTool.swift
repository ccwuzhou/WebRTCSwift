//
//  WebSocketIOTool.swift
//  WebRTCSwift
//
//  Created by wwz on 2017/3/27.
//  Copyright © 2017年 apple. All rights reserved.
//

import UIKit
import WebRTC
import SocketIO
public let RECEIVED_SINALING_MESSAGE_NOTI = "RECEIVED_SINALING_MESSAGE_NOTI"

let WEBSOCKET_URL_STRING = "http://47.90.55.2:3000"

public enum WebSocketSDPType: String {
    
    case hello = "init"
    case offer = "offer"
    case answer = "answer"
    case candidate = "candidate"
    case bye = "bye"
}

class WebSocketIOTool: NSObject {

    static let shared = WebSocketIOTool()
    
    var localSigid : String?
    
    var remoteSigid : String?
    
    private lazy var socket = SocketIOClient(socketURL: NSURL(string: WEBSOCKET_URL_STRING)!, config: ["log": false, "forcePolling": true])
    
    public func startLintening() {
        
        self.socket.on("connect") { (_, _) in
            
            print("socket connected")
        }
        
        self.socket.on("id") { (datas, _) in
            
            if datas.count == 0 {
                return
            }
            
            guard let result = datas[0] as? String else { return }
            
            self.localSigid = result
            
        }
        self.socket.on("id2") { (datas, _) in
            
        }
        self.socket.on("message") { (datas, _) in
            if datas.count == 0 {
                return
            }
            
            self.p_handleMessage(result: datas[0])
        }
        self.socket.connect()
    }
    
    private func p_handleMessage(result: Any) {
        
        print("receive data ==>\(result)")
        
        guard let dict = result as? [String: Any] else { return }
        
        let model = SocketIOModel(jsonDict: dict)
        
        guard let type = model.type, let from = model.from else { return }
        
        self.remoteSigid = from
        
        if type == WebSocketSDPType.hello.rawValue {
        
            // create media stream
            WebRTCTool.shared.createMediaStream()
            
            // 创建offer
            WebRTCTool.shared.createOffer(completionHandler: { (sdp) in
                
                let json : [String: Any] = ["to": from, "type": "offer", "payload": ["type": "offer", "sdp": sdp]]
                // 发送offer
                self.emitMessage(dict: json)
            })
            
        }else if type == WebSocketSDPType.offer.rawValue {
        
            // create media stream
            WebRTCTool.shared.createMediaStream()
            
            guard let sdp = model.payload?["sdp"] as? String else { return  }
            
            // set remote description
            WebRTCTool.shared.setRemoteDescription(type: .offer, sdp: sdp, completionHandler: { (sdp) in
                
                let json : [String: Any] = ["to": from, "type": "answer", "payload": ["type": "answer", "sdp": sdp]]
                // 发送answer
                self.emitMessage(dict: json)
            })
            
        }else if type == WebSocketSDPType.answer.rawValue {
         
            guard let sdp = model.payload?["sdp"] as? String else { return  }
            // set remote description
            WebRTCTool.shared.setRemoteDescription(type: .answer, sdp: sdp, completionHandler: nil)
            
        }else if type == WebSocketSDPType.candidate.rawValue {
        
            guard let payload = model.payload else {return}
            
            guard let candidate = payload["candidate"] as? String, let sdpMid = payload["id"] as? String, let sdpLineIndewx = payload["label"] as? Int else {return}
            
            WebRTCTool.shared.addICECandidata(sdp: candidate, sdpMLineIndex: Int32(sdpLineIndewx), sdpMid: sdpMid)
        
        }else if type == WebSocketSDPType.bye.rawValue {
        
        }
    }
    
    func emitMessage(dict: [String: Any]) {
        print("send data ==>\(dict)")
        self.socket.emit("message", dict)
    }
    
    func sendInit(sid: String) {
        self.emitMessage(dict: ["to": sid, "type": "init"])
    }
}


class SocketIOModel : NSObject {
    
    var type: String?
    var to : String?
    var from: String?
    
    var payload: [String: Any]?
    
    init(jsonDict: [String: Any]){
    
        super.init()
        self.setValuesForKeys(jsonDict)
    }
    
    override func setValue(_ value: Any?, forUndefinedKey key: String) {}
    
}
