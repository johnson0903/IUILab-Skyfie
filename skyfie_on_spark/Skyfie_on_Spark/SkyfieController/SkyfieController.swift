//
//  SkyfieController.swift
//  DJI_DPControl_RecordVideo
//
//  Created by 康平 on 2017/3/28.
//  Copyright © 2017年 康平. All rights reserved.
//

import Foundation
import CoreLocation
import DJISDK

protocol SkyfieControllerDelegate {
    // Method to notify delegate viewController that some action have been completed
    func aircraftIsTakingOff()
    func didAircraftTakeoff()
    func didAircraftLanding()
    
    func didDirectPointingStartWith(destLocation: CLLocationCoordinate2D, destAltitude: Float)
    func didDirectPointingStop()
    func didDirectPointingEnd()
    func didAircraftHeadingCalibrated()
    func showAlertResultOnView(_ info:String)
}

class SkyfieController: NSObject, DJIFlightControllerDelegate, DJIGimbalDelegate {
    
    // UI buttons state variables
    var isGoStopButtonEnable = true
    var isNearFarButtonEnable = true
    var isZoomButtonEnable = true
    var isFramingButtonEnable = true
    
    var delegate: SkyfieControllerDelegate? = nil
    var aircraft: DJIAircraft
    var currentFCState: DJIFlightControllerState? = nil
    var currentGimbalState: DJIGimbalState? = nil
    
    var aircraftLocation: CLLocationCoordinate2D = kCLLocationCoordinate2DInvalid
    var aircraftAltitude: Double = 5.0
    var aircraftHeading: Double = 0.0
    
    // Direct Pointing Mode related varables
    private var isStartMoveVertical = false
    private var isHorizontalHoverLocationSet = false
    private var previousDestAltitude: Float = 0
    private var previousDestAngle: Double = 0.0
    private var directPointingDestLocation: CLLocationCoordinate2D = kCLLocationCoordinate2DInvalid
    private var directPointingDestAltitude: Float = 0
    private var targetAziumuth: Double? = nil
    private var aziuDiffCounter = 0 // times of expected aziumuth difference
    private var reachTargetCounter = 0 // times of reaching target
    private var directPointingMoveSpeed: Float = 2
    private var headingThreshold: Double = 5
    private var directPointingControlTimer: Timer?
    var circularLocationTransformer: CircularLocationTransform = CircularLocationTransform()
    
    // Fine Tuning movement related varable/class instance
    private var sphereTrackGenerator: SphereSpeedGenerator?
    private var headingCalibrator: CylinderSpeedBooster?
    private var fineTuningControlTimer: Timer?
    private var radiusUpdateTimer: Timer?
    private var hoverLocation: CLLocationCoordinate2D = kCLLocationCoordinate2DInvalid
    private var currentUserHeading: Double = 0
    private var ctrlPitch: Float = 0
    private var ctrlRoll: Float = 0
    private var ctrlVerticalThrottle: Float = 0
    // Used on Framing Tuning left/right rotation
    private var ctrlYaw: Float = 0
    
    // Constant
    // Maxmum and minimum varibles in meter
    let maxAltitude = 15.0
    let minAltitude = 1.5
    let maxRadius = 10.0
    
    // Fine Tuning Speed (m/s)
    private var fineTuningSpeed: Float = 1.0
    private var directPointingRotateSpeed: Float = 1.2
    
    // Framing Tuning Angle for Gimbal Rotation (in degree)
    private var framingTuningAngle: Float = 5
    var pressedFinetuningButtonCount = 0
    private var newFineTuningControlTimer: Timer? = nil
    
    // New finetuning
    private var fineTuningCtrlData = DJIVirtualStickFlightControlData()
    
    // Near Far Move
    private var nearFarMoveTimer: Timer? = nil
    
    // Initiallize method
    init(aircraft: DJIAircraft) {
        self.aircraft = aircraft
        // Set aircraft flight Control parameters
        self.aircraft.flightController?.rollPitchCoordinateSystem = DJIVirtualStickFlightCoordinateSystem.body
        self.aircraft.flightController?.isVirtualStickAdvancedModeEnabled = true
        self.aircraft.flightController?.verticalControlMode = DJIVirtualStickVerticalControlMode.velocity
        self.aircraft.flightController?.yawControlMode = DJIVirtualStickYawControlMode.angularVelocity
        self.aircraft.flightController?.rollPitchControlMode = DJIVirtualStickRollPitchControlMode.velocity
        
        // initialize user center to fix location for study
        self.circularLocationTransformer.center = CLLocationCoordinate2D(latitude: 22.996731, longitude: 120.222870)
        
        // initialize sphereTrackGenerator and headingCalibrator
        sphereTrackGenerator = SphereSpeedGenerator(radius: Float(circularLocationTransformer.radius), velocity: directPointingRotateSpeed, sphereCenter: circularLocationTransformer.center)
        headingCalibrator = CylinderSpeedBooster(radius: Float(circularLocationTransformer.radius), velocity: fineTuningSpeed, cylinderCenter: circularLocationTransformer.center)
        
        super.init()
        self.aircraft.flightController?.delegate = self
        self.aircraft.gimbal?.delegate = self
    }
    
//    func initWith(aircraft: DJIAircraft) {
//        self.aircraft = aircraft
//
//        self.aircraft!.flightController?.delegate = self
//        self.aircraft!.gimbal?.delegate = self
//        // Set aircraft flight Control parameters
//        self.aircraft!.flightController?.rollPitchCoordinateSystem = DJIVirtualStickFlightCoordinateSystem.body
//        self.aircraft!.flightController?.isVirtualStickAdvancedModeEnabled = true
//        self.aircraft!.flightController?.verticalControlMode = DJIVirtualStickVerticalControlMode.velocity
//        self.aircraft!.flightController?.yawControlMode = DJIVirtualStickYawControlMode.angularVelocity
//        self.aircraft!.flightController?.rollPitchControlMode = DJIVirtualStickRollPitchControlMode.velocity
//
//        // initialize user center to fix location for study
//        self.circularLocationTransformer.center = CLLocationCoordinate2D(latitude: 22.996731, longitude: 120.222870)
//
//        // initialize sphereTrackGenerator and headingCalibrator
//        sphereTrackGenerator = SphereSpeedGenerator(radius: Float(circularLocationTransformer.radius), velocity: directPointingRotateSpeed, sphereCenter: circularLocationTransformer.center)
//        headingCalibrator = CylinderSpeedBooster(radius: Float(circularLocationTransformer.radius), velocity: fineTuningSpeed, cylinderCenter: circularLocationTransformer.center)
//    }
    
    // MARK: - States Update Callback Method
    func flightController(_ fc: DJIFlightController, didUpdate state: DJIFlightControllerState) {
        
        if state.flightMode == DJIFlightMode.autoTakeoff || state.flightMode == DJIFlightMode.assistedTakeoff {
            self.delegate?.aircraftIsTakingOff()
        }
        
        self.currentFCState = state
        if(state.aircraftLocation?.coordinate) != nil{
            self.aircraftLocation = (state.aircraftLocation?.coordinate)!
        }
        self.aircraftAltitude = state.altitude
        self.aircraftHeading = state.attitude.yaw
    }
    
    func gimbal(_ gimbal: DJIGimbal, didUpdate state: DJIGimbalState) {
        self.currentGimbalState = state
    }
    
    // MARK: - DJI aircraft general control and mode switch method
    func aircraftTakeoff() {
        if aircraft == nil {
            self.delegate?.showAlertResultOnView("No Aircraft Connected")
            return
        }
        
        self.aircraft.flightController?.startTakeoff(completion: {[weak self] (error: Error?) -> Void in
            if error != nil {
                self?.delegate?.showAlertResultOnView("Takeoff: \(error!)")
            }
            else {
                // calibrate gimbal angle to face to user
                self?.startTimerForHeadingCalibration()
                self?.GimbalAutoTuning()
                self?.delegate?.didAircraftTakeoff()
            }
        })
    }
    
    func aircraftLanding() {
        if self.aircraft == nil {
            self.delegate?.showAlertResultOnView("No Aircraft Connected")
            return
        }
        self.aircraft.flightController?.startLanding(completion: {[weak self] (error: Error?) -> Void in
            if error != nil {
                self?.delegate?.showAlertResultOnView("Landing: \(error!)")
            }
            else {
                self?.delegate?.didAircraftLanding()
            }
        })
    }
    
    func enableVirtualStickControlMode() {
        if self.aircraft == nil {
            self.delegate?.showAlertResultOnView("No Aircraft Connected")
            return
        }
        aircraft.flightController?.setVirtualStickModeEnabled(true, withCompletion: {[weak self] (error: Error?) -> Void in
            if error != nil {
                self?.delegate?.showAlertResultOnView("enableStickControlMode: \(error!.localizedDescription)")
            }
        })
    }
    
    func disableVirtualStickControlMode() {
        if self.aircraft == nil {
            self.delegate?.showAlertResultOnView("No Aircraft Connected")
            return
        }
        aircraft.flightController?.setVirtualStickModeEnabled(false, withCompletion: {[weak self] (error: Error?) -> Void in
            if error != nil {
                self?.delegate?.showAlertResultOnView("disableStickControlMode:\(error!.localizedDescription)")
            }
        })
    }
    // MARK: - Old Direct Pointing Method
    func setDirectPointingDestinationWith(directPointingHeading: CLLocationDirection, userElevation: Double) {
        //         heading and elevation is in degree
        //         safity zone checking
        //         if the radius less than 2m, aircarft is allowed to move backwards only.
        
        //        if findCurrentRealRadiusWith(flightMode: .spherical) < 2 {
        //            self.delegate?.showAlertResultOnView("In safity zone, should push out")
        //            return
        //        }
        
        //if current radius greater than 15 meter shouldn't move
        if findCurrentRealRadiusWith(flightMode: .spherical) > 15 {
            self.delegate?.showAlertResultOnView("dest Location is too far")
            return
        }
        
        directPointingDestLocation = findDestinationPoint(withHeading: directPointingHeading, andElevation: userElevation)
        directPointingDestAltitude = Float(findDestinationAltitudeBy(phonePitchInRadians: userElevation))
        
        print("dest Location: " + String(describing: directPointingDestLocation))
        print("dest altitude: " + String(directPointingDestAltitude))
        
        // if current aircraft location is valid, start perform Direct Pointing
        if CLLocationCoordinate2DIsValid(aircraftLocation) {
            startDirectPointingTimer()
        }
        else { //aircraftLocation is invalid
            self.delegate?.showAlertResultOnView("Current Drone Location Invalid")
        }
    }
    
