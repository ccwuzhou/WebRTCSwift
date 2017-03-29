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
private let WEBRTC_VIDEO_CODEC = "H264"

private enum WebRTCStreamTrackID : String {
    case mediaStream = "ARDAMS"
    case videoTrack = "ARDAMSv0"
    case audioTrack = "ARDAMSa0"
}

protocol WebRTCToolDelegate : NSObjectProtocol {
    
    func webRTCTool(webRTCTool: WebRTCTool, didGenerateIceCandidate candidate: RTCIceCandidate)
}


class WebRTCTool: NSObject {

    // MARK: -公有属性
    /// 单例
    static let shared = WebRTCTool()
    /// delegate
    public var delegate : WebRTCToolDelegate?
    
    // 本地
    var localVideoView : RTCEAGLVideoView?
    var localVideoTrack : RTCVideoTrack?
    
    // 远程
    var remoteVideoView : RTCEAGLVideoView?
    var remoteVideoTrack : RTCVideoTrack?
    
    // MARK: -私有属性
    fileprivate var mediaStream : RTCMediaStream!
    
    /// p2p连接工具
    fileprivate var peerConnectionFactory : RTCPeerConnectionFactory!
    
    /// p2p连接
    fileprivate var peerConnection : RTCPeerConnection?
    
    // peerConnection参数
    fileprivate lazy var configuration : RTCConfiguration = {
        
        let iceServer = RTCIceServer(urlStrings: [STUN_SERVER_URL])
        
        let config = RTCConfiguration()
        config.iceServers = [iceServer]
        config.iceTransportPolicy = .all
        
        return config
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
    public func startEngine() {
        
        RTCInitializeSSL()
        
        self.peerConnectionFactory = RTCPeerConnectionFactory()
    }
    
    public func stopEngine() {
        
        RTCCleanupSSL()
        
        self.peerConnectionFactory = nil
    }
    
    // 断开连接后清除
    public func cleanCache() {
        
        UIApplication.shared.isIdleTimerDisabled = false
        
        self.peerConnection = nil
        
        self.localVideoView?.removeFromSuperview()
        self.localVideoView = nil
        self.localVideoTrack = nil
        
        self.remoteVideoView?.removeFromSuperview()
        self.remoteVideoView = nil
        self.remoteVideoTrack = nil
    }
    
    public func addICECandidata(sdp: String, sdpMLineIndex: Int32, sdpMid: String) {
        
        guard let peerConnection = self.peerConnection else { return }
        
        peerConnection.add(RTCIceCandidate(sdp: sdp, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid))
    }

    /// 创建本地流
    public func initRTCSetting(remoteViewFrame: CGRect, localViewFrame: CGRect, superView : UIView) {
        
        // peer connect
        let peerConnection = self.peerConnectionFactory.peerConnection(with: self.configuration, constraints: self.peerConnectionConstraints, delegate: self)
        
        // local media stream
        self.mediaStream = self.peerConnectionFactory.mediaStream(withStreamId: WebRTCStreamTrackID.mediaStream.rawValue)

        // camera 权限
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
        
        self.localVideoTrack = self.peerConnectionFactory.videoTrack(with: videoSource, trackId: WebRTCStreamTrackID.videoTrack.rawValue)
        self.mediaStream.addVideoTrack(self.localVideoTrack!)
        
        // add audio track
        let audioTrack = self.peerConnectionFactory.audioTrack(withTrackId: WebRTCStreamTrackID.audioTrack.rawValue)
        self.mediaStream.addAudioTrack(audioTrack)
        
        // add to peerconnection
        peerConnection.add(self.mediaStream)
        
        // add remote video view
        self.remoteVideoView = RTCEAGLVideoView(frame: remoteViewFrame)
        superView.insertSubview(self.remoteVideoView!, at: 0)
        self.peerConnection = peerConnection
        
        // add local video view
        self.localVideoView = RTCEAGLVideoView(frame: localViewFrame)
        superView.insertSubview(self.localVideoView!, at: 1)
        self.localVideoTrack?.add(self.localVideoView!)
        
    }
    /// 创建offer
    public func createOffer(completionHandler: ((_ sdp: String)->())?) {
    
        guard let peerConnection = self.peerConnection else { return }
        
        peerConnection.offer(for: self.offerOrAnswerConstraints) {[weak self] (sessionDescription, error) in
            
            if let error = error {
            
                print(error)
                return
            }
            self?.p_setLocalDescription(sessionDescription: sessionDescription, completionHandler: completionHandler)
        }
    }
    
    /// 设置远程sdp
    public func setRemoteDescription(type: RTCSdpType, sdp: String, completionHandler: ((_ sdp: String)->())?) {
        
        guard let peerConnection = self.peerConnection else { return }
        
        let remoteSdp = RTCSessionDescription(type: type, sdp: sdp)
        
        let newSdp = self.p_sessionDescripteion(description: remoteSdp, preferredVideoCodec: WEBRTC_VIDEO_CODEC)
        
        peerConnection.setRemoteDescription(newSdp) {[weak self] (error) in
            
            if let error = error {
            
                print(error)
                return
            }
            
            if type != .offer {
                return
            }
            
            self?.peerConnection?.answer(for: (self?.offerOrAnswerConstraints)!, completionHandler: {[weak self] (sessionDescription, error) in
                
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

    /// 设置本地sdp
    fileprivate func p_setLocalDescription(sessionDescription: RTCSessionDescription?, completionHandler: ((_ sdp: String)->())?) {
    
        guard let sdp = sessionDescription else {
            return
        }
        
        guard let peerConnection = self.peerConnection else { return }
        
        let newSdp = self.p_sessionDescripteion(description: sdp, preferredVideoCodec: WEBRTC_VIDEO_CODEC)
        
        peerConnection.setLocalDescription(newSdp) {[weak self] (error) in
            
            if let handle = completionHandler {
            
                if let sdpString = self?.peerConnection?.localDescription?.sdp {
                    handle(sdpString)
                }
            }
        }
    }
    /// sdp 转换
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
        print("==didChange RTCSignalingState==\(stateChanged.rawValue)")
    }
    
    
    /** Called when media is received on a new stream from remote peer. */
    public func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream){
        print("==didAdd stream==")
        
        self.remoteVideoTrack = nil
        self.remoteVideoView?.renderFrame(nil)
        if stream.videoTracks.count == 0 {
            return;
        }
        self.remoteVideoTrack = stream.videoTracks[0]
        
        self.remoteVideoTrack?.add(self.remoteVideoView!)
    }
    
    
    /** Called when a remote peer closes a stream. */
    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream){
        print("==didRemove stream==")
    }
    
    
    /** Called when negotiation is needed, for example ICE has restarted. */
    public func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection){
        print("==peerConnectionShouldNegotiate==")
    }
    
    
    /** Called any time the IceConnectionState changes. */
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState){

        switch newState {
        case .connected:
            print("==connected==")
            UIApplication.shared.isIdleTimerDisabled = true
        case .disconnected:
            print("==disconnected==")
        case .closed:
            print("==closed==")
        case .failed:
            print("==failed==")
        default:
            break
        }
    }
    
    
    /** Called any time the IceGatheringState changes. */
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState){
        print("==didChange RTCIceGatheringState==\(newState.rawValue)")
    }
    
    
    /** New ice candidate has been found. */
    public func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate){
        
        print("==didGenerate RTCIceCandidate==")
        
        if let delegate = self.delegate {
            
            delegate.webRTCTool(webRTCTool: self, didGenerateIceCandidate: candidate)
        }
    }
    
    
    /** Called when a group of local Ice candidates have been removed. */
    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]){
        print("==didRemove candidates==")
    }
    
    
    /** New data channel has been opened. */
    public func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel){
        print("==didOpen dataChannel==")
    }

}
