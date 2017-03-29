//
//  ViewController.swift
//  WebRTCSwift
//
//  Created by apple on 2017/3/27.
//  Copyright © 2017年 apple. All rights reserved.
//

import WWZSwift
import WWZSwiftSocket
import WebRTC

private let SERVER_HOST = "47.90.55.2"
private let SERVER_PORT : UInt16 = 20014

class ViewController: UIViewController {
    
    var udpSocket : WWZUDPSocket = WWZUDPSocket()
    
    var isOnCalling : Bool = false
    
    lazy var tipLabel : UILabel = UILabel(frame: self.view.bounds)
    
    lazy var textField : UITextField = UITextField(frame: CGRect(x: 10, y: 40, width: 200, height: 40))
    
    var isAllowToTap : Bool = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        self.view.backgroundColor = UIColor.lightGray
        WebSocketIOTool.shared.startLintening()
        
        WebRTCTool.shared.delegate = self
        
        self.udpSocket.delegate = self
        
        self.textField.text = "szwwz"
        self.textField.borderStyle = .roundedRect
        
        self.udpSocket.startListen(port: 8989)
        self.view.addSubview(self.textField)
        
        self.textField.wwz_alignCenterX()
//        self.view.addSubview(self.tipLabel)
//        self.tipLabel.numberOfLines = 0
//        self.addButtons()
        
        self.addNotification()
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        if !self.isOnCalling {
            
            self.textField.resignFirstResponder()
            self.app_get_sigid(uuid: self.textField.text!)
            self.isOnCalling = true
        }else{
        
            WebRTCTool.shared.cleanCache()
            WebSocketIOTool.shared.emitMessage(dict: ["to": WebSocketIOTool.shared.remoteSigid!, "type": "bye"])
            self.isOnCalling = false
        }
        self.textField.isHidden = self.isOnCalling
    }
    
    private func addButtons() {
        
//        let button = UIButton(frame: CGRect(x: 10, y: 100, width: 60, height: 40))
//        button.setTitle("室外机", for: .normal)
//        button.addTarget(self, action: #selector(ViewController.clickOut), for: .touchUpInside)
//        button.backgroundColor = UIColor.red
//        self.view.addSubview(button)
        
        let button2 = UIButton(frame: CGRect(x: 200, y: 100, width: 60, height: 40))
        button2.backgroundColor = UIColor.red
        button2.setTitle("室内机", for: .normal)
        button2.addTarget(self, action: #selector(ViewController.clickIn), for: .touchUpInside)
        self.view.addSubview(button2)
    }
    
    @objc private func clickIn() {
        self.textField.resignFirstResponder()
        self.app_get_sigid(uuid: self.textField.text!)
    }
    
    
    private func app_get_sigid(uuid: String) {
        
        let message = "{\"app\":\"video\",\"api\":\"app_get_sigid_by_uuid\",\"data\":{\"uuid\":\"\(uuid)\"}}"
        
        self.udpSocket.send(message: message, toHost: SERVER_HOST, port: SERVER_PORT)
    }
}

extension ViewController {

