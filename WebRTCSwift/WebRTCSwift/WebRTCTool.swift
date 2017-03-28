//
//  WebRTCTool.swift
//  WebRTCSwift
//
//  Created by apple on 2017/3/27.
//  Copyright © 2017年 apple. All rights reserved.
//

import UIKit
import WebRTC

private let STUN_SERVER_URL = "stun:112.74.103.182:3478"
//private let STUN_SERVER_URL_2 = "stun:stun.l.google.com:19302"

protocol WebRTCToolDelegate : NSObjectProtocol {
    
    func webRTCTool(webRTCTool: WebRTCTool, didGenerateIceCandidate candidate: RTCIceCandidate)
    
    func webRTCTool(webRTCTool: WebRTCTool, setLocalStream stream: RTCMediaStream)
    
    func webRTCTool(webRTCTool: WebRTCTool, addRemoteStream stream: RTCMediaStream)
}


class WebRTCTool: NSObject {

    // MARK: -公有属性
    /// 单例
    static let shared = WebRTCTool()
    /// delegate
    public var delegate : WebRTCToolDelegate?
    
    
    // MARK: -私有属性
    fileprivate lazy var peerConnectionFactory : RTCPeerConnectionFactory = RTCPeerConnectionFactory()
    
    fileprivate var mediaStream : RTCMediaStream!
    
    fileprivate lazy var peerConnection : RTCPeerConnection = {
    
        let iceServer = RTCIceServer(urlStrings: [STUN_SERVER_URL])
        
        let config = RTCConfiguration()
        config.iceServers = [iceServer]
        config.iceTransportPolicy = .all
        
        return self.peerConnectionFactory.peerConnection(with: config, constraints: self.peerConnectionConstraints, delegate: self)
    
    }()

    fileprivate var peerConnectionConstraints : RTCMediaConstraints {
    
        return RTCMediaConstraints(mandatoryConstraints: ["OfferToReceiveAudio" : "true","OfferToReceiveVideo" : "true"], optionalConstraints: ["DtlsSrtpKeyAgreement" : "true"])
    }

    fileprivate var offerOrAnswerConstraints : RTCMediaConstraints {
    
        return RTCMediaConstraints(mandatoryConstraints: ["OfferToReceiveAudio" : "true","OfferToReceiveVideo" : "true"], optionalConstraints: nil)
    }

    fileprivate var localVideoConstraints : RTCMediaConstraints {
    
        return RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
    }


    /// 公有方法
    public func addICECandidata(sdp: String, sdpMLineIndex: Int32, sdpMid: String) {
    
        self.peerConnection.add(RTCIceCandidate(sdp: sdp, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid))
    }

    /// 创建本地流
    public func createMediaStream() {
        
        // local media stream
        self.mediaStream = self.peerConnectionFactory.mediaStream(withStreamId: "ARDAMS")
        

        guard (AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo).last as? AVCaptureDevice) != nil else {
            
            print("相机不能打开摄像头")
            
            return
        }
        
        let authStatus = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
        
        if authStatus == .restricted || authStatus == .denied {
            
            print("相机访问受限")

            return
        }
        // add video track
        let videoSource = self.peerConnectionFactory.avFoundationVideoSource(with: self.localVideoConstraints)
        
        let videoTrack = self.peerConnectionFactory.videoTrack(with: videoSource, trackId: "ARDAMSv0")
        self.mediaStream.addVideoTrack(videoTrack)
        
        // add audio track
        let audioTrack = self.peerConnectionFactory.audioTrack(withTrackId: "ARDAMSa0")
        self.mediaStream.addAudioTrack(audioTrack)
        
        // add to peerconnection
        self.peerConnection.add(self.mediaStream)
        
        if let delegate = self.delegate {
            delegate.webRTCTool(webRTCTool: self, setLocalStream: self.mediaStream)
        }
        
    }
    // 创建offer
    public func createOffer(completionHandler: ((_ sdp: String)->())?) {
    
        self.peerConnection.offer(for: self.offerOrAnswerConstraints) {[weak self] (sessionDescription, error) in
            
            if let error = error {
            
                print(error)
                return
            }
            self?.p_setLocalDescription(sessionDescription: sessionDescription, completionHandler: completionHandler)
            
        }
    }
    
    /// 设置远程description
    public func setRemoteDescription(type: String, sdp: String, completionHandler: ((_ sdp: String)->())?) {
        
        let sdpType : RTCSdpType = type == "offer" ? .offer : .answer
        
        let remoteSdp = RTCSessionDescription(type: sdpType, sdp: sdp)
        
        let newSdp = self.p_sessionDescripteion(description: remoteSdp, preferredVideoCodec: "H264")
        
        self.peerConnection.setRemoteDescription(newSdp) {[weak self] (error) in
            
            if let error = error {
            
                print(error)
               return
            }
            
            if sdpType != .offer {
                return
            }
            
            self?.peerConnection.answer(for: (self?.offerOrAnswerConstraints)!, completionHandler: {[weak self] (sessionDescription, error) in
                
                if let error = error {
                    
                    print(error)
                    return
                }
                
                self?.p_setLocalDescription(sessionDescription: sessionDescription, completionHandler: completionHandler)
            })
        }
    }
}

