//
//  CylinderSpeedBooster.swift
//  
//
//  Created by IUILAB on 2017/1/22.
//
//

import Foundation
import CoreLocation

class CylinderSpeedBooster{
    fileprivate var _updateRate: Float = 0.1
    fileprivate var _radius: Float = 3.0
    fileprivate var _velocity: Float = 1.0
    fileprivate var _cylinderCenter: CLLocationCoordinate2D = kCLLocationCoordinate2DInvalid
    fileprivate var placeChecker: CircularLocationTransform = CircularLocationTransform()
    fileprivate var prevTime: Date = Date()
    fileprivate var isPathRevising: Bool = false
    fileprivate var isStartMoving: Bool = false
    var forSphereUsing: Bool = true
    
    fileprivate var initGPS: CLLocationCoordinate2D? = kCLLocationCoordinate2DInvalid
    var radius: Float {
        get{
            return self._radius
        }
        set{
            if newValue > 2 {
                if newValue > 15 {
                    self._radius = 15
                }
                else {
                    self._radius = newValue
                }
                placeChecker.radius = Double(self._radius)
//                print("radius has set To : \(self.radius)")
            }else{
                if forSphereUsing {
                    self._radius = newValue
                }else{
                    self._radius = 2.0
                    placeChecker.radius = Double(self._radius)
                }
                
            }
        }
    }
    var velocity:Float {
        get{
            if forSphereUsing {
                if self._velocity * radTrans(radVal: Double(self._velocity / self.radius)) * updateRate < 15 {
                    return self._velocity
                }else{
                    return 0
                }
            }else{
                return self._velocity
            }
        }
        set{
            if radTrans(radVal:Double(newValue / self.radius)) * newValue * updateRate < 15 {
                self._velocity = newValue
            }else{
                self._velocity = 1
            }
        }
    }
    var cylinderCenter: CLLocationCoordinate2D{
        get{
            return self._cylinderCenter
        }
        set{
            if newValue.latitude < 90 && newValue.longitude < 180 && newValue.latitude > -90 && newValue.longitude > -180{
                self._cylinderCenter = newValue
                placeChecker.center = self._cylinderCenter
            }
        }
    }
    
    var updateRate: Float{
        get{
            return _updateRate
        }
        set{
            if newValue > 0.04 && newValue < 0.2 {
                self._updateRate = newValue
            }
        }
    }
    
    var rotateSpeed: Double {
        get{
            if forSphereUsing {
                if self._velocity * radTrans(radVal: Double(self.velocity / self.radius)) * updateRate < 15 {
                    return Double(self._velocity / self.radius)
                }else{
                    return 0
                }
            }else{
                return Double(self._velocity / self.radius)
            }
            
        }
    }
    init(radius: Float, velocity: Float, cylinderCenter: CLLocationCoordinate2D) {
        if radius > 2 {
            self.radius = radius
        }
        if velocity > 0 {
            self.velocity = velocity
        }
        self.cylinderCenter = cylinderCenter
    }
    func horizontalTrans(aircraftLocation: CLLocationCoordinate2D, aircraftHeading: Float ,isCW: Bool) -> Dictionary<String, Float> {
        let expectHead: Double = expectHeading(aircraftLocation: initGPS!)
        let locationErr: Bool = isLocationError(aircraftLocation: initGPS!)
        var finResult: Dictionary<String, Float> = ["rotate": 0, "speed": 0, "angle": 0]
//        if locationErr {
//            print("Location Error: now heading to\(toNormalAngle(radTrans(radVal: expectHead)))")
//        }
        if isContinuous() {
            if isPathRevising {
                if !isStartMoving {
                    if isWrongHead(aircraftLocation: initGPS!, aircraftHeading: aircraftHeading) {
                        finResult["rotate"] = toNormalAngle(radTrans(radVal: expectHead))
                        finResult["angle"] = 1
                        isPathRevising = true
                    }else{
                        isPathRevising = false
                    }
                }else{
                    isPathRevising = false
                    isStartMoving = true
                    finResult = isCW ? ["rotate": radTrans(radVal: self.rotateSpeed), "speed": self.velocity, "angle": 0] : ["rotate": -radTrans(radVal: self.rotateSpeed), "speed": -self.velocity, "angle": 0]
                }
            }else{
                if locationErr {
                    print("Location Error")
                }
                isStartMoving = true
                finResult = isCW ? ["rotate": radTrans(radVal: self.rotateSpeed), "speed": self.velocity, "angle": 0] : ["rotate": -radTrans(radVal: self.rotateSpeed), "speed": -self.velocity, "angle": 0]
            }
        }else{
            initGPS = aircraftLocation
            //self.radius = Float(distantCal(spotA: initGPS!, spotB: cylinderCenter))
            if isWrongHead(aircraftLocation: initGPS!, aircraftHeading: aircraftHeading) {
                finResult["rotate"] = toNormalAngle(radTrans(radVal: expectHead))
                finResult["angle"] = 1
                isPathRevising = true
            }else{
                finResult = isCW ? ["rotate": radTrans(radVal: self.rotateSpeed), "speed": self.velocity, "angle": 0] : ["rotate": -radTrans(radVal: self.rotateSpeed), "speed": -self.velocity, "angle": 0]
            }
        }
        return finResult
    }
    