    func startDirectPointingTimer() {
        if aircraft.flightController?.isVirtualStickControlModeAvailable() == false {
            enableVirtualStickControlMode()
        }
        
        if directPointingControlTimer == nil {
            directPointingControlTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(performDirectPointing), userInfo: nil, repeats: true)
            directPointingControlTimer?.fire()
            self.delegate?.didDirectPointingStartWith(destLocation: directPointingDestLocation, destAltitude: directPointingDestAltitude)
        }
    }
    
    @objc func performDirectPointing() {
        var ctrlData = DJIVirtualStickFlightControlData()
        ctrlData.pitch = 0
        // set aircraft altitude to destination altitude (m)
        aircraft.flightController?.verticalControlMode = DJIVirtualStickVerticalControlMode.position
        ctrlData.verticalThrottle = directPointingDestAltitude
        
        // determine whether target azimuth should change
        let expectedAziumuth = getAzimuthByCoordi(From: aircraftLocation, to: directPointingDestLocation)
        checkTargetAziumuth(expectedAziumuth)
        
        // determine whether aircraft heading should calibrate
        let currentDistance = getDistanceFrom(aircraftLocation, to: directPointingDestLocation)
        
        //if should calibrate aircraft heading
        if shouldHeadingCalibrate(currentDistance) {
            self.delegate?.showAlertResultOnView("Change Heading!")
            // calibrate aircraft heading to target aziumuth
            aircraft.flightController?.yawControlMode = DJIVirtualStickYawControlMode.angle
            
            ctrlData.roll = 0
            if targetAziumuth! > 180 {
                ctrlData.yaw = Float(targetAziumuth!) - 360
            }
            else {
                ctrlData.yaw = Float(targetAziumuth!)
            }
        }
        else { // heading is ok, getting the velocity and go.
            aircraft.flightController?.yawControlMode = DJIVirtualStickYawControlMode.angularVelocity
            
            ctrlData.yaw = 0
            ctrlData.roll = directPointingVelocityModified2(currentDistance: currentDistance)
            
            let verticalDistance = abs(Float(aircraftAltitude) - directPointingDestAltitude)
            
            if ctrlData.roll == 0 {
                // reach target location (after confirm 3 times)
                reachTargetCounter += 1
                if reachTargetCounter == 3 {
                    stopDirectPointingControlTimer()
                    stopAndHover()
                    reachTargetCounter = 0
                    
                    let rd = findCurrentRealRadiusWith(flightMode: .spherical)
                    // start heading calibration, making AC heading face to user
                    print("Reach destination. Distance: " + String(currentDistance))
                    print("Reach destination. Radius: " + String(circularLocationTransformer.radius))
                    print("R D: "+String(rd))
                    startTimerForHeadingCalibration()
                }
            }
            else {
                print("altitude distance: " + String(verticalDistance))
                reachTargetCounter = 0
            }
        }
        if ((aircraft != nil && aircraft.flightController != nil) && (aircraft.flightController!.isVirtualStickControlModeAvailable())) {
            aircraft.flightController!.send(ctrlData, withCompletion: {[weak self](error: Error?) -> Void in
                if error == nil {
                    // tunging gimbal angle by current altitude
                    self?.GimbalAutoTuning()
                }
            })
        }
    }
    
    // MARK: - Direct Pointing Implement Method
    func updateCenterTo(location: CLLocationCoordinate2D) {
        if !CLLocationCoordinate2DIsValid(location) {
            //self.delegate?.showAlertResultOnView("Cannot set center to invalid location")
            return
        }
        
        circularLocationTransformer.center = location
        sphereTrackGenerator?.sphereCenter = circularLocationTransformer.center
        headingCalibrator?.cylinderCenter = circularLocationTransformer.center
        
        self.delegate?.showAlertResultOnView("New center set from user's location" + "(" + String(format: "%.8f", location.latitude) + ", " + String(format: "%.8f", location.longitude) + ")")
    }
    
    // 將飛機目前位置設為圓心
    func setCenterToAircraftLocation() {
        if CLLocationCoordinate2DIsValid(aircraftLocation) {
            if currentFCState?.gpsSignalLevel != DJIGPSSignalLevel.levelNone && currentFCState?.gpsSignalLevel != DJIGPSSignalLevel.level0 && currentFCState?.gpsSignalLevel != DJIGPSSignalLevel.level1 && currentFCState?.gpsSignalLevel != DJIGPSSignalLevel.level2 && currentFCState?.gpsSignalLevel != DJIGPSSignalLevel.level3{
                updateCenterTo(location: aircraftLocation)
            }
            else {
                self.delegate?.showAlertResultOnView("Current GPS signal is weak, please try later")
            }
        }
        else {
            self.delegate?.showAlertResultOnView("variable 'aircraftLocation' invalid")
        }
    }
    
    func executeDirectPointing(userHeading: CLLocationDirection?, userPhonePitch: Double) {
        if CLLocationCoordinate2DIsValid(aircraftLocation) {
            // if current radius less than 2 meter shouldn't move
            if findCurrentRealRadiusWith(flightMode: .spherical) < 2 {
                stopFineTuningControlTimer()
                stopAndHover()
                self.delegate?.showAlertResultOnView("In safity zone, should push out")
                return
            }
            
            //if current radius greater than 15 meter shouldn't move
            if findCurrentRealRadiusWith(flightMode: .spherical) > 10 {
                stopFineTuningControlTimer()
                stopAndHover()
                self.delegate?.showAlertResultOnView("Can't move! Current aircraft location is too far")
                return
            }
            
            self.directPointingDestAltitude = Float(findDestinationAltitudeBy(phonePitchInRadians: userPhonePitch))
            
            var targetAngle: Double
            if userPhonePitch > 75 * (.pi/180) {
                targetAngle = 89.0 * (.pi/180)
            }
            else if userPhonePitch < 10.0 * (.pi/180) {
                targetAngle = 0.0
            } else {
                targetAngle = userPhonePitch
            }
            
            let shouldMoveUp = previousDestAngle < targetAngle ? true : false
            
            let flightInfo: Dictionary<String, Any> = ["mode": FlightMode.spherical, "moveRight": shouldMoveRight(userHeading: userHeading), "userHeading": userHeading!, "moveUp": shouldMoveUp, "targetAngle": targetAngle]
            
            self.previousDestAltitude = directPointingDestAltitude
            self.previousDestAngle = targetAngle
            
            startDirectPointingTimer(flightInfo: flightInfo)
            
            // notify UI change
            isNearFarButtonEnable = false
            isZoomButtonEnable = false
            isFramingButtonEnable = false
            NotificationCenter.default.post(name: .updateUI, object: nil)
        }
        else { //aircraftLocation is invalid
            self.delegate?.showAlertResultOnView("Current Drone Location Invalid")
        }
    }
    
    //使用方位角判斷: 繞行模式的 directpointing 要往左還是右邊繞行
    func shouldMoveRight(userHeading: CLLocationDirection?) -> Bool {
        
        //因為我們永遠讓飛機對著中心，所以上次的userheading方位角會是現在飛機的方位角加180度
        let previousUserHeading = 180 + (currentFCState?.attitude.yaw)!
        if previousUserHeading > 180 {
            // y 是與上次 heading 相差180度的方位角
            let y = previousUserHeading - 180
            if userHeading! < y || userHeading! > previousUserHeading {
                return true
            }
            else {
                return false
            }
        }
        else {
            // y 是與上次 heading 相差180度的方位角
            let y = previousUserHeading + 180
            if userHeading! > previousUserHeading && userHeading! < y {
                return true
            }
            else {
                return false
            }
        }
    }
    
    // No GPS Direct Pointing Timer
    func startNoGPSDirectPointingTimer(flightInfo: Dictionary<String, Any>) {
        if aircraft.flightController?.isVirtualStickControlModeAvailable() == false {
            enableVirtualStickControlMode()
        }
        
        if directPointingControlTimer == nil {
            directPointingControlTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(performNoGPSDirectPointing), userInfo: flightInfo, repeats: true)
            self.delegate?.didDirectPointingStartWith(destLocation: directPointingDestLocation, destAltitude: directPointingDestAltitude)
        }
    }
    
    @objc func performNoGPSDirectPointing(_ timer: Timer) {
        let flightInfo = timer.userInfo as! Dictionary<String, Any>
        let userHeading = flightInfo["userHeading"] as! CLLocationDirection
        let shouldMoveUp = flightInfo["moveUp"] as! Bool
        let shouldMoveRight = flightInfo["moveRight"] as! Bool
        
        // 若高度還未到範圍內則調整高度
        if (abs((currentFCState?.altitude)! - Double(directPointingDestAltitude)) > 0.4) {
            performNoGPSVerticalMove(shouldMoveUp: shouldMoveUp)
            return
        }
    }
    
    func performNoGPSVerticalMove(shouldMoveUp: Bool) {
        var ctrlData = DJIVirtualStickFlightControlData()
    }
    
    // 每 0.1 秒觸發一次 "performShpereDirectPointing" function
    func startDirectPointingTimer(flightInfo: Dictionary<String, Any>) {
        if aircraft.flightController?.isVirtualStickControlModeAvailable() == false {
            enableVirtualStickControlMode()
        }
        
        if directPointingControlTimer == nil {
            ctrlPitch = 0
            ctrlRoll = 0
            directPointingControlTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(performSphereDirectPointing), userInfo: flightInfo, repeats: true)
            self.delegate?.didDirectPointingStartWith(destLocation: directPointingDestLocation, destAltitude: directPointingDestAltitude)
        }
    
    }
    
    // 目前的directPointing
    @objc func performSphereDirectPointing(_ timer: Timer) {
        let flightInfo = timer.userInfo as! Dictionary<String, Any>
        let userHeading = flightInfo["userHeading"] as! CLLocationDirection
        let shouldMoveUp = flightInfo["moveUp"] as! Bool
        let shouldMoveRight = flightInfo["moveRight"] as! Bool
        let targetAngle = flightInfo["targetAngle"] as! Double
        
        // 若高度還未到範圍內則調整高度
//        if (abs((currentFCState?.altitude)! - Double(directPointingDestAltitude)) > 0.4) {
//            performVerticalMove(shouldMoveUp: shouldMoveUp)
//            return
//        }
        if shouldMoveUp {
            
            if (sphereTrackGenerator?.accumVerticalAngle)! < targetAngle {
                print("up")
                performVerticalMove(shouldMoveUp: shouldMoveUp)
                return
            } else {
                if !isHorizontalHoverLocationSet {
                    hoverLocation = kCLLocationCoordinate2DInvalid
                    isHorizontalHoverLocationSet = true
                }
                performHorizontalMove(shouldMoveRight: shouldMoveRight)
            }
            // 如果飛機與人的角度減180在指定範圍內則停止，到達目的
            if abs(abs(userHeading - (currentFCState?.attitude.yaw)!) - 180) < 3.5
            {
                GimbalAutoTuning()
                stopDirectPointingControlTimer()
                stopAndHover()
                updateSphereGenerator()
                startTimerForHeadingCalibration()
            }

        } else {
            print("down")
            if (sphereTrackGenerator?.accumVerticalAngle)! > targetAngle {
                performVerticalMove(shouldMoveUp: shouldMoveUp)
                return
            } else {
                if !isHorizontalHoverLocationSet {
                    hoverLocation = kCLLocationCoordinate2DInvalid
                    isHorizontalHoverLocationSet = true
                }
                performHorizontalMove(shouldMoveRight: shouldMoveRight)
            }
            // 如果飛機與人的角度減180在指定範圍內則停止，到達目的
            if abs(abs(userHeading - (currentFCState?.attitude.yaw)!) - 180) < 3.5
            {
                GimbalAutoTuning()
                stopDirectPointingControlTimer()
                stopAndHover()
                updateSphereGenerator()
                startTimerForHeadingCalibration()
            }
        }
//        if abs((sphereTrackGenerator?.accumVerticalAngle)! - targetAngle) > 10 * (Double.pi/180) {
//
//            performVerticalMove(shouldMoveUp: shouldMoveUp)
//            return
//        }
        
//        // 否則調整水平位置
//        else {
//            if !isHorizontalHoverLocationSet {
//                hoverLocation = kCLLocationCoordinate2DInvalid
//                isHorizontalHoverLocationSet = true
//            }
//            performHorizontalMove(shouldMoveRight: shouldMoveRight)
//        }
//
//
//        // 如果飛機與人的角度減180在指定範圍內則停止，到達目的
//        if abs(abs(userHeading - (currentFCState?.attitude.yaw)!) - 180) < 3.5
//        {
//            isStartMoveVertical = false
//            GimbalAutoTuning()
//            stopDirectPointingControlTimer()
//            stopAndHover()
//            updateSphereGenerator()
//            startTimerForHeadingCalibration()
//        }
    }
    
    // 目前 directpointing 垂直移動部分的 function
    func performVerticalMove(shouldMoveUp: Bool) {
        var ctrlData: DJIVirtualStickFlightControlData = DJIVirtualStickFlightControlData()
        
        var aircraftShouldMove: Dictionary<String, Float> = (sphereTrackGenerator?.verticalTrans(aircraftHeading: Float(aircraftHeading), aircraftLocation: aircraftLocation, aircraftAltitude: Float(aircraftAltitude), up: shouldMoveUp))!
 
        aircraft.flightController?.yawControlMode = DJIVirtualStickYawControlMode.angularVelocity
    
        if shouldMoveUp {
            ctrlData.roll = aircraftShouldMove["forward"]!
            ctrlData.verticalThrottle = aircraftShouldMove["up"]!
        }
        else { // down
            ctrlData.roll = -aircraftShouldMove["backward"]!
            if aircraftAltitude > minAltitude {
                ctrlData.verticalThrottle = -aircraftShouldMove["down"]!
            }
        }
    
        // it means accumAngle has reached 0 or 90 degree, check whether AC altitude is same as expected altitude.(1.5m and (circle radius)m) if not, move vertical up/down to the altitude
//                if ctrlData.roll == 0 && ctrlData.verticalThrottle == 0 {
//                    if shouldMoveUp { // altitude should be same as circle radius
//                        if aircraftAltitude < circularLocationTransformer.radius + minAltitude {
//                            aircraft.flightController?.verticalControlMode = DJIVirtualStickVerticalControlMode.position
//
//                            ctrlData.verticalThrottle = Float(circularLocationTransformer.radius + minAltitude)
//                        }
//                    }
//                    else { // down, altitude should be 1.5m
//                        if aircraftAltitude > minAltitude {
//                            aircraft.flightController?.verticalControlMode = DJIVirtualStickVerticalControlMode.position
//
//                            ctrlData.verticalThrottle = Float(minAltitude)
//                        }
//                    }
//                }
    
        
        if ((aircraft != nil && aircraft.flightController != nil) && (aircraft.flightController!.isVirtualStickControlModeAvailable())) {
            aircraft.flightController!.send(ctrlData, withCompletion: nil)
        }
    
    }
    
    // 目前 directpointing 水平移動部分的 function
    func performHorizontalMove(shouldMoveRight: Bool) {
        var ctrlData: DJIVirtualStickFlightControlData = DJIVirtualStickFlightControlData()

        if !CLLocationCoordinate2DIsValid(hoverLocation) {
            if (currentFCState?.velocityX == 0 || currentFCState?.velocityX == -0)
                && (currentFCState?.velocityY == 0 || currentFCState?.velocityY == -0)
                && (currentFCState?.velocityZ == 0 || currentFCState?.velocityZ == -0)
            {
                hoverLocation = self.aircraftLocation
            }
        }
        else {
            if shouldMoveRight == true { //Move right
                let aircraftShouldMove: Dictionary<String, Float> = (sphereTrackGenerator?.horizontalTrans(aircraftLocation: hoverLocation, aircraftHeading: Float(aircraftHeading), altitude: Float(aircraftAltitude), isCW: true))!
                if aircraftShouldMove["angle"] == 1 {
                    // aircraft heading should calibrate to correct heading in angle
                    aircraft.flightController?.yawControlMode = DJIVirtualStickYawControlMode.angle
                    ctrlData.pitch = 0
                    ctrlData.yaw = aircraftShouldMove["rotate"]!
                }
                else {
                    print("move Right")
                    // aircraft heading is ok, start to perform horizontal move
                    aircraft.flightController?.yawControlMode = DJIVirtualStickYawControlMode.angularVelocity
                    ctrlData.pitch = -aircraftShouldMove["speed"]!
                    ctrlData.yaw = aircraftShouldMove["rotate"]!
                }
            }
            else { //Move left
                let aircraftShouldMove: Dictionary<String, Float> = (sphereTrackGenerator?.horizontalTrans(aircraftLocation: hoverLocation, aircraftHeading: Float(aircraftHeading), altitude: Float(aircraftAltitude), isCW: false))!
                if aircraftShouldMove["angle"] == 1 {
                    // aircraft heading should calibrate to correct heading in angle
                    aircraft.flightController?.yawControlMode = DJIVirtualStickYawControlMode.angle
                    ctrlData.pitch = 0
                    ctrlData.yaw = aircraftShouldMove["rotate"]!
                }
                else {
                    print("move Left")
                    // aircraft heading is ok, start to perform horizontal move
                    aircraft.flightController?.yawControlMode = DJIVirtualStickYawControlMode.angularVelocity
                    ctrlData.pitch = -aircraftShouldMove["speed"]!
                    ctrlData.yaw = aircraftShouldMove["rotate"]!
                }
            }
        }
        
        if ((aircraft != nil && aircraft.flightController != nil) && (aircraft.flightController!.isVirtualStickControlModeAvailable())) {
            aircraft.flightController!.send(ctrlData, withCompletion: nil)
        }
    }
    
    func stopDirectPointing() {
        stopDirectPointingControlTimer()
        stopAndHover()

        // reset heading and radius after aircraft stopped
        startRadiusUpdateTimerWith(flightMode: .spherical)
        startTimerForHeadingCalibration()
        self.delegate?.didDirectPointingStop()
    }

    func stopDirectPointingControlTimer() {
        if directPointingControlTimer != nil {
            directPointingControlTimer?.invalidate()
            directPointingControlTimer = nil
            print("stop directpointing timer")
        }
    }
    
    func findDestinationPoint(withHeading userHeading: CLLocationDirection, andElevation userPitchAngle: Double) -> CLLocationCoordinate2D {

        var destinationPoint: CLLocationCoordinate2D = kCLLocationCoordinate2DInvalid
    
        // Spherical Coordinate System
        destinationPoint = circularLocationTransformer.findSpherePoint(radian: toRadian(from: userHeading), tiltAngle: userPitchAngle)
    
        return destinationPoint
    }
    
    func findDestinationAltitudeBy(phonePitchInRadians: Double) -> Double {
        
        // Spherical Coordinate System
        
        //使用radius當做斜邊，phonePitchInRadians 當作角度算出 radius * sin(elevation) 當作需爬升的高度
        let oppositeLength: Double = circularLocationTransformer.radius * sin(phonePitchInRadians)
        if oppositeLength + minAltitude < minAltitude {
            return minAltitude
        }
        else {
            return oppositeLength + minAltitude
        }
    }
    
    func checkTargetAziumuth(_ newAziumuth: Double) {
        if targetAziumuth == nil {
            targetAziumuth = newAziumuth
        }
        
        if abs(newAziumuth - targetAziumuth!) > headingThreshold
            && abs(newAziumuth - targetAziumuth!) < (360 - headingThreshold) {
            aziuDiffCounter += 1
            if aziuDiffCounter == 3 {
                targetAziumuth = newAziumuth
                aziuDiffCounter = 0
                print("change targetAziumuth")
            }
        }
        else {
            aziuDiffCounter = 0
        }
    }
    
    func shouldHeadingCalibrate(_ currentDistance: Double) -> Bool {
        let exchangeHeading = getExchangedAircraftHeading()
        
        // if distance is equal with and less than 1 meter, should not calibrate because aziumuth would floating in short distance.
        if currentDistance <= 1 {
            return false
        }
        
        if (abs(exchangeHeading - targetAziumuth!) <= headingThreshold)
            || (abs(exchangeHeading - targetAziumuth!) >= (360 - headingThreshold)) {
            return false
        }
        return true
    }
    
    func directPointingVelocityModified(gateDistance: Double, targetDitance: Double, currentDistance: Double) -> Float{
        let slope: Double = 1 / (gateDistance - targetDitance)
        
        // it will treat as reaching target if current distance is less than 1
        // meter or modified velocity is less than 0.01 m/s
        if currentDistance <= targetDitance + 1 {
            return 0
        }
        else if currentDistance > targetDitance && currentDistance < gateDistance{
            let modifiedVelocity = Float(pow(((currentDistance - targetDitance) * slope),2))
            if directPointingMoveSpeed * modifiedVelocity < 0.01 {
                return 0
            }
            else {
                return directPointingMoveSpeed * modifiedVelocity
            }
        }
        else{
            return directPointingMoveSpeed
        }
    }
    
    func directPointingVelocityModified2(currentDistance: Double) -> Float{
        let gateDistance: Double = 2.5
        let targetDistance: Double = 1.0
        
        // it will treat as reaching target if current distance is less than 1
        // meter or modified velocity is less than 0.01 m/s
        if currentDistance <= targetDistance {
            return 0
        }
        else if currentDistance > targetDistance && currentDistance < gateDistance{
            let modifiedVelocity = currentDistance - targetDistance
            if modifiedVelocity < 0.1 {
                return 0.1
            }else{
                return Float(modifiedVelocity)
            }
        }
        else{
            return directPointingMoveSpeed
        }
    }
    
    func getAzimuthByCoordi(From A: CLLocationCoordinate2D, to B: CLLocationCoordinate2D) -> Double {
        let lat1 = toRadian(from: A.latitude)
        let lon1 = toRadian(from: A.longitude)
        
        let lat2 = toRadian(from: B.latitude)
        let lon2 = toRadian(from: B.longitude)
        
        let dLon = lon2 - lon1
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radiansAzimuth = atan2(y, x)
        
        var degreeAzimuth = toDegree(from: radiansAzimuth)
        if degreeAzimuth < 0 {
            degreeAzimuth += 360
        }
        
        return degreeAzimuth
    }
    
    func toRadian (from deg: Double) -> Double {
        return deg * (.pi / 180)
    }
    
    func toDegree(from rad: Double) -> Double {
        return rad * (180 / .pi)
    }

    func getDistanceFrom(_ pointA: CLLocationCoordinate2D, to pointB: CLLocationCoordinate2D) -> Double {
        let pointA_c: CLLocation = CLLocation(latitude: pointA.latitude, longitude: pointA.longitude)
        let pointB_c: CLLocation = CLLocation(latitude: pointB.latitude, longitude: pointB.longitude)
    
        // return the distance between 2 location in meters
        return pointA_c.distance(from: pointB_c)
    }

    func currentExpectedAircraftHeading(_ remoteHeading: CLLocationDirection) -> Float {
        // get expected aircraft's heading [-180, 180] from user heading [0, 359.9]
        return Float(remoteHeading) - 180
    }

    //依照Mode判斷實際飛機到中心的半徑
    func findCurrentRealRadiusWith(flightMode: FlightMode) -> Double {
        switch flightMode {
        case .spherical:
            // Spherical Coordinate System
            var oppositeLength = aircraftAltitude - minAltitude
            if oppositeLength < 0 { oppositeLength = 0 }
            let adjacentLength = getDistanceFrom(circularLocationTransformer.center, to: aircraftLocation)
            
            return sqrt(pow(Double(oppositeLength), 2) + pow(adjacentLength, 2))
        case .cartesian:
            return getDistanceFrom(circularLocationTransformer.center, to: aircraftLocation)
        case .gimbal:
            var oppositeLength = aircraftAltitude - minAltitude
            if oppositeLength < 0 { oppositeLength = 0 }
            let adjacentLength = getDistanceFrom(circularLocationTransformer.center, to: aircraftLocation)
            
            return sqrt(pow(Double(oppositeLength), 2) + pow(adjacentLength, 2))
        }
    }
    
    func findCurrentElevationRadians() -> Double {
        // try to tuning the length of opposite (height) to make gimbal catch user's face
        var oppositeLength = aircraftAltitude - 1
        if oppositeLength < 0 { oppositeLength = 0 }
        let adjacentLength = getDistanceFrom(circularLocationTransformer.center, to: aircraftLocation)
        
        return atan(Double(oppositeLength)/adjacentLength)
    }
    
    // MARK: - Fine Tuning Mode Method
    
    // DJI Virtual stick commands should be sent to the aircraft between 5 Hz and 25 Hz
    // for radius updating, we choose 20 Hz to check whether the aircraft stop because the aircraft's state is updated in 10 Hz.
    func startRadiusUpdateTimerWith(flightMode: FlightMode) {
        if radiusUpdateTimer == nil {
            radiusUpdateTimer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(checkAndPerformRadiusUpdate), userInfo: flightMode, repeats: true)
            radiusUpdateTimer?.fire()
        }
    }
    
    // check the state of the aircraft, updating radius when the aircraft stoped (velocity = 0)
    @objc func checkAndPerformRadiusUpdate(_ timer: Timer) {
        if (currentFCState?.velocityX == 0 || currentFCState?.velocityX == -0)
        && (currentFCState?.velocityY == 0 || currentFCState?.velocityY == -0)
        && (currentFCState?.velocityZ == 0 || currentFCState?.velocityZ == -0)
        {
            let flightMode = timer.userInfo as! FlightMode
            circularLocationTransformer.radius = findCurrentRealRadiusWith(flightMode: flightMode)
            sphereTrackGenerator?.radius = Float(self.circularLocationTransformer.radius)
            
            print("### SkyfieController updated radius to \(self.circularLocationTransformer.radius) ###")
            
            self.radiusUpdateTimer!.invalidate()
            self.radiusUpdateTimer = nil
        }
    }
    
    // for flight control, we choose 10 Hz, same as the frequency of the aircraft's state being updated
    func startTimerForHeadingCalibration() {
        if aircraft.flightController?.isVirtualStickControlModeAvailable() == false {
            enableVirtualStickControlMode()
        }
        
        if fineTuningControlTimer == nil {
            hoverLocation = kCLLocationCoordinate2DInvalid
            isHorizontalHoverLocationSet = false
            updateHeadingCalibrator()

            fineTuningControlTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(checkAndPerformHeadingCalibration), userInfo: nil, repeats: true)
            fineTuningControlTimer?.fire()
            print("Start Heading Calibration")
        }
    }
    
    @objc func checkAndPerformHeadingCalibration() {
        if !CLLocationCoordinate2DIsValid(hoverLocation) {
            if (currentFCState?.velocityX == 0 || currentFCState?.velocityX == -0)
            && (currentFCState?.velocityY == 0 || currentFCState?.velocityY == -0)
            && (currentFCState?.velocityZ == 0 || currentFCState?.velocityZ == -0)
            {
                hoverLocation = self.aircraftLocation
            }
        }
        else { // hoverLocation have been set
            let aircraftShouldMove: Dictionary<String, Float> = (headingCalibrator?.horizontalTrans(aircraftLocation: hoverLocation, aircraftHeading: Float(aircraftHeading), isCW: true))!
        
            if aircraftShouldMove["angle"] == 1 {
            // aircraft heading should calibrate to correct heading in angle
                aircraft.flightController?.yawControlMode = DJIVirtualStickYawControlMode.angle
                var ctrlData: DJIVirtualStickFlightControlData = DJIVirtualStickFlightControlData()
                ctrlData.roll = 0
                ctrlData.pitch = 0
                ctrlData.verticalThrottle = 0
                ctrlData.yaw = aircraftShouldMove["rotate"]!

                if ((aircraft != nil && aircraft.flightController != nil) && (aircraft.flightController!.isVirtualStickControlModeAvailable())) {
                    aircraft.flightController!.send(ctrlData, withCompletion: nil)
                }
                else {
                    aircraft.flightController?.setVirtualStickModeEnabled(true, withCompletion: nil)
                }
            }
            else {
                // aircraft heading is ok, end the timer
                stopFineTuningControlTimer()
                stopAndHover()
                self.delegate?.didAircraftHeadingCalibrated()
                recoverUI()
            }
        }
    }
    
    @objc func performHeadingCalibrationBeforeDirectPointing() {
        if !CLLocationCoordinate2DIsValid(hoverLocation) {
            if (currentFCState?.velocityX == 0 || currentFCState?.velocityX == -0)
                && (currentFCState?.velocityY == 0 || currentFCState?.velocityY == -0)
                && (currentFCState?.velocityZ == 0 || currentFCState?.velocityZ == -0)
            {
                hoverLocation = self.aircraftLocation
            }
        }
        else { // hoverLocation have been set
            let aircraftShouldMove: Dictionary<String, Float> = (headingCalibrator?.horizontalTrans(aircraftLocation: hoverLocation, aircraftHeading: Float(aircraftHeading), isCW: true))!
            
            if aircraftShouldMove["angle"] == 1 {
                // aircraft heading should calibrate to correct heading in angle
                aircraft.flightController?.yawControlMode = DJIVirtualStickYawControlMode.angle
                var ctrlData: DJIVirtualStickFlightControlData = DJIVirtualStickFlightControlData()
                ctrlData.roll = 0
                ctrlData.pitch = 0
                ctrlData.verticalThrottle = 0
                ctrlData.yaw = aircraftShouldMove["rotate"]!
                
                if ((aircraft != nil && aircraft.flightController != nil) && (aircraft.flightController!.isVirtualStickControlModeAvailable())) {
                    aircraft.flightController!.send(ctrlData, withCompletion: {[weak self](error: Error?) -> Void in
                        if error == nil {
                            
                        }
                    })
                }
                else {
                    aircraft.flightController?.setVirtualStickModeEnabled(true, withCompletion: nil)
                }
            }
            else {
                // aircraft heading is ok, end the timer
                stopFineTuningControlTimer()
                stopAndHover()
            }
        }
    }

    func startTimerForZoomInOutMoveWith(_ flightInfo: Dictionary<String, Any>) {
        // resolve flight infomation
        let flightMode = flightInfo["mode"] as! FlightMode
        
        // safity zone checking
        if findCurrentRealRadiusWith(flightMode: flightMode) < 2 {
            if flightMode == .spherical {
                let shouldMoveNear = flightInfo["moveNear"] as! Bool
                if shouldMoveNear == true {
                    stopFineTuningControlTimer()
                    stopAndHover()
                    self.delegate?.showAlertResultOnView("In safity zone, should push out")
                    return
                }
            }
            else if flightMode == .cartesian { // Cartesian
                let moveDirection = flightInfo["direction"] as! String
                if moveDirection == "back" {
                    stopFineTuningControlTimer()
                    stopAndHover()
                    self.delegate?.showAlertResultOnView("In safity zone, should push out")
                    return
                }
            }
            else { // Gimbal
                let shouldMoveNear = flightInfo["moveNear"] as! Bool
                if shouldMoveNear == true {
                    stopFineTuningControlTimer()
                    stopAndHover()
                    self.delegate?.showAlertResultOnView("In safity zone, should push out")
                    return
                }
            }
        }
        if fineTuningControlTimer == nil {
            ctrlRoll = 0
            ctrlPitch = 0
            ctrlVerticalThrottle = 0
            hoverLocation = kCLLocationCoordinate2DInvalid
            print("fineTuningControlTimer restart")
            fineTuningControlTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(checkAndPerformZoomInOutMove), userInfo: flightInfo, repeats: true)
            fineTuningControlTimer?.fire()
            
            // post notifaction
            isFramingButtonEnable = false
            isGoStopButtonEnable = false
            isNearFarButtonEnable = false
            NotificationCenter.default.post(name: .updateUI, object: nil)
        }
        
