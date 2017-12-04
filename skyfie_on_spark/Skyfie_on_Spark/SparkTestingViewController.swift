//
//  SparkTestingViewController.swift
//  DJISDKSwiftDemo
//
//  Created by 康平 on 2017/7/13.
//  Copyright © 2017年 DJI. All rights reserved.
//

import UIKit
import DJISDK

class SparkTestingViewController: UIViewController, DJIFlightControllerDelegate {
    
    @IBOutlet var btn_takeoffLanding: UIButton!
    @IBOutlet var btn_limitSwitch: UIButton!
    
    
    weak var aircraft: DJIAircraft? = nil
    var aircraftLocation: CLLocationCoordinate2D = kCLLocationCoordinate2DInvalid
    var aircraftHeading: Double = 0
    var targetAziumuth: Double? = nil
    var aziuDiffCounter = 0 // times of expected aziumuth difference
    var reachTargetCounter = 0 // times of reaching target
    var flightControlTimer: Timer? = nil
    
    // constant
    var centerLocation: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 24.9862091, longitude: 121.5729213)
    var directPointingMoveSpeed: Float = 2
    var headingThreshold: Double = 5
    var flag_limitSwitch: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        //        let pointA = CLLocationCoordinate2D(latitude: 24.9863, longitude: 121.5729213)
        //        let pointB = CLLocationCoordinate2D(latitude: 24.9862091, longitude: 121.5730)
        //
        //        print("Aziuth1: " + String(getAzimuthByCoordi(From: pointA, to: pointB)))
        //        print("Aziuth2: " + String(getAzimuthByDistance(From: pointA, to: pointB)))
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        aircraft = (DJISDKManager.product() as! DJIAircraft)
        if aircraft != nil {
            aircraft?.flightController?.delegate = self
            
            aircraft!.flightController?.rollPitchCoordinateSystem = DJIVirtualStickFlightCoordinateSystem.body
            aircraft!.flightController?.isVirtualStickAdvancedModeEnabled = true
            aircraft!.flightController?.verticalControlMode = DJIVirtualStickVerticalControlMode.velocity
            aircraft!.flightController?.yawControlMode = DJIVirtualStickYawControlMode.angularVelocity
            aircraft!.flightController?.rollPitchControlMode = DJIVirtualStickRollPitchControlMode.velocity
            
            // enable virtualStick mode
            aircraft?.flightController?.setVirtualStickModeEnabled(true, withCompletion: {[weak self] (error: Error?) -> Void in
                self?.showAlert("enable virtual stick mode")
            })
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        if aircraft != nil && aircraft?.flightController?.delegate === self {
            aircraft!.flightController!.delegate = nil
        }
    }
    
    func flightController(_ fc: DJIFlightController, didUpdate state: DJIFlightControllerState) {
        aircraftLocation = (state.aircraftLocation?.coordinate)!
        aircraftHeading = state.attitude.yaw
        
        if state.isLandingConfirmationNeeded {
            aircraft?.flightController?.confirmLanding(completion: nil)
        }
    }
    
    @IBAction func limitSwitchClicked(_ sender: UIButton) {
        if btn_limitSwitch.currentTitle == "NoLimit" {
            DispatchQueue.main.async {
                self.btn_limitSwitch.setTitle("Limited", for: UIControlState.normal)
            }
            flag_limitSwitch = true
        }
        if btn_limitSwitch.currentTitle == "Limited" {
            DispatchQueue.main.async {
                self.btn_limitSwitch.setTitle("NoLimit", for: UIControlState.normal)
            }
            flag_limitSwitch = false
        }
        print(flag_limitSwitch)
    }
    @IBAction func takeoffLandingClicked(_ sender: UIButton) {
        if btn_takeoffLanding.currentTitle == "Takeoff" {
            aircraft?.flightController?.startTakeoff(completion: {[weak self] (error: Error?) -> Void in
                self?.btn_takeoffLanding.setTitle("Landing", for: UIControlState.normal)
            })
        }
        if btn_takeoffLanding.currentTitle == "Landing" {
            aircraft?.flightController?.startLanding(completion: {[weak self] (error: Error?) -> Void in
                self?.btn_takeoffLanding.setTitle("Takeoff", for: UIControlState.normal)
            })
            
        }
    }
    
    @IBAction func setCenterClicked(_ sender: UIButton) {
        if CLLocationCoordinate2DIsValid(aircraftLocation) {
            centerLocation = aircraftLocation
            showAlert("Set center to current AC location")
        }
    }
    @IBAction func backToHomeClicked(_ sender: UIButton) {
        aircraft?.flightController?.startGoHome(completion: {[weak self] (error: Error?) -> Void in
            self?.showAlert("back to home success")
        })
    }
    @IBAction func moveToCenterClicked(_ sender: UIButton) {
        startMoveToCenter()
    }
    
    @IBAction func upClicked(_ sender: UIButton) {
        startMovement(to: "up")
    }
    @IBAction func downClicked(_ sender: UIButton) {
        startMovement(to: "down")
    }
    @IBAction func leftRotateClicked(_ sender: UIButton) {
        startMovement(to: "leftRotate")
    }
    @IBAction func rightRotateClicked(_ sender: UIButton) {
        startMovement(to: "rightRotate")
    }
    
    @IBAction func frontClicked(_ sender: UIButton) {
        startMovement(to: "front")
    }
    @IBAction func backClicked(_ sender: UIButton) {
        startMovement(to: "back")
    }
    @IBAction func leftClicked(_ sender: UIButton) {
        startMovement(to: "left")
    }
    @IBAction func rightClicked(_ sender: UIButton) {
        startMovement(to: "right")
    }
    
    @IBAction func stopMovement(_ sender: UIButton) {
        stopFlightControlTimer()
        stopAndHover()
    }
    
    func startMovement(to direction: String) {
        if flightControlTimer == nil {
            flightControlTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(performMovement), userInfo: direction, repeats: true)
            flightControlTimer?.fire()
        }
    }
    
    @objc func performMovement(_ timer: Timer) {
        let moveDirection = timer.userInfo as! String
        var ctrlData: DJIVirtualStickFlightControlData = DJIVirtualStickFlightControlData()
        
        if moveDirection == "up" { ctrlData.verticalThrottle = 5 }
        else if moveDirection == "down" { ctrlData.verticalThrottle = -5 }
        else if moveDirection == "leftRotate" { ctrlData.yaw = -15 }
        else if moveDirection == "rightRotate" { ctrlData.yaw = 15 }
        else if moveDirection == "front" { ctrlData.roll = 5 }
        else if moveDirection == "back" { ctrlData.roll = -5 }
        else if moveDirection == "left" { ctrlData.pitch = -5 }
        else if moveDirection == "right" { ctrlData.pitch = 5 }
        
        if ((aircraft != nil && aircraft!.flightController != nil) && (aircraft!.flightController!.isVirtualStickControlModeAvailable())) {
            aircraft!.flightController!.send(ctrlData, withCompletion: nil)
        }
    }
    
    func startMoveToCenter() {
        if flightControlTimer == nil {
            flightControlTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(performMoveToCenter), userInfo: nil, repeats: true)
            flightControlTimer?.fire()
        }
    }
    
    @objc func performMoveToCenter() {
        var ctrlData = DJIVirtualStickFlightControlData()
        ctrlData.pitch = 0
        ctrlData.verticalThrottle = 0
        
        // determine whether target azimuth should change
        let expectedAziumuth = getAzimuthByCoordi(From: aircraftLocation, to: centerLocation)
        checkTargetAziumuth(expectedAziumuth)
        
        // determine whether aircraft heading should calibrate
        let currentDistance = getDistanceFrom(aircraftLocation, and: centerLocation)
        if shouldHeadingCalibrate(currentDistance) {
            // calibrate aircraft heading to target aziumuth
            aircraft?.flightController?.yawControlMode = DJIVirtualStickYawControlMode.angle
            
            ctrlData.roll = 0
            if targetAziumuth! > 180 {
                ctrlData.yaw = Float(targetAziumuth!) - 360
            }
            else {
                ctrlData.yaw = Float(targetAziumuth!)
            }
        }
        else { // heading is ok, getting the velocity and go.
            aircraft?.flightController?.yawControlMode = DJIVirtualStickYawControlMode.angularVelocity
            
            ctrlData.yaw = 0
            ctrlData.roll = velocityModified(gateDistance: 2.5, targetDitance: 0, currentDistance: currentDistance)
            
            if ctrlData.roll == 0 { // reach target location
                reachTargetCounter += 1
                if reachTargetCounter == 3 {
                    reachTargetCounter = 0
                    stopFlightControlTimer()
                    stopAndHover()
                    
                    print("Distance: " + String(currentDistance))
                    showAlert("Reach target location")
                }
            }
            else {
                reachTargetCounter = 0
            }
        }
        
        if ((aircraft != nil && aircraft!.flightController != nil) && (aircraft!.flightController!.isVirtualStickControlModeAvailable())) {
            aircraft!.flightController!.send(ctrlData, withCompletion: nil)
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
            }
        }
        else {
            aziuDiffCounter = 0
        }
    }
    
    func shouldHeadingCalibrate(_ currentDistance: Double) -> Bool {
        let exchangeHeading = getExchangedAircraftHeading()
        
        // if distance is equal with and less than 1 meter, should not calibrate because aziumuth would be floating in short distance.
        if currentDistance <= 1 {
            return false
        }
        
        if (abs(exchangeHeading - targetAziumuth!) <= headingThreshold)
            || (abs(exchangeHeading - targetAziumuth!) >= (360 - headingThreshold)) {
            return false
        }
        return true
    }
    
    func velocityModified(gateDistance: Double, targetDitance: Double, currentDistance: Double) -> Float{
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
    
    func stopAndHover() {
        aircraft?.flightController?.yawControlMode = DJIVirtualStickYawControlMode.angularVelocity
        
        var ctrlData: DJIVirtualStickFlightControlData = DJIVirtualStickFlightControlData()
        ctrlData.pitch = 0
        ctrlData.roll = 0
        ctrlData.yaw = 0
        ctrlData.verticalThrottle = 0
        
        if ((aircraft != nil && aircraft!.flightController != nil) && (aircraft!.flightController!.isVirtualStickControlModeAvailable())) {
            aircraft!.flightController!.send(ctrlData, withCompletion: nil)
        }
    }
    
    func stopFlightControlTimer() {
        if flightControlTimer != nil {
            flightControlTimer?.invalidate()
            flightControlTimer = nil
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
    
    //    func getAzimuthByDistance(From A: CLLocationCoordinate2D, to B: CLLocationCoordinate2D) -> Double {
    //        let diffLat = Double(B.latitude - A.latitude)
    //        let diffLog = Double(B.longitude - A.longitude)
    //
    //        let C = CLLocationCoordinate2D(latitude: B.latitude, longitude: A.longitude)
    //
    //        let dAB = getDistanceFrom(A, and: B)
    //        let dBC = getDistanceFrom(B, and: C)
    //
    //        let theta = radians2Degree(asin(dBC / dAB))
    //        print("Theta degree by asin: " + String(theta))
    //
    //        var degreeAziuth: Double = 0
    //        if diffLat >= 0 && diffLog >= 0 { // 1st quadrant
    //            degreeAziuth = theta
    //        }
    //        else if diffLat < 0 && diffLog >= 0 { // 2nd quadrant
    //            degreeAziuth = 180 - theta
    //        }
    //        else if diffLat < 0 && diffLog < 0 { // 3rd quadrant
    //            degreeAziuth = 180 + theta
    //        }
    //        else if diffLat >= 0 && diffLog < 0 { // 4th quadrant
    //            degreeAziuth = 360 - theta
    //        }
    //
    //        return degreeAziuth
    //    }
    
    func getAzimuthByCoordi(From A: CLLocationCoordinate2D, to B: CLLocationCoordinate2D) -> Double {
        let lat1 = degree2Radians(A.latitude)
        let lon1 = degree2Radians(A.longitude)
        
        let lat2 = degree2Radians(B.latitude)
        let lon2 = degree2Radians(B.longitude)
        
        let dLon = lon2 - lon1
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radiansAzimuth = atan2(y, x)
        
        var degreeAzimuth = radians2Degree(radiansAzimuth)
        if degreeAzimuth < 0 {
            degreeAzimuth += 360
        }
        
        return degreeAzimuth
    }
    
    func degree2Radians(_ degree: Double) -> Double {
        return degree * .pi / 180
    }
    
    func radians2Degree(_ radians: Double) -> Double {
        return radians * 180 / .pi
    }
    
    func getDistanceFrom(_ pointA: CLLocationCoordinate2D, and pointB: CLLocationCoordinate2D) -> Double {
        let pointA_c: CLLocation = CLLocation(latitude: pointA.latitude, longitude: pointA.longitude)
        let pointB_c: CLLocation = CLLocation(latitude: pointB.latitude, longitude: pointB.longitude)
        
        // return the distance between 2 location in meters
        return pointA_c.distance(from: pointB_c)
    }
    
    func showAlert(_ msg: String?) {
        // create the alert
        let alert = UIAlertController(title: "", message: msg, preferredStyle: UIAlertControllerStyle.alert)
        // add the actions (buttons)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
        // show the alert
        self.present(alert, animated: true, completion: nil)
    }
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destinationViewController.
     // Pass the selected object to the new view controller.
     }
     */
    
}
