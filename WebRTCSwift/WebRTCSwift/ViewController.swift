//
//  ViewController.swift
//  WebRTCSwift
//
//  Created by apple on 2017/3/27.
//  Copyright © 2017年 apple. All rights reserved.
//

import UIKit
import WWZSwiftSocket
import WebRTC

private let SERVER_HOST = "47.90.55.2"
private let SERVER_PORT : UInt16 = 20014

class ViewController: UIViewController {

    var remoteVideoTrack : RTCVideoTrack?
    var remoteVidewView : RTCEAGLVideoView?
    
    var udpSocket : WWZUDPSocket = WWZUDPSocket()
    
    lazy var tipLabel : UILabel = UILabel(frame: self.view.bounds)
    
    lazy var textField : UITextField = UITextField(frame: CGRect(x: 10, y: 10, width: 200, height: 40))
    
    var isAllowToTap : Bool = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.lightGray
        WebSocketIOTool.shared.startLintening()
        
        WebRTCTool.shared.delegate = self
        
        self.udpSocket.delegate = self
        
        self.textField.text = "wwz"
        self.textField.borderStyle = .roundedRect
        
        self.udpSocket.startListen(port: 8989)
        self.view.addSubview(self.textField)
        self.view.addSubview(self.tipLabel)
        self.tipLabel.numberOfLines = 0
        self.addButtons()
        
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
//        if self.isAllowToTap {
        
//            self.app_get_sigid(uuid: "123456789")
//            self.isAllowToTap = false
//        }
    }

    private func addButtons() {
        
        let button = UIButton(frame: CGRect(x: 10, y: 100, width: 60, height: 40))
        button.setTitle("室外机", for: .normal)
        button.addTarget(self, action: #selector(ViewController.clickOut), for: .touchUpInside)
        button.backgroundColor = UIColor.red
        self.view.addSubview(button)
        
        let button2 = UIButton(frame: CGRect(x: 200, y: 100, width: 60, height: 40))
        button2.backgroundColor = UIColor.red
        button2.setTitle("室内机", for: .normal)
        button2.addTarget(self, action: #selector(ViewController.clickIn), for: .touchUpInside)
        self.view.addSubview(button2)
    }
    @objc private func clickOut() {

        self.textField.resignFirstResponder()
        self.app_set_sigid(uuid: self.textField.text!, sigid: WebSocketIOTool.shared.localSigid!)
    }
    
    @objc private func clickIn() {
        self.textField.resignFirstResponder()
        self.app_get_sigid(uuid: self.textField.text!)
    }
    
    private func app_set_sigid(uuid: String, sigid: String) {
        
        let message = "{\"app\":\"video\",\"api\":\"app_set_sigid\",\"data\":{\"uuid\":\"\(uuid)\", \"sigid\":\"\(sigid)\"}}"
        
        self.udpSocket.send(message: message, toHost: SERVER_HOST, port: SERVER_PORT)
    }
    private func app_get_sigid(uuid: String) {
        
        let message = "{\"app\":\"video\",\"api\":\"app_get_sigid_by_uuid\",\"data\":{\"uuid\":\"\(uuid)\"}}"
        
        self.udpSocket.send(message: message, toHost: SERVER_HOST, port: SERVER_PORT)
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

    func webRTCTool(webRTCTool: WebRTCTool, setLocalStream stream: RTCMediaStream) {
        
        self.remoteVidewView = RTCEAGLVideoView(frame: self.view.bounds)
        self.view.addSubview(self.remoteVidewView!)
    }

    func webRTCTool(webRTCTool: WebRTCTool, addRemoteStream stream: RTCMediaStream) {
        
        self.remoteVideoTrack = nil
        self.remoteVidewView?.renderFrame(nil)
        if stream.videoTracks.count == 0 {
            return;
        }
        self.remoteVideoTrack = stream.videoTracks[0]
        
        self.remoteVideoTrack?.add(self.remoteVidewView!)
        
    }
    
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