//        if flightMode == .spherical {
//            let shouldMoveNear = flightInfo["moveNear"] as! Bool
//            updateSphericalNearFarMoveSpeedComponents(by: moveSpeed)
//
//            if shouldMoveNear {
//                ctrlVerticalThrottle = -ctrlVerticalThrottle
//            }
//            else { // far
//                ctrlRoll = -ctrlRoll
//            }
//        }
//        else if flightMode == "cartesian"{ // Cartesian
//            // update speed components
//            // change based direction if the variation of heading is greater than or equal to 10
//            let newUserHeading = flightInfo["heading"] as! Double
//
//            if abs(newUserHeading - currentUserHeading) >= 10 && abs(newUserHeading - currentUserHeading) <= 350 {
//                currentUserHeading = newUserHeading
//            }
//            let moveDirection = flightInfo["direction"] as! String
//            print("fine tune to " + moveDirection)
//            updateCartesianMoveComponents(byUserHeading: currentUserHeading, moveSpeed: moveSpeed, andMoveDirection: moveDirection)
//        }
//        else { // Gimbal
//
//        }
    }

    @objc func checkAndPerformZoomInOutMove(_ timer: Timer) {
        let flightInfo = timer.userInfo as! Dictionary<String, Any>
        let flightMode = flightInfo["mode"] as! FlightMode
        var ctrlData: DJIVirtualStickFlightControlData = DJIVirtualStickFlightControlData()
        
        // In spherical fine tuning mode, aircraft's heading should be absolutely right (face to user) before performing movements.
        if flightMode == .spherical {
            if !CLLocationCoordinate2DIsValid(hoverLocation) {
                print("set hoverlocation")
                if (currentFCState?.velocityX == 0 || currentFCState?.velocityX == -0)
                && (currentFCState?.velocityY == 0 || currentFCState?.velocityY == -0)
                && (currentFCState?.velocityZ == 0 || currentFCState?.velocityZ == -0)
                {
                    hoverLocation = self.aircraftLocation
                }
            }
            else { // hoverLocation have been set
                updateHeadingCalibrator()
        
                // perform heading calibration and near/far move
                let aircraftShouldMove: Dictionary<String, Float> = (headingCalibrator?.horizontalTrans(aircraftLocation: hoverLocation, aircraftHeading: Float(aircraftHeading), isCW: true))!
        
                if aircraftShouldMove["angle"] == 1 {
                    // aircraft heading should calibrate to correct heading in angle
                    aircraft.flightController?.yawControlMode = DJIVirtualStickYawControlMode.angle

                    ctrlData.roll = 0
                    ctrlData.pitch = 0
                    ctrlData.verticalThrottle = 0
                    ctrlData.yaw = aircraftShouldMove["rotate"]!
            
                    if ((aircraft != nil && aircraft.flightController != nil) && (aircraft.flightController!.isVirtualStickControlModeAvailable())) {
                        aircraft.flightController!.send(ctrlData, withCompletion: nil)
                    }
                }
                else { // heading is ok, start to perform movement
                    aircraft.flightController?.yawControlMode = DJIVirtualStickYawControlMode.angularVelocity

                    ctrlData.pitch = 0.0
                    ctrlData.yaw = 0.0
                    ctrlData.roll = ctrlRoll
                    ctrlData.verticalThrottle = ctrlVerticalThrottle
                }
            }
        }
        else if flightMode == .cartesian{ // Cartesian
            aircraft.flightController?.yawControlMode = DJIVirtualStickYawControlMode.angularVelocity
        
            ctrlData.roll = ctrlRoll
            ctrlData.pitch = ctrlPitch
            ctrlData.yaw = 0
            ctrlData.verticalThrottle = 0
        }
        else { //Gimbal
    
            let moveNear = flightInfo["moveNear"] as! Bool
            var gimbalAngle: Float = 0.0
            if currentGimbalState != nil {
                gimbalAngle = -(currentGimbalState?.attitudeInDegrees.pitch)!
            }
            else {
                self.delegate?.showAlertResultOnView("gimbal state  invalid")
                return
            }

            let angleInRadians = (toRadian(from: Double(gimbalAngle)))
            let moveSpeed = flightInfo["speed"] as! Float
            
            if moveNear { // move near
//                print("move near")
                if self.aircraftAltitude <= minAltitude {
                    ctrlData.verticalThrottle = 0
                }
                else {
                    ctrlData.roll = cos(Float(angleInRadians)) * moveSpeed
//                    print("moveNear ctrlData.roll: \(ctrlData.roll)")
                    ctrlData.verticalThrottle = -sin(Float(angleInRadians)) * moveSpeed
//                    print("moveNear ctrlData.verticalThrottle: \(ctrlData.verticalThrottle)")
                }
            }
            else { //move far
//                print("move far")
                if aircraftAltitude >= 20 {
                    ctrlData.verticalThrottle = 0
                    self.delegate?.showAlertResultOnView("Can't Move far anymore")
                }
                else {
                    ctrlData.roll = -cos(Float(angleInRadians)) * moveSpeed
//                    print("moveNear ctrlData.roll: \(ctrlData.roll)")
                    ctrlData.verticalThrottle = sin(Float(angleInRadians)) * moveSpeed
//                    print("moveNear ctrlData.verticalThrottle: \(ctrlData.verticalThrottle)")
                }
            }
        }
        
        // Checking whether the aircarft's movement will be close to safity zone or out of maxmum distance. If so, stop the drone or make the speed down proportionally
//        if findCurrentRealRadiusWith(flightMode: flightMode) <= 3 && ctrlData.roll > 0 {
//            stopFineTuningControlTimer()
//            stopAndHover()
//            self.delegate?.showAlertResultOnView("Aircraft too close!")
//        }
//        if findCurrentRealRadiusWith(flightMode: flightMode) <= 7 && ctrlData.roll > 0 {
//            ctrlData.roll = ctrlData.roll * velocityModified(gateDistance: 7, targetDitance: 3, currentDistance: findCurrentRealRadiusWith(flightMode: flightMode))
//            ctrlData.verticalThrottle = ctrlData.verticalThrottle * velocityModified(gateDistance: 7, targetDitance: 3, currentDistance: findCurrentRealRadiusWith(flightMode: flightMode))
//        }
//        if findCurrentRealRadiusWith(flightMode: flightMode) >= 15 && ctrlData.roll < 0 {
//            stopFineTuningControlTimer()
//            stopAndHover()
//            self.delegate?.showAlertResultOnView("Aircraft too far!")
//        }
///////////
//        print("pitch: \(ctrlData.pitch)")
//        print("roll: \(ctrlData.roll)")
//        print("yaw: \(ctrlData.yaw)")
//        print("verticalThrottle: \(ctrlData.verticalThrottle)")
///////////
        if ((aircraft != nil && aircraft.flightController != nil) && (aircraft.flightController!.isVirtualStickControlModeAvailable())) {
            aircraft.flightController!.send(ctrlData, withCompletion: {[weak self](error: Error?) -> Void in
                if error == nil {
                    // tunging gimbal angle by current altitude
                    
                    //self?.GimbalAutoTuning() // 因為現在根據gimbal角度調整遠近，所以移動遠近時不需要調整gimbal角度
                }
            })
        }
    }
    
    func startTimerForNearFarMove(moveNear: Bool) {
        
        // 檢查飛機是否離中心太近
        if findCurrentRealRadiusWith(flightMode: .spherical) < 2 {
            self.delegate?.showAlertResultOnView("離中心太近，請將飛機遠離！")
            return
        }
        if findCurrentRealRadiusWith(flightMode: .spherical) > maxRadius {
            self.delegate?.showAlertResultOnView("超出限制距離，請機飛機拉近")
            return
        }
        
        if nearFarMoveTimer == nil {
            nearFarMoveTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(performNearFarMove), userInfo: moveNear, repeats: true)
        }
    }
    
    @objc func performNearFarMove(_ timer: Timer) {
        var ctrlData = DJIVirtualStickFlightControlData()
        if !CLLocationCoordinate2DIsValid(hoverLocation) {
            if (currentFCState?.velocityX == 0 || currentFCState?.velocityX == -0)
                && (currentFCState?.velocityY == 0 || currentFCState?.velocityY == -0)
                && (currentFCState?.velocityZ == 0 || currentFCState?.velocityZ == -0)
            {
                hoverLocation = self.aircraftLocation
            }
        } else {
            updateHeadingCalibrator()
            
            let aircraftShouldMove: Dictionary<String, Float> = (headingCalibrator?.horizontalTrans(aircraftLocation: hoverLocation, aircraftHeading: Float(aircraftHeading), isCW: true))!
            
            if aircraftShouldMove["angle"] == 1 {
                // aircraft heading should calibrate to correct heading in angle
                aircraft.flightController?.yawControlMode = DJIVirtualStickYawControlMode.angle
                
//                ctrlData.roll = 0
//                ctrlData.pitch = 0
//                ctrlData.verticalThrottle = 0
//                ctrlData.yaw = aircraftShouldMove["rotate"]!
                
                if ((aircraft != nil && aircraft.flightController != nil) && (aircraft.flightController!.isVirtualStickControlModeAvailable())) {
                    aircraft.flightController!.send(ctrlData, withCompletion: nil)
                }
            } else {
                var gimbalAngle: Float = 0.0
                if currentGimbalState != nil {
                    gimbalAngle = -(currentGimbalState?.attitudeInDegrees.pitch)!
                }
                else {
                    self.delegate?.showAlertResultOnView("gimbal state  invalid")
                    return
                }
                
                let angleInRadians = (toRadian(from: Double(gimbalAngle)))
                let moveSpeed: Float = 1.5
                let moveNear = timer.userInfo as! Bool
                if moveNear { // move near
                    //                print("move near")
                    if self.aircraftAltitude <= minAltitude {
                        ctrlData.verticalThrottle = 0
                    }
                    else {
                        ctrlData.roll = cos(Float(angleInRadians)) * moveSpeed
                        //                    print("moveNear ctrlData.roll: \(ctrlData.roll)")
                        ctrlData.verticalThrottle = -sin(Float(angleInRadians)) * moveSpeed
                        //                    print("moveNear ctrlData.verticalThrottle: \(ctrlData.verticalThrottle)")
                    }
                }
                else { //move far
                    //                print("move far")
                    if aircraftAltitude >= 20 {
                        ctrlData.verticalThrottle = 0
                        self.delegate?.showAlertResultOnView("Can't Move far anymore")
                    }
                    else {
                        ctrlData.roll = -cos(Float(angleInRadians)) * moveSpeed
                        //                    print("moveNear ctrlData.roll: \(ctrlData.roll)")
                        ctrlData.verticalThrottle = sin(Float(angleInRadians)) * moveSpeed
                        //                    print("moveNear ctrlData.verticalThrottle: \(ctrlData.verticalThrottle)")
                    }
                }
            }
        }
    }
    
    func velocityModified(gateDistance: Double, targetDitance: Double, currentDistance: Double) -> Float{
        let slope: Double = 1 / (gateDistance - targetDitance)
        if currentDistance > targetDitance && currentDistance < gateDistance{
            return Float(pow(((currentDistance - targetDitance) * slope),2))
        }else if currentDistance < targetDitance{
            return 0
        }else{
            return 1
        }
    }
    func startTimerForVerticalMoveWith(_ flightInfo: Dictionary<String, Any>) {
        
        if fineTuningControlTimer == nil {
            hoverLocation = kCLLocationCoordinate2DInvalid

            fineTuningControlTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(checkAndPerformVerticalMove), userInfo: flightInfo, repeats: true)
            fineTuningControlTimer?.fire()
        }
    }

    @objc func checkAndPerformVerticalMove(_ timer: Timer) {
        print("垂直")
        // resolve flight infomation
        let flightInfo = timer.userInfo as! Dictionary<String, Any>
        let flightMode = flightInfo["mode"] as! FlightMode
        let shouldMoveUp = flightInfo["moveUp"] as! Bool

        var ctrlData: DJIVirtualStickFlightControlData = DJIVirtualStickFlightControlData()
        ctrlData.pitch = 0.0
        
        // In spherical fine tuning mode, aircraft's heading should be absolutely right (face to user) before performing movements.
        if flightMode == .spherical {
            if !CLLocationCoordinate2DIsValid(hoverLocation) {
                if (currentFCState?.velocityX == 0 || currentFCState?.velocityX == -0)
                && (currentFCState?.velocityY == 0 || currentFCState?.velocityY == -0)
                && (currentFCState?.velocityZ == 0 || currentFCState?.velocityZ == -0)
                {
                    hoverLocation = self.aircraftLocation
                }
            }
            else { // hoverLocation have been set
                // cheack and perform vertical movement
                let aircraftShouldMove: Dictionary<String, Float> = (sphereTrackGenerator?.verticalTrans(aircraftHeading: Float(aircraftHeading), aircraftLocation: aircraftLocation, aircraftAltitude: Float(aircraftAltitude), up: shouldMoveUp))!
        
                if aircraftShouldMove["angle"] == 1 {
                    // heading should calibrate to correct heading in angle
                    aircraft.flightController?.yawControlMode = DJIVirtualStickYawControlMode.angle
                    ctrlData.roll = 0.0
                    ctrlData.verticalThrottle = 0.0
                    ctrlData.yaw = aircraftShouldMove["rotate"]!
                }
                else {
                    // heading is ok, start to perform vertical move
                    aircraft.flightController?.yawControlMode = DJIVirtualStickYawControlMode.angularVelocity
                    ctrlData.yaw = 0.0
                
                    if shouldMoveUp {
                        ctrlData.roll = aircraftShouldMove["forward"]!
                        ctrlData.verticalThrottle = aircraftShouldMove["up"]!
                    }
                    else { // down
                        ctrlData.roll = -aircraftShouldMove["backward"]!
                        ctrlData.verticalThrottle = -aircraftShouldMove["down"]!
                    }
                    
                    // it means accumAngle has reached 0 or 90 degree, check whether AC altitude is same as expected altitude.(1.5m and (circle radius)m) if not, move vertical up/down to the altitude
                    if ctrlData.roll == 0 && ctrlData.verticalThrottle == 0 {
                        if shouldMoveUp { // altitude should be same as circle radius
                            if aircraftAltitude < circularLocationTransformer.radius + minAltitude {
                                aircraft.flightController?.verticalControlMode = DJIVirtualStickVerticalControlMode.position
                                
                                ctrlData.verticalThrottle = Float(circularLocationTransformer.radius) + Float(minAltitude)
                            }
                        }
                        else { // down, altitude should be 1.5m
                            if aircraftAltitude > minAltitude {
                                aircraft.flightController?.verticalControlMode = DJIVirtualStickVerticalControlMode.position
                                
                                ctrlData.verticalThrottle = Float(minAltitude)
                            }
                        }
                    }
                }
            }
        }
        else if flightMode == .cartesian { // Cartesian
            ctrlData.roll = 0
            ctrlData.yaw = 0

            if shouldMoveUp {
                if aircraftAltitude >= 20 {
                    ctrlData.verticalThrottle = 0
                }
                else {
                    ctrlData.verticalThrottle = fineTuningSpeed
                }
            }
            else {
                if self.aircraftAltitude <= minAltitude {
                    ctrlData.verticalThrottle = 0
                }
                else {
                    ctrlData.verticalThrottle = -fineTuningSpeed
                }
            }
        }
        else { //gimbal
            let gimbalAngle = -(currentGimbalState?.attitudeInDegrees.pitch)!
            let gimbalAngleInRadians = (toRadian(from: Double(90 - gimbalAngle)))
            
            if shouldMoveUp {
                if aircraftAltitude >= 20 {
                    ctrlData.verticalThrottle = 0
                }
                else {
                    ctrlData.roll = cos(Float(gimbalAngleInRadians))
                    ctrlData.verticalThrottle = sin(Float(gimbalAngleInRadians))
                }
            }
            else {
                if self.aircraftAltitude <= minAltitude {
                    ctrlData.verticalThrottle = 0
                }
                else {
                    ctrlData.roll = -cos(Float(gimbalAngleInRadians))
                    ctrlData.verticalThrottle = -sin(Float(gimbalAngleInRadians))
                }
            }
        }

        if ((aircraft != nil && aircraft.flightController != nil) && (aircraft.flightController!.isVirtualStickControlModeAvailable())) {
            aircraft.flightController!.send(ctrlData, withCompletion: {[weak self](error: Error?) -> Void in
                if error == nil {
                    // tunging gimbal angle by current altitude
                    //self?.GimbalAutoTuning()
                }
            })
        }
    }
    
    func startTimerForHorizontalMoveWith(_ flightInfo: Dictionary<String, Any>) {
        
        if fineTuningControlTimer == nil {
            ctrlPitch = 0
            ctrlRoll = 0
            hoverLocation = kCLLocationCoordinate2DInvalid

            fineTuningControlTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(checkAndPerformHorizontalMove), userInfo: flightInfo, repeats: true)
            fineTuningControlTimer?.fire()
        }
        
