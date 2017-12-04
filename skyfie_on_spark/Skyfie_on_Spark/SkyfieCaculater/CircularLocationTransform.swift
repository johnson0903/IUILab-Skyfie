//
//  CircularLocationTransform.swift
//  placeCalculator
//
//  Created by IUILAB on 2016/11/8.
//  Copyright © 2016年 IUILAB. All rights reserved.
//

// with accuracy of 6 digit GPS accuracy is 11.1cm
import Foundation
import CoreLocation

class CircularLocationTransform {
    private var _center: CLLocationCoordinate2D? = kCLLocationCoordinate2DInvalid
    private var curRadius: Double = 4.0
    private let earthRadius: Double = 6378137
    
    var center: CLLocationCoordinate2D{
        get {
            return _center!
        }
        set {
            if CLLocationCoordinate2DIsValid(newValue) {
                _center = newValue
            }
        }
    }
    
    var radius: Double{
        get {
            return curRadius
        }
        set {
            if newValue > 15 {
                curRadius = 15.0
            }
            else if newValue < 2 {
                curRadius = 2.0
            }
            else {
                curRadius = newValue
            }
        }
    }
    
    private var lonModified: Double{
        get {
            return cos(degTrans(degVal: Float((center.latitude))))
        }
    }
    
    
    func findCirclePoint(radian: Double) -> CLLocationCoordinate2D {
        return changeCircleRadius(radian: radian, radius: curRadius)
    }
    
    func findSpherePoint(radian: Double, tiltAngle: Double) -> CLLocationCoordinate2D{
        return changeCircleRadius(radian: radian, radius: curRadius*cos(tiltAngle))
    }
    
    private func changeCircleRadius(radian: Double, radius: Double) -> CLLocationCoordinate2D{
        let moidfiedDegree :Dictionary<String, Double> = meterToGPS(distY: (radius*cos(radian)),distX: (radius*sin(radian)))
        let newPoint : CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: center.latitude + moidfiedDegree["lat"]!, longitude: center.longitude + moidfiedDegree["lon"]!);
        return newPoint
    }
    
    private func meterToGPS(distY: Double, distX: Double) -> Dictionary<String, Double>{
        return ["lat": (180/Double.pi)*(distY/earthRadius), "lon": (180/Double.pi)*(distX/(earthRadius * lonModified))]
    }
    private func radTrans(radVal:Double) -> Float{
        return Float(radVal * 180 / Double.pi)
    }
    private func degTrans(degVal:Float) -> Double{
        return Double(Double(degVal) * Double.pi / 180);
    }

    
}

