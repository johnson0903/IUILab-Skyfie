//
//  SphereSpeedGenerator.swift
//  placeCalculator
//
//  Created by IUILAB on 2017/1/20.
//  Copyright © 2017年 IUILAB. All rights reserved.
//

import Foundation
import CoreLocation

class SphereSpeedGenerator{
    private var _updateRate: Float = 0.1 //更新週期 (1次 0.1秒, 頻率10Hz)
    private var _radius: Float = 3.0
    private var _angularVelocity: Float = 1.0
    private var _sphereCenter: CLLocationCoordinate2D = kCLLocationCoordinate2DInvalid
    private var _accumVerticalAngle: Double = 0.0 //上下移動累積已移動的角度
    private var horizontalTrack: CylinderSpeedBooster?
    private var prevTime: Date = Date()
    private var velocityAdjust: Date = Date()
    private var horizontalChecker: CircularLocationTransform = CircularLocationTransform()
    private var isStartMoving: Bool = false
    
    var radius: Float {
        get {
            return self._radius
        }
        set {
            if newValue > 15 {
                self._radius = 15.0
            }
            else if newValue < 2 {
                self._radius = 2.0
            }
            else {
                self._radius = newValue
            }
            horizontalTrack?.radius = self._radius * Float(cos(accumVerticalAngle))
            horizontalChecker.radius = Double(self._radius) * (cos(accumVerticalAngle))
        }
    }
    
    var angularVelocity: Float {
        get {
            return self._angularVelocity
        }
        set {
            if newValue > 0 {
                self._angularVelocity = newValue
                horizontalTrack?.velocity = self._angularVelocity
            }
        }
    }
    
    var sphereCenter: CLLocationCoordinate2D {
        get {
            return self._sphereCenter
        }
        set {
            if CLLocationCoordinate2DIsValid(newValue) {
                self._sphereCenter = newValue
                horizontalTrack?.cylinderCenter = self._sphereCenter
                horizontalChecker.center = self._sphereCenter
            }
        }
    }
    
    var updateRate: Float{
        get {
            return _updateRate
        }
        set {
            //?????
            if newValue > 0.04 && newValue < 0.2 {
                self._updateRate = newValue
                horizontalTrack?.updateRate = self._updateRate
            }
        }
    }
    
    var singleElevationRotate: Double{
        get {
            return Double(self.angularVelocity * self.updateRate / self.radius)
        }
    }
    
    var singleVelocityTrans: Double{
        get {
            return self.accumVerticalAngle + Double(self.angularVelocity * self.updateRate / self.radius / 2)
        }
    }
    
    private var accumVerticalAngle: Double{
        get {
            return _accumVerticalAngle
        }
        set {
            _accumVerticalAngle = newValue
            horizontalTrack?.radius = self.radius * Float(cos(_accumVerticalAngle))
            horizontalChecker.radius = Double(self._radius) * (cos(accumVerticalAngle))
        }
    }
    
    init(radius: Float, velocity: Float, sphereCenter: CLLocationCoordinate2D) {
        if radius > 2 {
            self.radius = radius
        }
        if velocity > 0 {
            self.angularVelocity = velocity
        }
        self.sphereCenter = sphereCenter
        self.horizontalTrack = CylinderSpeedBooster(radius: self.radius, velocity: self.angularVelocity, cylinderCenter: self.sphereCenter)
        horizontalTrack?.forSphereUsing = true
        self.horizontalChecker.center = self.sphereCenter
    }
    
    func horizontalTrans(aircraftLocation: CLLocationCoordinate2D, aircraftHeading: Float, altitude: Float, isCW: Bool)-> Dictionary< String , Float> {
        if !isContinuous() {
            accumVerticalAngle = expectElevation(altitude: altitude )
        }
        return (horizontalTrack?.horizontalTrans(aircraftLocation: aircraftLocation, aircraftHeading: aircraftHeading, isCW: isCW))!
    }
    
