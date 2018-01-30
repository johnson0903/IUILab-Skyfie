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
    
    private var radius: Double
    private let updateRate = 0.1 // 1 次 0.1秒
    private var currentVerticalAngle = 0.0
    private var angularVelocity = 1.0
    
    private var singleVelocityTrans: Double {
        return self.currentVerticalAngle + (self.angularVelocity * self.updateRate / self.radius / 2)
    }
    
    init() {
        self.radius = 5.0
    }
    
    func getVerticalMovement(isMoveUp: Bool, aircraftAltitude: Float) -> DJIVirtualStickFlightControlData {
        
        var ctrlData = DJIVirtualStickFlightControlData()
        self.currentVerticalAngle = self.getElevation(aircraftAltitude: aircraftAltitude)
        
        if isMoveUp {
            if self.currentVerticalAngle < (Double.pi/2) && self.currentVerticalAngle >= 0 {
                ctrlData.verticalThrottle = Float(self.angularVelocity * cos(self.singleVelocityTrans))
                ctrlData.roll = Float(self.angularVelocity * sin(singleVelocityTrans))
            } else {
                
            }
        } else {
            
        }
        return ctrlData
    }
    
    private func getElevation(aircraftAltitude: Float) -> Double {
        return asin(Double(aircraftAltitude - 1.5) / self.radius)
    }
}