    fileprivate func addNotification() {
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.received_sigid_noti(noti:)), name: NSNotification.Name(WEB_RECEIVED_SIGID_NOTI), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.received_sinaling_noti(noti:)), name: NSNotification.Name(WEB_RECEIVED_SINALING_MESSAGE_NOTI), object: nil)
    }
    // 获取到本地sigid
    @objc private func received_sigid_noti(noti: Notification) {
        
        guard let sigid = noti.object as? String else { return }
        
        self.app_set_sigid(uuid: "szwwz", sigid: sigid)
    }
    
    private func app_set_sigid(uuid: String, sigid: String) {
        
        let message = "{\"app\":\"video\",\"api\":\"app_set_sigid\",\"data\":{\"uuid\":\"\(uuid)\", \"sigid\":\"\(sigid)\"}}"
        
        self.udpSocket.send(message: message, toHost: SERVER_HOST, port: SERVER_PORT)
    }
    // 收到message
    @objc private func received_sinaling_noti(noti: Notification) {
        
        guard let socketModel = noti.object as? SocketIOModel else { return }
        
        guard let type = socketModel.type, let from = socketModel.from else { return }
        
        WebSocketIOTool.shared.remoteSigid = from
        
        if type == WebSocketSDPType.hello.rawValue {// 收到呼叫请求
            
           self.received_call()
            
        }else if type == WebSocketSDPType.offer.rawValue {// 收到offer
            
            self.received_offer(socketModel: socketModel)
            
        }else if type == WebSocketSDPType.answer.rawValue {// 收到answer
            
            self.received_answer(socketModel: socketModel)
            
        }else if type == WebSocketSDPType.candidate.rawValue {// 收到candidata
            
            self.received_candidate(socketModel: socketModel)
            
        }else if type == WebSocketSDPType.bye.rawValue {// 收到挂断
            
            self.received_hungup()
        }
    }
    
    private func received_call() {
        
        let tipView = WebRTCTipView(frame: CGRect(x: (WWZ_SCREEN_WIDTH-250)*0.5, y: (WWZ_SCREEN_HEIGHT-350)*0.5, width: 250, height: 350))
        tipView.delegate = self
        tipView.wwz_show(completion: nil)
    }
    
    private func received_offer(socketModel: SocketIOModel) {
        
        // create media stream
        WebRTCTool.shared.initRTCSetting(remoteViewFrame: UIScreen.main.bounds, localViewFrame: CGRect(x: WWZ_SCREEN_WIDTH-90-10, y: WWZ_SCREEN_HEIGHT-160-10, width: 90, height: 160), superView: self.view)
        
        guard let sdp = socketModel.payload?["sdp"] as? String else { return  }
        
        // set remote description
        WebRTCTool.shared.setRemoteDescription(type: .offer, sdp: sdp, completionHandler: { (sdp) in
            
            let json : [String: Any] = ["to": socketModel.from!, "type": "answer", "payload": ["type": "answer", "sdp": sdp]]
            // 发送answer
            WebSocketIOTool.shared.emitMessage(dict: json)
        })
    }
    
    private func received_answer(socketModel: SocketIOModel) {
        
        guard let sdp = socketModel.payload?["sdp"] as? String else { return  }
        // set remote description
        WebRTCTool.shared.setRemoteDescription(type: .answer, sdp: sdp, completionHandler: nil)
    }
    
    private func received_candidate(socketModel: SocketIOModel) {
        
        guard let payload = socketModel.payload else {return}
        
        guard let candidate = payload["candidate"] as? String, let sdpMid = payload["id"] as? String, let sdpLineIndewx = payload["label"] as? Int else {return}
        
        WebRTCTool.shared.addICECandidata(sdp: candidate, sdpMLineIndex: Int32(sdpLineIndewx), sdpMid: sdpMid)
    }
    private func received_hungup() {
        
        WebRTCTool.shared.cleanCache()
        self.isOnCalling = false
        self.textField.isHidden = self.isOnCalling
    }

}

extension ViewController : WWZUDPSocketDelegate {

    func udpSocket(udpSocket: WWZUDPSocket, didReceiveData data: Data, fromHost host: String) {
        
        guard host == SERVER_HOST else{
            return
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) else { return }
        
        print(json)
        
        self.tipLabel.text = String(data: data, encoding: .utf8)
        
        guard let resultDict = json as? [String : Any] else { return }
        
        guard let api = resultDict["api"] as? String else { return }
        
        guard api == "app_get_sigid_by_uuid" else {
            return
        }
        
        guard let dataDict = resultDict["data"] as? [String: String] else { return }
        
        guard let sigid = dataDict["sigid"] else { return }
        
        WebSocketIOTool.shared.remoteSigid = sigid
        
        WebSocketIOTool.shared.sendInit(sid: sigid)
    }
}

extension ViewController : WebRTCToolDelegate {
    
    func webRTCTool(webRTCTool: WebRTCTool, didGenerateIceCandidate candidate: RTCIceCandidate) {
        
        let json : [String : Any] = ["to": WebSocketIOTool.shared.remoteSigid!,
                     "type":"candidate",
                      "payload": [
                        "label":NSNumber(value: candidate.sdpMLineIndex),
                        "id":candidate.sdpMid!,
                        "candidate": candidate.sdp]]
        WebSocketIOTool.shared.emitMessage(dict: json)
    }
}


extension ViewController : WebRTCTipViewDelegate {

    func tipView(tipView: WebRTCTipView, didClickButtonAtIndex index: Int) {
        
        if index == 0 {
            self.isOnCalling = true
            self.textField.isHidden = self.isOnCalling
            // create media stream
            WebRTCTool.shared.initRTCSetting(remoteViewFrame: UIScreen.main.bounds, localViewFrame: CGRect(x: WWZ_SCREEN_WIDTH-90-10, y: WWZ_SCREEN_HEIGHT-160-10, width: 90, height: 160), superView: self.view)
            
            // 创建offer
            WebRTCTool.shared.createOffer(completionHandler: { (sdp) in
                
                let json : [String: Any] = ["to": WebSocketIOTool.shared.remoteSigid!, "type": "offer", "payload": ["type": "offer", "sdp": sdp]]
                // 发送offer
                WebSocketIOTool.shared.emitMessage(dict: json)
            })
        }
    }
}
