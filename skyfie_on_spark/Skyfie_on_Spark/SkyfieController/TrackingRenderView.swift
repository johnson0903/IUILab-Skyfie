//
//  TrackRenderView.swift
//  Skyfie_on_Spark
//
//  Created by 李嘉晟 on 2017/11/7.
//  Copyright © 2017年 康平. All rights reserved.
//

import UIKit

@objc protocol TrackingRenderViewDelegate: NSObjectProtocol {
    func renderViewDidTouchAtPoint(point: CGPoint)
    @objc func renderViewDidMoveToPoint(endPoint: CGPoint, fromPoint startPoint: CGPoint, isFinished finished: Bool)
}

class TrackingRenderView: UIView {

    var delegate: TrackingRenderViewDelegate?
    var trackingRect: CGRect?
    var isDottedLine: Bool?
    var text: NSString?
    
    var fillColor: UIColor?
    var startPoint: CGPoint?
    var endPoint: CGPoint?
    var isMoved: Bool = false
    
    let TEXT_RECT_WIDTH: CGFloat = 40
    let TEXT_RECT_HEIGHT: CGFloat = 40
    
    //MARK - UIResponder Methods
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        self.isMoved = false
        self.startPoint = touches.first?.location(in: self)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.isMoved = true
        self.endPoint = touches.first?.location(in: self)
        if self.delegate != nil && (self.delegate?.responds(to: #selector(self.delegate?.renderViewDidMoveToPoint(endPoint:fromPoint:isFinished:))))! {
            self.delegate?.renderViewDidMoveToPoint(endPoint: self.endPoint!, fromPoint: self.startPoint!, isFinished: false)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.endPoint = touches.first?.location(in: self)
        if self.isMoved {
            if self.delegate != nil && (self.delegate?.responds(to: #selector(self.delegate?.renderViewDidMoveToPoint(endPoint:fromPoint:isFinished:))))! {
                self.delegate?.renderViewDidMoveToPoint(endPoint: self.endPoint!, fromPoint: self.startPoint!, isFinished: true)
            }
        }
        else {
            if self.delegate != nil && (self.delegate?.responds(to: #selector(self.delegate?.renderViewDidTouchAtPoint(point:))))! {
                self.delegate?.renderViewDidTouchAtPoint(point: self.startPoint!)
            }
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.endPoint = touches.first?.location(in: self)
        if self.isMoved {
            if self.delegate != nil && (self.delegate?.responds(to: #selector(self.delegate?.renderViewDidMoveToPoint(endPoint:fromPoint:isFinished:))))! {
                self.delegate?.renderViewDidMoveToPoint(endPoint: self.endPoint!, fromPoint: self.startPoint!, isFinished: true)
            }
        }
    }
    
    func updateRect(rect: CGRect, fillColor: UIColor){
        if rect == self.trackingRect {
            return
        }
        self.fillColor = fillColor
        self.trackingRect = rect
        self.setNeedsDisplay()
    }
    
    func setText(text: NSString) {
        if self.text == text{
            return
        }
        self.text = text
        self.setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        if self.trackingRect == nil {
            return
        }
        var context: CGContext? = UIGraphicsGetCurrentContext()
        let strokeColor: UIColor = UIColor.gray
        context?.setStrokeColor(strokeColor.cgColor)
        let fillColor = self.fillColor!
        context?.setFillColor(fillColor.cgColor)
        context?.setLineWidth(1.8)
        
        if self.isDottedLine! {
            let lengths: [CGFloat] = [10, 10]
            context?.setLineDash(phase: 0, lengths: lengths)
        }
        
        context?.addRect(self.trackingRect!)
        context?.drawPath(using: .fillStroke)
        
        if self.text != nil {
            let origin_x = (self.trackingRect?.origin.x)! + 0.5*(self.trackingRect?.size.width)! - 0.5*TEXT_RECT_WIDTH
            let origin_y = (self.trackingRect?.origin.y)! + 0.5*(self.trackingRect?.size.height)! - 0.5*TEXT_RECT_HEIGHT
            let textRect = CGRect(x: origin_x, y: origin_y, width: TEXT_RECT_WIDTH, height: TEXT_RECT_HEIGHT)
            let paragraphStyle: NSMutableParagraphStyle = NSMutableParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
            paragraphStyle.lineBreakMode = .byCharWrapping
            paragraphStyle.alignment = .center
            let font = UIFont.boldSystemFont(ofSize: 35)
            var dic: Dictionary<NSAttributedStringKey, Any> = [:]
            dic = [.font: font, .paragraphStyle: paragraphStyle, .foregroundColor: UIColor.white]
            self.text?.draw(in: textRect, withAttributes: dic)
        }
    }
}