    fileprivate func expectHeading(aircraftLocation: CLLocationCoordinate2D)->Double{
        let calPointA: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: aircraftLocation.latitude, longitude: cylinderCenter.longitude)
        var realHead: Double = 0
        if aircraftLocation.latitude < cylinderCenter.latitude {
            if aircraftLocation.longitude < cylinderCenter.longitude {
                realHead = -Double.pi - asin(-distantCal(spotA: calPointA , spotB: aircraftLocation)/distantCal(spotA: cylinderCenter, spotB: aircraftLocation))
            }else{
                realHead = Double.pi - asin(distantCal(spotA: calPointA , spotB: aircraftLocation)/distantCal(spotA: cylinderCenter, spotB: aircraftLocation))
            }
        }else{
            if aircraftLocation.longitude < cylinderCenter.longitude {
                realHead =  asin(-distantCal(spotA: calPointA , spotB: aircraftLocation)/distantCal(spotA: cylinderCenter, spotB: aircraftLocation))
            }else{
                realHead = asin(distantCal(spotA: calPointA , spotB: aircraftLocation)/distantCal(spotA: cylinderCenter, spotB: aircraftLocation))
            }
        }
        return realHead
    }
    fileprivate func isLocationError(aircraftLocation:CLLocationCoordinate2D)->Bool{
        let expectPlace: CLLocationCoordinate2D = placeChecker.findCirclePoint(radian: expectHeading(aircraftLocation: aircraftLocation))
        if distantCal(spotA: expectPlace, spotB: aircraftLocation) < 2 || abs(distantCal(spotA: self.cylinderCenter, spotB: aircraftLocation) - Double(self.radius)) < 1 {
            return false
        }else{
            return true
        }
    }
    fileprivate func isContinuous()-> Bool{
        let currentTime: Date = Date()
        let result = (currentTime.timeIntervalSince(prevTime) < 0.15) ? true : false
        prevTime = currentTime
        if !result {
            isPathRevising = false
            isStartMoving = false
        }
        return result
    }
    //if inertia bring the aircraft out the circle
//    fileprivate func revisePath(aircraftLocation: CLLocationCoordinate2D, isCW: Bool) -> Dictionary<String, Float>{
//        
//    }
    fileprivate func isWrongHead(aircraftLocation:CLLocationCoordinate2D, aircraftHeading: Float)-> Bool{
        let aircraftCont: Float = aircraftHeading < 0 ? (aircraftHeading + 360) : aircraftHeading
        var expectCont: Float = toNormalAngle(radTrans(radVal: expectHeading(aircraftLocation: aircraftLocation)))
        expectCont = expectCont < 0 ? (expectCont + 360) : expectCont
        
//        print("AC Heading: " + String(aircraftCont))
//        print("expect Heading: " + String(expectCont))
        
        if abs(aircraftCont - expectCont) < radTrans(radVal:rotateSpeed) * updateRate {
            return false
        }else if abs(aircraftCont - expectCont) > (360 - radTrans(radVal:rotateSpeed) * updateRate){
            return false
        }else{
            return true
        }

    }
    fileprivate func wrongHeadingRevise(){
        
    }
    
    fileprivate func distantCal(spotA: CLLocationCoordinate2D, spotB: CLLocationCoordinate2D)-> Double{
        let tempLocationA:CLLocation = CLLocation(latitude: spotA.latitude, longitude: spotA.longitude)
        let tempLocationB: CLLocation = CLLocation(latitude: spotB.latitude, longitude: spotB.longitude)
        return tempLocationA.distance(from: tempLocationB)
    }
    fileprivate func radTrans(radVal:Double) -> Float{
        return Float(radVal * 180 / Double.pi)
    }
    fileprivate func degTrans(degVal:Float) -> Double{
        return Double(Double(degVal) * Double.pi / 180);
    }
    fileprivate func toNormalAngle(_ angle: Float) -> Float{
        var nVal:Float = angle > 0 ? (angle + 180) : (angle - 180)
        if nVal > 180 {
            nVal = nVal - 360 * round(nVal/360)
        }else if nVal < -180 {
            nVal = nVal + 360 * round(abs(nVal/360))
        }
        return nVal
    }

}
