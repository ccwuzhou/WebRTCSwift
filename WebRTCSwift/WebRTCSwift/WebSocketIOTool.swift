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

public let WEB_RECEIVED_SINALING_MESSAGE_NOTI = "WEB_RECEIVED_SINALING_MESSAGE_NOTI"
public let WEB_RECEIVED_SIGID_NOTI = "WEB_RECEIVED_SIGID_NOTI"

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
    
    // 本地sigid
    var localSigid : String?
    
    // 远程sigid
    var remoteSigid : String?
    
    private lazy var socket = SocketIOClient(socketURL: NSURL(string: WEBSOCKET_URL_STRING)!, config: ["log": false, "forcePolling": true])
    
    // 开始监听数据
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
            
            NotificationCenter.default.post(name: NSNotification.Name(WEB_RECEIVED_SIGID_NOTI), object: result)
            
        }
        self.socket.on("id2") { (datas, _) in
            
        }
        self.socket.on("message") { (datas, _) in
            if datas.count == 0 {
                return
            }
            
            print("receive data ==>\(datas[0])")
            
            guard let dict = datas[0] as? [String: Any] else { return }
            
            let model = SocketIOModel(jsonDict: dict)
            
            NotificationCenter.default.post(name: NSNotification.Name(WEB_RECEIVED_SINALING_MESSAGE_NOTI), object: model)
        }
        self.socket.connect()
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