    func verticalTrans(aircraftLocation: CLLocationCoordinate2D, aircraftHeading: Float , aircraftAltitude: Float ,up:Bool) -> Dictionary<String, Float> {
        var fineResult: Dictionary<String, Float> = ["rotate": 0, "angle": 0]
//        if !isContinuous() {
//            // if accumVerticalAngle is up to 90 degree last fine tune and this fine tune try to move down
//            if !up && accumVerticalAngle == .pi/2 {
////                accumVerticalAngle = expectElevationByMutiple(aircraftLocation: aircraftLocation, altitude: altitude)
//                isStartMoving = true
//                velocityAdjust = Date()
//            }
//            else {
//                accumVerticalAngle = expectElevationByMutiple(aircraftLocation: aircraftLocation, altitude: aircraftAltitude)
//                print("angle Elevation: \(radTrans(radVal:accumVerticalAngle))")
//                isStartMoving = false
//                //self.radius = sqrt(pow(Float(distantCal(spotA: aircraftLocation, spotB: sphereCenter)), 2)+pow(altitude, 2))
//            }
//        }
//        if !isStartMoving {
//            if distantCal(spotA: aircraftLocation, spotB: sphereCenter) < 0.5 || abs(Double.pi/2 - accumVerticalAngle) < singleElevationRotate {
//                isStartMoving = true
//                velocityAdjust = Date()
//            }
//            else {
//                if isWrongHead(aircraftLocation: aircraftLocation, aircraftHeading: aircraftHeading) {
//                    fineResult["rotate"] = toNormalAngle(radTrans(radVal: expectHeading(aircraftLocation: aircraftLocation)))
//                    fineResult["angle"] = 1
//                }
//                else {
//                    isStartMoving = true
//                    velocityAdjust = Date()
//                }
//            }
//        }
//
//        if isStartMoving {
//            if accumVerticalAngle > Double.pi {
//                accumVerticalAngle = Double.pi
//            }
//            if accumVerticalAngle < 0 {
//                accumVerticalAngle = 0
//            }
//
//            if up {
//                print("accumAngle: \(radTrans(radVal: accumVerticalAngle))")
//                if accumVerticalAngle < Double.pi/2 && accumVerticalAngle >= 0 {
//                    fineResult = ["up": angularVelocity * Float(cos(singleVelocityTrans)), "forward": angularVelocity * Float(sin(singleVelocityTrans)), "angle": 0]
//                }else{
//                    accumVerticalAngle = Double.pi/2
//                    fineResult =  ["up": 0, "forward": 0, "angle": 0]
//                }
//                if accumVerticalAngle < Double.pi/2 {
//                    accumVerticalAngle += singleElevationRotate
//                }
//            }
//            else {
//                print("accumAngle: \(radTrans(radVal: accumVerticalAngle))")
//                if accumVerticalAngle <= Double.pi/2 && accumVerticalAngle > 0 {
//                    fineResult =  ["down": angularVelocity * Float(cos(singleVelocityTrans)), "backward": angularVelocity * Float(sin(singleVelocityTrans)), "angle": 0]
//                }else{
//                    fineResult =  ["down": 0, "backward": 0, "angle": 0]
//                }
//                if accumVerticalAngle > 0 {
//                    accumVerticalAngle -= singleElevationRotate
//                }
//            }
//
//        }
        
        accumVerticalAngle = expectElevationByMutiple(aircraftLocation: aircraftLocation, altitude: aircraftAltitude)
        print("accumVerticalAngle: \(radToDegree(radVal: accumVerticalAngle))")
        if accumVerticalAngle > Double.pi {
            accumVerticalAngle = Double.pi
        }
        if accumVerticalAngle < 0 {
            accumVerticalAngle = 0
        }
        if isWrongHead(aircraftLocation: aircraftLocation, aircraftHeading: aircraftHeading){
            fineResult["rotate"] = toNormalAngle(radToDegree(radVal: expectHeading(aircraftLocation: aircraftLocation)))
            fineResult["angle"] = 1
        } else {
            if up {
                print("up accumAngle: \(radToDegree(radVal: accumVerticalAngle))")
                if accumVerticalAngle < Double.pi/2 && accumVerticalAngle >= 0 {
                    fineResult = ["up": angularVelocity * Float(cos(singleVelocityTrans)), "forward": angularVelocity * Float(sin(singleVelocityTrans)), "angle": 0]
                }
                else {
                    accumVerticalAngle = Double.pi/2
                    fineResult =  ["up": 0, "forward": 0, "angle": 0]
                }
                if accumVerticalAngle < Double.pi/2 {
                    accumVerticalAngle += singleElevationRotate
                }
            }
            else {
                print("down accumAngle: \(radToDegree(radVal: accumVerticalAngle))")
                if accumVerticalAngle <= Double.pi/2 && accumVerticalAngle > 0 {
                    fineResult =  ["down": angularVelocity * Float(cos(singleVelocityTrans)), "backward": angularVelocity * Float(sin(singleVelocityTrans)), "angle": 0]
                }
                    // 當 accumVerticalAngle 大於 ℿ/2 或 小於 0
                else {
                    fineResult =  ["down": 0, "backward": 0, "angle": 0]
                }
                if accumVerticalAngle > 0 {
                    accumVerticalAngle -= singleElevationRotate
                }
            }
        }
        
        return fineResult
    }
    