extension WebRTCTool {

    fileprivate func p_setLocalDescription(sessionDescription: RTCSessionDescription?, completionHandler: ((_ sdp: String)->())?) {
    
        guard let sdp = sessionDescription else {
            return
        }
        
        let newSdp = self.p_sessionDescripteion(description: sdp, preferredVideoCodec: "H264")
        
        self.peerConnection.setLocalDescription(newSdp) {[weak self] (error) in
            
            if let handle = completionHandler {
            
                if let sdpString = self?.peerConnection.localDescription?.sdp {
                    handle(sdpString)
                }
            }
        }
        
    }
    
    fileprivate func p_sessionDescripteion(description: RTCSessionDescription, preferredVideoCodec codec: String) -> RTCSessionDescription{
    
        let sdpString = description.sdp
        let lineSeparator = "\n"
        let mLineSeparator = " "
        
        var mLines = sdpString.components(separatedBy: lineSeparator)
        
        var mLineIndex = -1
        var codecRtpMap : String?
        
        let pattern = "^a=rtpmap:(\\d+) \(codec)(/\\d+)+[\r]?$"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else{return description}
        
        var i = 0
        
        while i < mLines.count && (mLineIndex == -1 || codecRtpMap == nil) {
            
            let line = mLines[i]
            if line.hasPrefix("m=video") {
                
                mLineIndex = i
                i += 1
                continue
            }
            
            if let codecMatches = regex.firstMatch(in: line, options: [], range: NSMakeRange(0, line.characters.count)) {
            
                codecRtpMap = (line as NSString).substring(with: codecMatches.rangeAt(1))
                i += 1
                continue
            }
            i += 1
        }
        
        if mLineIndex == -1 {
            return description
        }
        
        if codecRtpMap == nil {
            return description
        }
        
        let origMlineParts = mLines[mLineIndex].components(separatedBy: mLineSeparator)
        
        if origMlineParts.count > 3 {
            var newMLineParts = [String]()
            
            for origPartIndex in 0..<3 {
                
                newMLineParts.append(origMlineParts[origPartIndex])
            }
            newMLineParts.append(codecRtpMap!)
            
            for origPartIndex in 3..<origMlineParts.count {
                
                if codecRtpMap! != origMlineParts[origPartIndex] {
                    newMLineParts.append(origMlineParts[origPartIndex])
                }
            }
            
            let newMLine = newMLineParts.joined(separator: mLineSeparator)
            mLines[mLineIndex] = newMLine
        }else{
        
            print("Wrong SDP media description format: \(mLines[mLineIndex])")
        }
        
        let mangledSdpString = mLines.joined(separator: lineSeparator)
        
        return RTCSessionDescription(type: description.type, sdp: mangledSdpString)
    }
}

extension WebRTCTool : RTCPeerConnectionDelegate {

    
    /** Called when the SignalingState changed. */
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState){
        print("didChange= stateChanged===================\(stateChanged.rawValue)")
    }
    
    
    /** Called when media is received on a new stream from remote peer. */
    public func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream){
        
        if let delegate = self.delegate {
        
            delegate.webRTCTool(webRTCTool: self, addRemoteStream: stream)
        }
    }
    
    
    /** Called when a remote peer closes a stream. */
    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream){
        print("didRemove stream====================")
    }
    
    
    /** Called when negotiation is needed, for example ICE has restarted. */
    public func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection){
        print("peerConnectionShouldNegotiate====================")
    }
    
    
    /** Called any time the IceConnectionState changes. */
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState){
        print("didChange1 newState====================\(newState.rawValue)")
        
        switch newState {
        case .connected:
            print("==========connected==========")
        case .disconnected:
            print("==========disconnected==========")
        default:
            break
        }
        
    }
    
    
    /** Called any time the IceGatheringState changes. */
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState){
        print("didChange2====================\(newState.rawValue)")
    }
    
    
    /** New ice candidate has been found. */
    public func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate){
        
        if let delegate = self.delegate {
            
            delegate.webRTCTool(webRTCTool: self, didGenerateIceCandidate: candidate)
        }
    }
    
    
    /** Called when a group of local Ice candidates have been removed. */
    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]){
        print("didRemove candidates====================")
    }
    
    
    /** New data channel has been opened. */
    public func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel){
        print("didOpen====================")
    }

}
