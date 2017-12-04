//
//  FPVView.swift
//  DJI_DPControl
//
//  Created by 康平 on 2017/1/30.
//  Copyright © 2017年 康平. All rights reserved.
//

import UIKit

protocol FPVViewDelegate: NSObjectProtocol {
//    func headingShouldCalibrate()
    func framingTuningfor(_ direction: String)
    func framingTuningEnd()
}

class FPVView: UIView, UIGestureRecognizerDelegate {
    weak var delegate: FPVViewDelegate? = nil
//    var flag_isHeadingOK: Bool = false
    var originTouchLocation: CGPoint = CGPoint()

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupGesture()
    }
    
    func setupGesture() {
        let swipeFinder: UIPanGestureRecognizer = UIPanGestureRecognizer(target: self , action: #selector(gestureHandler(_:)))
        swipeFinder.delegate = self
        self.addGestureRecognizer(swipeFinder)
    }
    
    @objc func gestureHandler(_ gesture: UIGestureRecognizer) {
        if let swipeGesture = gesture as? UIPanGestureRecognizer {
            if swipeGesture.state == UIGestureRecognizerState.began {
                self.originTouchLocation = swipeGesture.location(in: self)
                
//                if !flag_isHeadingOK {
//                    self.delegate?.headingShouldCalibrate()
//                }
            }
            if swipeGesture.state == UIGestureRecognizerState.changed {
//                if flag_isHeadingOK {
                    let newTouchLocation = swipeGesture.location(in: self)
                    
                    // judge the direciton of movement
                    if newTouchLocation.x - originTouchLocation.x > (self.superview?.frame.maxX)!/20 { // Right
                        self.delegate?.framingTuningfor("Right")
//                        print("Right")
                    }
                    else if newTouchLocation.x - originTouchLocation.x < -(self.superview?.frame.maxX)!/20 { // Left
                        self.delegate?.framingTuningfor("Left")
//                        print("Left")
                    }
                    else { // stay on horizontal direction (neither right nor left)
                        self.delegate?.framingTuningfor("SoH")
                    }
                
                    if newTouchLocation.y - originTouchLocation.y > (self.superview?.frame.maxY)!/32 { // Down
                        self.delegate?.framingTuningfor("Down")
//                        print("Down")
                    }
                    if newTouchLocation.y - originTouchLocation.y < -(self.superview?.frame.maxY)!/32 { // Up
                        self.delegate?.framingTuningfor("Up")
//                        print("Up")
                    }
//                }
            }
            if swipeGesture.state == UIGestureRecognizerState.ended {
                self.delegate?.framingTuningEnd()
            }
        }
    }
}