    private func isContinuous()-> Bool {
        let currentTime: Date = Date()
        let result = (currentTime.timeIntervalSince(prevTime) < 0.15) ? true : false
        prevTime = currentTime
        return result
    }
    
    private func expectHeading(aircraftLocation: CLLocationCoordinate2D) -> Double {
        let calPointA: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: aircraftLocation.latitude, longitude: sphereCenter.longitude)
        var realHead: Double = 0
        if aircraftLocation.latitude < sphereCenter.latitude {
            if aircraftLocation.longitude < sphereCenter.longitude {
                realHead = -Double.pi - asin(-distantCal(spotA: calPointA , spotB: aircraftLocation)/distantCal(spotA: sphereCenter, spotB: aircraftLocation))
            }
            else {
                realHead = Double.pi - asin(distantCal(spotA: calPointA , spotB: aircraftLocation)/distantCal(spotA: sphereCenter, spotB: aircraftLocation))
            }
        }
        else {
            if aircraftLocation.longitude < sphereCenter.longitude {
                realHead =  asin(-distantCal(spotA: calPointA , spotB: aircraftLocation)/distantCal(spotA: sphereCenter, spotB: aircraftLocation))
            }
            else {
                realHead = asin(distantCal(spotA: calPointA , spotB: aircraftLocation)/distantCal(spotA: sphereCenter, spotB: aircraftLocation))
            }
        }
        return realHead
    }
    
    func isWrongHead(aircraftLocation:CLLocationCoordinate2D, aircraftHeading: Float)-> Bool {
        
        // 將飛機原本的 0~180、0~-180 方位換算為 0~360 度
        let aircraftCont: Float = aircraftHeading < 0 ? (aircraftHeading + 360) : aircraftHeading
        var expectCont: Float = toNormalAngle(radToDegree(radVal: expectHeading(aircraftLocation: aircraftLocation)))
        expectCont = expectCont < 0 ? (expectCont + 360) : expectCont
        
        if abs(aircraftCont - expectCont) < radToDegree(radVal:(horizontalTrack?.rotateSpeed)!) * updateRate {
            return false
        }else if abs(aircraftCont - expectCont) > (360 - radToDegree(radVal:(horizontalTrack?.rotateSpeed)!) * updateRate){
            return false
        }else{
            return true
        }
    }

    private func distantCal(spotA: CLLocationCoordinate2D, spotB: CLLocationCoordinate2D)-> Double{
        let tempLocationA:CLLocation = CLLocation(latitude: spotA.latitude, longitude: spotA.longitude)
        let tempLocationB: CLLocation = CLLocation(latitude: spotB.latitude, longitude: spotB.longitude)
        return tempLocationA.distance(from: tempLocationB)
    }
    
    private func expectElevation(altitude: Float)-> Double{
        return asin(Double((altitude - 1.5 ) / self.radius))
    }
    
    private func expectElevationByMutiple(aircraftLocation: CLLocationCoordinate2D, altitude: Float)-> Double{
        let distanceToCenter = distantCal(spotA: aircraftLocation, spotB: sphereCenter)
        
//        return (Float(distanceToCenter) < self.radius && altitude > 1.5 + self.radius / 2) ? acos(distanceToCenter / Double(self.radius)) : expectElevation(altitude: altitude)
        if Float(distanceToCenter) < self.radius && altitude > 1.5 + self.radius / 2 {
            return acos(distanceToCenter / Double(self.radius))
        }
        else {
            return expectElevation(altitude: altitude)
        }
    }
    
    private func radToDegree(radVal:Double) -> Float{
        return Float(radVal * 180 / Double.pi)
    }
    
    private func degreeToRad(degVal:Float) -> Double{
        return Double(Double(degVal) * Double.pi / 180);
    }
    
    private func toNormalAngle(_ angle: Float) -> Float{
        var nVal: Float = angle > 0 ? (angle + 180) : (angle - 180)
        if nVal > 180 {
            nVal = nVal - 360 * round(nVal/360)
        }
        else if nVal < -180 {
            nVal = nVal + 360 * round(abs(nVal/360))
        }
        return nVal
    }
}

