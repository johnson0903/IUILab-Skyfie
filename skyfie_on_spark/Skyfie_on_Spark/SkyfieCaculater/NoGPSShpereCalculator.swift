//
//  NoGPSShpereCalculator.swift
//  Skyfie_on_Spark
//
//  Created by iMac on 2018/1/30.
//  Copyright © 2018年 康平. All rights reserved.
//

import Foundation
import DJISDK
class NoGPSSphereCalculator {
    
    private var radius: Float
    private let updateRate = 0.1 // 1 次 0.1秒
    private var currentVerticalAngle = 0.0
    private var angularVelocity = 1.0
    
    private func getCurrentVerticalAngle(aircraftAltitude: Float) -> Float {
        return asin((aircraftAltitude - 1.5) / radius)
    }
    
    init() {
        self.radius = 5.0
    }
    
    func getVerticalMovement(isMoveUp: Bool, aircraftAltitude: Float) -> DJIVirtualStickFlightControlData {
        
        var ctrlData = DJIVirtualStickFlightControlData()
        self.currentVerticalAngle = Double(self.getCurrentVerticalAngle(aircraftAltitude: aircraftAltitude))
        
        if isMoveUp { // move up
            if self.currentVerticalAngle < (Double.pi/2) && self.currentVerticalAngle >= 0 {
                ctrlData.verticalThrottle = Float(self.angularVelocity * cos(self.currentVerticalAngle))
                ctrlData.roll = Float(self.angularVelocity * sin(self.currentVerticalAngle))
            } else {
                ctrlData.verticalThrottle = 0.0
                ctrlData.roll = 0.0
            }
        } else { //move down
            if self.currentVerticalAngle < (Double.pi/2) && self.currentVerticalAngle >= 0 {
                ctrlData.verticalThrottle = -Float(self.angularVelocity * cos(self.currentVerticalAngle))
                ctrlData.roll = -Float(self.angularVelocity * sin(self.currentVerticalAngle))
            } else {
                ctrlData.verticalThrottle = 0.0
                ctrlData.roll = 0.0
            }
        }
        return ctrlData
    }

}
