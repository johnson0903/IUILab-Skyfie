//
//  MotionAnalyzer.swift
//  FlyHighHigh
//
//  Created by iuilab on 2016/7/4.
//  Copyright © 2016年 iuilab. All rights reserved.
//

import Foundation
import CoreMotion

class MotionAnalyzer {
    private var currentMotion = ["x": 0.0, "y":0.0, "z": 0.0]
    private var initMotion = ["x": 0.0, "y":0.0, "z": 0.0]
    private var rate = 0.0
    private var prevUserMotion = 0.0
    var lowpassRate: Double{
        get{
            return rate
        }
        set{
            if newValue > 0.0 {
                rate = newValue
            }
        }
    }
    init(lopaRate:Double){
        if lopaRate > 0.0 {
            rate = lopaRate
        }
    }
    
    func translate(sensorData: CMDeviceMotion) -> FlyCommand {
        var rCommand: FlyCommand = FlyCommand()
        var cleanCurrentPosi = ["x": filt(rawVal: sensorData.gravity.x, preVal: currentMotion["x"]!, rate: self.rate), "y":filt(rawVal: sensorData.gravity.y, preVal: currentMotion["y"]!, rate: self.rate), "z": filt(rawVal: sensorData.gravity.z, preVal: currentMotion["z"]!, rate: self.rate)]
        var offsetMotion = ["x": cleanCurrentPosi["x"]! - initMotion["x"]!, "y": cleanCurrentPosi["y"]! - initMotion["y"]!, "z": cleanCurrentPosi["z"]! - initMotion["z"]!]
        let cleanUserMotion = filt(rawVal: sensorData.userAcceleration.y, preVal: prevUserMotion, rate: 0.4)
        //print("offset: ", offsetMotion["z"], ", init: ", initMotion["z"], "current: ", cleanCurrentPosi["z"], "raw: ", sensorData.gravity.z)
        if offsetMotion["x"]! > 0.1 {
            rCommand.right = Float(abs(linearMapping(rawVal: offsetMotion["x"]!)))
        }else if offsetMotion["x"]! < -0.1 {
            rCommand.left = Float(abs(linearMapping(rawVal: offsetMotion["x"]!)))
        }
        if offsetMotion["z"]! > 0.1  {
            rCommand.back = Float(abs(linearMapping(rawVal: offsetMotion["z"]!)))
            //print("pitch: ", sensorData.attitude.pitch, "gravityZ: ", sensorData.gravity.z)
        }else if offsetMotion["z"]! < -0.1 {
            rCommand.front = Float(abs(linearMapping(rawVal: offsetMotion["z"]!)))
            //print("pitch: ", sensorData.attitude.pitch, "gravityZ: ", sensorData.gravity.z)
        }
        if rCommand.front > 5 || rCommand.back > 5{
            if rCommand.left < 4 {
                rCommand.left = 0
            }
            if rCommand.right < 4 {
                rCommand.right = 0
            }
        }
        if rCommand.left > 4 || rCommand.right > 4 {
            if rCommand.front < 2 {
                rCommand.front = 0
            }
            if rCommand.back < 6 {
                rCommand.back = 0
            }
        }
        currentMotion = cleanCurrentPosi
        prevUserMotion = cleanUserMotion
        return rCommand
    }
    
    func setInitMotion(firstMotion: Dictionary<String, Double>, secondMotion:Dictionary<String, Double>) -> Void {
        //initMotion = ["x":filt(x,preVal:0.0, rate:0.8), "y":y, "z":filt(z,preVal:0.0, rate:0.8)]
        initMotion = ["x":filt(rawVal: secondMotion["x"]!,preVal:firstMotion["x"]!, rate:0.5), "y":filt(rawVal: secondMotion["y"]!,preVal:firstMotion["y"]!, rate:0.5), "z":filt(rawVal: secondMotion["z"]!,preVal:firstMotion["z"]!, rate:0.5)]
        currentMotion = initMotion
    }
    
    func clearData() -> Void {
        currentMotion = ["x": 0.0, "y":0.0, "z": 0.0]
        initMotion = ["x": 0.0, "y":0.0, "z": 0.0]
        prevUserMotion = 0.0
    }
    
    private func filt(rawVal: Double, preVal: Double, rate: Double) -> Double {
        return preVal*(1.0-rate) + rawVal * rate
    }
    
    private func linearMapping(rawVal:Double) -> Float{
        return Float(round(rawVal*15))
    }
    
}