//        if flightMode == "cartesian" {
//            // update speed components
//            // change based direction if the variation of heading is greater than or equal to 10
//            let newUserHeading = flightInfo["heading"] as! Double
//
//            if abs(newUserHeading - currentUserHeading) >= 10 && abs(newUserHeading - currentUserHeading) <= 350 {
//                currentUserHeading = newUserHeading
//            }
//            let moveDirection = flightInfo["direction"] as! String
//
//            updateCartesianMoveComponents(byUserHeading: currentUserHeading, moveSpeed: fineTuningSpeed, andMoveDirection: moveDirection)
//        }
    }
    func newFineTuneMove(direction: FineTuningDirection) {
        if pressedFinetuningButtonCount == 0 {
            isGoStopButtonEnable = false
            isZoomButtonEnable = false
            isNearFarButtonEnable = false
            NotificationCenter.default.post(name: .updateUI, object: nil)
        }
        
        switch direction {
        case .Left,
             .Right:
            aircraft.flightController?.yawControlMode = DJIVirtualStickYawControlMode.angularVelocity
            fineTuningCtrlData.pitch = (direction == .Left) ? Float(-1) : Float(1)
            if newFineTuningControlTimer == nil {
                newFineTuningControlTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(newPerformHorizontalMove), userInfo: nil, repeats: true)
                newFineTuningControlTimer?.fire()
            }
        case .Up,
             .Down:
            let gimbalAngle = -(currentGimbalState?.attitudeInDegrees.pitch)!
            let gimbalAngleInRadians = (toRadian(from: Double(90 - gimbalAngle)))
            
            if direction == .Up {
                if aircraftAltitude >= maxAltitude {
                    fineTuningCtrlData.verticalThrottle = 0
                }
                else {
                    fineTuningCtrlData.roll = cos(Float(gimbalAngleInRadians))
                    fineTuningCtrlData.verticalThrottle = sin(Float(gimbalAngleInRadians))
                }
            }
            else {
                if self.aircraftAltitude <= minAltitude {
                    fineTuningCtrlData.verticalThrottle = 0
                }
                else {
                    fineTuningCtrlData.roll = -cos(Float(gimbalAngleInRadians))
                    fineTuningCtrlData.verticalThrottle = -sin(Float(gimbalAngleInRadians))
                }
            }
            
            if newFineTuningControlTimer == nil {
                newFineTuningControlTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(newPerformVerticalMove), userInfo: nil, repeats: true)
                newFineTuningControlTimer?.fire()
            }
        }
        
        pressedFinetuningButtonCount += 1
    }
    
    func newFineTuneHorizontalMove(direction: FineTuningDirection) {
        aircraft.flightController?.yawControlMode = DJIVirtualStickYawControlMode.angularVelocity
        fineTuningCtrlData.pitch = (direction == .Left) ? Float(-1) : Float(1)
        if newFineTuningControlTimer == nil {
            newFineTuningControlTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(newPerformHorizontalMove), userInfo: nil, repeats: true)
            newFineTuningControlTimer?.fire()
            
            isGoStopButtonEnable = false
            isZoomButtonEnable = false
            isNearFarButtonEnable = false
            NotificationCenter.default.post(name: .updateUI, object: nil)
        }
    }
    
    @objc func newPerformHorizontalMove(_ timer: Timer) {
        if ((aircraft != nil && aircraft.flightController != nil) && (aircraft.flightController!.isVirtualStickControlModeAvailable())) {
            aircraft.flightController!.send(fineTuningCtrlData, withCompletion: nil)
        }
    }
    
    func newFineTuneVerticalMove(direction: FineTuningDirection) {
        let gimbalAngle = -(currentGimbalState?.attitudeInDegrees.pitch)!
        let gimbalAngleInRadians = (toRadian(from: Double(90 - gimbalAngle)))
        
        if direction == .Up {
            if aircraftAltitude >= maxAltitude {
                fineTuningCtrlData.verticalThrottle = 0
            }
            else {
                fineTuningCtrlData.roll = cos(Float(gimbalAngleInRadians))
                fineTuningCtrlData.verticalThrottle = sin(Float(gimbalAngleInRadians))
            }
        }
        else {
            if self.aircraftAltitude <= minAltitude {
                fineTuningCtrlData.verticalThrottle = 0
            }
            else {
                fineTuningCtrlData.roll = -cos(Float(gimbalAngleInRadians))
                fineTuningCtrlData.verticalThrottle = -sin(Float(gimbalAngleInRadians))
            }
        }
        
        if newFineTuningControlTimer == nil {
            newFineTuningControlTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(newPerformVerticalMove), userInfo: nil, repeats: true)
            newFineTuningControlTimer?.fire()
        }
    }
    
    @objc func newPerformVerticalMove(_ timer: Timer) {
        if ((aircraft != nil && aircraft.flightController != nil) && (aircraft.flightController!.isVirtualStickControlModeAvailable())) {
            aircraft.flightController!.send(fineTuningCtrlData, withCompletion: nil)
        }
    }
    
    @objc func checkAndPerformHorizontalMove(_ timer: Timer) {

        let flightInfo = timer.userInfo as! Dictionary<String, Any>
        let flightMode = flightInfo["mode"] as! FlightMode
        
        var ctrlData: DJIVirtualStickFlightControlData = DJIVirtualStickFlightControlData()
        ctrlData.verticalThrottle = 0.0
        switch flightMode {
        
        case .spherical:
            // In spherical fine tuning mode, aircraft's heading should be absolutely right (face to user) before performing movements.
            if !CLLocationCoordinate2DIsValid(hoverLocation) {
                if (currentFCState?.velocityX == 0 || currentFCState?.velocityX == -0)
                    && (currentFCState?.velocityY == 0 || currentFCState?.velocityY == -0)
                    && (currentFCState?.velocityZ == 0 || currentFCState?.velocityZ == -0)
                {
                    hoverLocation = self.aircraftLocation
                }
            }
            else { // hoverLocation have been set
                ctrlData.roll = 0.0
                let shouldMoveRight = flightInfo["moveRight"] as! Bool
                
                if shouldMoveRight == true {
                    let aircraftShouldMove: Dictionary<String, Float> = (sphereTrackGenerator?.horizontalTrans(aircraftLocation: hoverLocation, aircraftHeading: Float(aircraftHeading), altitude: Float(aircraftAltitude), isCW: true))!
                    if aircraftShouldMove["angle"] == 1 {
                        // aircraft heading should calibrate to correct heading in angle
                        aircraft.flightController?.yawControlMode = DJIVirtualStickYawControlMode.angle
                        ctrlData.pitch = 0
                        ctrlData.yaw = aircraftShouldMove["rotate"]!
                    }
                    else {
                        // aircraft heading is ok, start to perform horizontal move
                        aircraft.flightController?.yawControlMode = DJIVirtualStickYawControlMode.angularVelocity
                        ctrlData.pitch = -aircraftShouldMove["speed"]!
                        ctrlData.yaw = aircraftShouldMove["rotate"]!
                    }
                }
                else { // Left
                    let aircraftShouldMove: Dictionary<String, Float> = (sphereTrackGenerator?.horizontalTrans(aircraftLocation: hoverLocation, aircraftHeading: Float(aircraftHeading), altitude: Float(aircraftAltitude), isCW: false))!
                    if aircraftShouldMove["angle"] == 1 {
                        // aircraft heading should calibrate to correct heading in angle
                        aircraft.flightController?.yawControlMode = DJIVirtualStickYawControlMode.angle
                        ctrlData.pitch = 0
                        ctrlData.yaw = aircraftShouldMove["rotate"]!
                    }
                    else {
                        // aircraft heading is ok, start to perform horizontal move
                        aircraft.flightController?.yawControlMode = DJIVirtualStickYawControlMode.angularVelocity
                        ctrlData.pitch = -aircraftShouldMove["speed"]!
                        ctrlData.yaw = aircraftShouldMove["rotate"]!
                    }
                }
            }
            
        case .cartesian:
            aircraft.flightController?.yawControlMode = DJIVirtualStickYawControlMode.angularVelocity
            let flightDirection = flightInfo["direction"] as! String
            ctrlData.pitch = (flightDirection == "left") ? Float(-1.5) : Float(1.5)
            
        case .gimbal:
            aircraft.flightController?.yawControlMode = DJIVirtualStickYawControlMode.angularVelocity
            let flightDirection = flightInfo["direction"] as! String
            fineTuningCtrlData.pitch = (flightDirection == "left") ? Float(-1.5) : Float(1.5)
            
        }

///////////
//        print("Horizontal pitch: \(ctrlData.pitch)")
//        print("Horizonral yaw: \(ctrlData.yaw) \n")
//        print("Aircraft Heading: \(self.aircraftHeading)")
///////////
        if ((aircraft != nil && aircraft.flightController != nil) && (aircraft.flightController!.isVirtualStickControlModeAvailable())) {
            aircraft.flightController!.send(fineTuningCtrlData, withCompletion: nil)
        }
    }
    
    // for left/right direciton tuning, should tune aircraft's heading due to DJI hardware setting
    func startTimerForFramingTuning(_ rotateDirection: Int) {
        if aircraft.flightController?.isVirtualStickControlModeAvailable() == false {
            enableVirtualStickControlMode()
        }
        
        if fineTuningControlTimer == nil {
            ctrlYaw = 0
            aircraft.flightController?.yawControlMode = DJIVirtualStickYawControlMode.angularVelocity
            fineTuningControlTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(performFramingTuning), userInfo: nil, repeats: true)
            fineTuningControlTimer?.fire()
        }
        
        // update framing tuning direction of horizontal rotation
        if rotateDirection > 0 {
            ctrlYaw = 10
        }
        if rotateDirection == 0 {
            ctrlYaw = 0
        }
        if rotateDirection < 0 {
            ctrlYaw = -10
        }
    }
    
    @objc func performFramingTuning() {
        var ctrlData: DJIVirtualStickFlightControlData = DJIVirtualStickFlightControlData()
        ctrlData.pitch = 0
        ctrlData.roll = 0
        ctrlData.verticalThrottle = 0
        ctrlData.yaw = ctrlYaw
        
        if ((aircraft != nil && aircraft.flightController != nil) && (aircraft.flightController!.isVirtualStickControlModeAvailable())) {
            aircraft.flightController!.send(ctrlData, withCompletion: nil)
        }
    }
    
    func stopAndHover() {
        aircraft.flightController?.yawControlMode = DJIVirtualStickYawControlMode.angularVelocity
        aircraft.flightController?.verticalControlMode = DJIVirtualStickVerticalControlMode.velocity
        
        var ctrlData: DJIVirtualStickFlightControlData = DJIVirtualStickFlightControlData()
        ctrlData.pitch = 0.0
        ctrlData.roll = 0.0
        ctrlData.yaw = 0.0
        ctrlData.verticalThrottle = 0.0
        
        if ((aircraft != nil && aircraft.flightController != nil) && (aircraft.flightController!.isVirtualStickControlModeAvailable())) {
            aircraft.flightController!.send(ctrlData, withCompletion: nil)
        }
        print("### stop and hover ###")
    }
    
    func newFineTuneStopAndHover(){
        aircraft.flightController?.yawControlMode = DJIVirtualStickYawControlMode.angularVelocity
        aircraft.flightController?.verticalControlMode = DJIVirtualStickVerticalControlMode.velocity
        fineTuningCtrlData.roll = 0.0
        fineTuningCtrlData.pitch = 0.0
        fineTuningCtrlData.yaw = 0.0
        fineTuningCtrlData.verticalThrottle = 0.0
        hoverLocation = aircraftLocation
        if ((aircraft != nil && aircraft.flightController != nil) && (aircraft.flightController!.isVirtualStickControlModeAvailable())) {
            aircraft.flightController!.send(fineTuningCtrlData, withCompletion: nil)
        }
    }
    
    func stopNearFarMoveTimer() {
        if nearFarMoveTimer != nil {
            nearFarMoveTimer?.invalidate()
            nearFarMoveTimer = nil
        }
    }
    
    func stopFineTuningControlTimer() {
        if fineTuningControlTimer != nil {
            fineTuningControlTimer?.invalidate()
            fineTuningControlTimer = nil
        }
    }
    
    func stopFineTuningFor(direction: FineTuningDirection) {
        switch direction {
        case .Left,
             .Right:
            fineTuningCtrlData.pitch = 0.0
        case .Down,
             .Up:
            fineTuningCtrlData.roll = 0.0
            fineTuningCtrlData.verticalThrottle = 0.0
        }
    }
    
    func stopNewFineTuningTimer() {
        if newFineTuningControlTimer != nil {
            newFineTuningControlTimer?.invalidate()
            newFineTuningControlTimer = nil
        }
    }
    
    func updateHeadingCalibrator() {
        headingCalibrator?.radius = Float(circularLocationTransformer.radius)
        headingCalibrator?.cylinderCenter = circularLocationTransformer.center
    }
    
    func updateSphereGenerator() {
        if sphereTrackGenerator?.radius != Float(circularLocationTransformer.radius) {
            sphereTrackGenerator?.radius = Float(circularLocationTransformer.radius)
            sphereTrackGenerator?.sphereCenter = circularLocationTransformer.center
        }
    }
    
    func updateSphericalNearFarMoveSpeedComponents(by moveSpeed: Float) {
        let currentElevationRadians = Float(findCurrentElevationRadians())
        ctrlRoll = moveSpeed * cos(currentElevationRadians)
        ctrlVerticalThrottle = moveSpeed * sin(currentElevationRadians)
    }
    
    // Get the move speed components from the angle theta between user and aircraft's heading
    func updateCartesianMoveComponents(byUserHeading userHeading: Double, moveSpeed: Float, andMoveDirection direction: String) {
        var thetaInDegree = getExchangedAircraftHeading() - userHeading
        // make theta be in range [0,359.9]
        if thetaInDegree < 0 {
            thetaInDegree += 360
        }
//        print("theta degree: "+String(thetaInDegree))
        let theta = Float(toRadian(from: thetaInDegree))
        
        if direction == "front" {
            ctrlRoll = moveSpeed * cos(theta)
            ctrlPitch = -moveSpeed * sin(theta)
        }
        if direction == "back" {
            ctrlRoll = -moveSpeed * cos(theta)
            ctrlPitch = moveSpeed * sin(theta)
        }
        
        if direction == "right" {
//            if (thetaInDegree >= 0 && thetaInDegree <= 180) || (thetaInDegree > 270 && thetaInDegree <= 360) {
//                ctrlRoll = moveSpeed * sin(theta)
//                ctrlPitch = moveSpeed * cos(theta)
//            }
//            if (thetaInDegree > 180 && thetaInDegree <= 270) {
//                ctrlRoll = moveSpeed * cos(theta)
//                ctrlPitch = moveSpeed * sin(theta)
//            }
            ctrlRoll = moveSpeed * sin(theta)
            ctrlPitch = moveSpeed * cos(theta)
        }
        if direction == "left" {
//            if (thetaInDegree >= 0 && thetaInDegree <= 180) || (thetaInDegree > 270 && thetaInDegree <= 360) {
//                ctrlRoll = -moveSpeed * sin(theta)
//                ctrlPitch = -moveSpeed * cos(theta)
//            }
//            if (thetaInDegree > 180 && thetaInDegree <= 270) {
//                ctrlRoll = -moveSpeed * cos(theta)
//                ctrlPitch = -moveSpeed * sin(theta)
//            }
            ctrlRoll = -moveSpeed * sin(theta)
            ctrlPitch = -moveSpeed * cos(theta)
        }
    }
    
    func getExchangedAircraftHeading() -> Double {
        // return aircraft heading from [-180, 180] to [0, 359.9]
        if aircraftHeading == 0 || aircraftHeading == -0 {
            return 0
        }
        if aircraftHeading > 0 {
            return aircraftHeading
        }
        // aircraftHeading < 0
        return aircraftHeading + 360
    }
    
