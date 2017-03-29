//
//  WebRTCTipView.swift
//  WebRTCSwift
//
//  Created by wwz on 2017/3/29.
//  Copyright © 2017年 apple. All rights reserved.
//

import WWZSwift

protocol WebRTCTipViewDelegate : NSObjectProtocol{
    
    func tipView(tipView: WebRTCTipView, didClickButtonAtIndex index: Int)
}

private let WebRTCTipView_BUTTON_TAG = 99

class WebRTCTipView: WWZShowView {

    var delegate : WebRTCTipViewDelegate?
    
    override init(frame: CGRect) {
        
        super.init(frame: frame)
        
        self.setContentView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setContentView() {
        
        self.isTapEnabled = false
        
        self.layer.wwz_setCorner(radius: 20.0)
        
        // top
        let topView = UIView(frame: CGRect(x: 0, y: 0, width: self.width, height: 188), backgroundColor: UIColor.colorFromRGBA(rgba: 0x66bdf6))
        self.addSubview(topView)
        
        let imageView = UIImageView(image: UIImage(named: "ring"))
        topView.addSubview(imageView)
        
        imageView.wwz_alignCenterX()
        imageView.centerY = topView.height*0.4
        
        let titleLabel = UILabel(frame: CGRect.zero, text: "可视门铃", font: UIFont.systemFont(ofSize: 15), tColor: UIColor.white, alignment: .center, numberOfLines: 1)
        titleLabel.sizeToFit()
        topView.addSubview(titleLabel)
        
        titleLabel.wwz_alignCenterX()
        titleLabel.y = imageView.bottom+5
        
        // button
        let acceptButton = UIButton(frame: CGRect.zero, nTitle: "接受", titleFont: UIFont.systemFont(ofSize: 16), nColor: UIColor.white)
        self.addSubview(acceptButton)
        
        acceptButton.tag = WebRTCTipView_BUTTON_TAG+0
        acceptButton.wwz_setNBImage("accept", hBImage: "accept_highlighted", sBImage: nil)
        acceptButton.sizeToFit()
        acceptButton.wwz_alignCenterX()
        acceptButton.centerY = (self.height-topView.height)*0.3+topView.bottom
        acceptButton.wwz_setTarget(self, action: #selector(WebRTCTipView.clickButtonAtIndex(sender:)))
        
        
        let refuseButton = UIButton(frame: CGRect.zero, nTitle: "拒绝", titleFont: UIFont.systemFont(ofSize: 16), nColor: UIColor.white)
        self.addSubview(refuseButton)
        
        refuseButton.tag = WebRTCTipView_BUTTON_TAG+1
        refuseButton.wwz_setNBImage("reject", hBImage: "reject_highlighted", sBImage: nil)
        refuseButton.sizeToFit()
        refuseButton.wwz_alignCenterX()
        refuseButton.centerY = (self.height-topView.height)*0.7+topView.bottom
        refuseButton.wwz_setTarget(self, action: #selector(WebRTCTipView.clickButtonAtIndex(sender:)))
    }
    
    @objc private func clickButtonAtIndex(sender: UIButton) {
        
        self.wwz_dismiss(completion: nil)
        
        if let delegate = self.delegate {
            
            delegate.tipView(tipView: self, didClickButtonAtIndex: sender.tag-WebRTCTipView_BUTTON_TAG)
        }
    }
}