// MARK: - Gimbal Tuning Method
    // Gimbal angle tuning automatically for up/down fine tuning and tradtional pitch control
    func GimbalAutoTuning() {
        let gimbal: DJIGimbal? = aircraft.gimbal
        if gimbal != nil {
            let currentElevation = findCurrentElevationRadians() * 180 / .pi
            let gimbalPitchShouldBe = (-currentElevation) as NSNumber
            let attitudeInDegrees = currentGimbalState?.attitudeInDegrees
            
            let gimbalRotation = DJIGimbalRotation(pitchValue: gimbalPitchShouldBe, rollValue: NSNumber(value: (attitudeInDegrees?.roll)!), yawValue: NSNumber(value: (attitudeInDegrees?.yaw)!)
                , time: 1, mode: DJIGimbalRotationMode.absoluteAngle)
            
            gimbal?.rotate(with: gimbalRotation, completion: nil)
        }
    }

    // Gimbal angle tuning according to framing tuning command
    func GimbalTuningForFramingTuning(to direction: String) {
        let gimbal: DJIGimbal? = aircraft.gimbal
        if gimbal != nil {
            if direction == "Up" {
                let gimbalRotation = DJIGimbalRotation(pitchValue: NSNumber(value: framingTuningAngle), rollValue: 0, yawValue: 0, time: 1, mode: DJIGimbalRotationMode.relativeAngle)
                gimbal?.rotate(with: gimbalRotation, completion: nil)
            }
            if direction == "Down" {
                let gimbalRotation = DJIGimbalRotation(pitchValue: NSNumber(value: -framingTuningAngle), rollValue: 0, yawValue: 0, time: 1, mode: DJIGimbalRotationMode.relativeAngle)
                gimbal?.rotate(with: gimbalRotation, completion: nil)
            }
//// DJI Phantom doesn't support to tune the gimbal's yaw value, should use startTimerForFramingTuningMove() to tune the aircraft's yaw value (heading)

//            if direction == "Right" {
//                gimbal?.rotateGimbal(with: DJIGimbalRotateAngleMode.angleModeRelativeAngle, pitch: stopRotation, roll: stopRotation, yaw: tuningRotation, withCompletion: nil)
//            }
//            if direction == "Left" {
//                gimbal?.rotateGimbal(with: DJIGimbalRotateAngleMode.angleModeRelativeAngle, pitch: stopRotation, roll: stopRotation, yaw: reverseTuningRotation, withCompletion: nil)
//            }
        }
    }
    
    func GimbalStop() {
        let gimbal: DJIGimbal? = aircraft.gimbal
        if gimbal != nil {
            let gimbalRotation = DJIGimbalRotation(pitchValue: 0, rollValue: 0, yawValue: 0, time: 1, mode: DJIGimbalRotationMode.relativeAngle)
            gimbal?.rotate(with: gimbalRotation, completion: nil)
        }
    }
    
    func recoverUI(){
        isFramingButtonEnable = true
        isNearFarButtonEnable = true
        isZoomButtonEnable = true
        isGoStopButtonEnable = true
        NotificationCenter.default.post(name: .updateUI, object: nil)
    }
}
