//
//  DP_PhoneControlViewController.swift
//  DJI_DPControl
//
//  Created by 康平 on 2017/1/12.
//  Copyright © 2017年 康平. All rights reserved.
//

import UIKit
import CoreLocation
import MapKit
import CoreMotion

import DJISDK
import VideoPreviewer

class PhoneControlViewController: UIViewController, DJIVideoFeedListener, DJICameraDelegate, CLLocationManagerDelegate, SkyfieControllerDelegate, LogViewControllerDelegate, FPVViewDelegate, TrackingRenderViewDelegate{
    
    //MARK: - TrackingRenderView Delegate method
    func renderViewDidTouchAtPoint(point: CGPoint) {
        if self.isTrackingMissionRunning && !self.isNeedConfirm {
            return
        }
        
        if self.isNeedConfirm {
            let largeRect = self.currentTrackingRect?.insetBy(dx: -10, dy: -10)
            if (largeRect?.contains(point))! {
                self.missionOperator.acceptConfirmation(completion: {(error: Error?) -> Void in
                    if error != nil {
                        self.showAlertResultOnView("Set Recommended recommended camera and gimbal configuration: \(error!.localizedDescription)")
                    }
                })
            }
            else {
                self.missionOperator.stopMission(completion: {(error: Error?) -> Void in
                    if error != nil {
                        self.showAlertResult("Cancel Tracking: \(error!.localizedDescription)")
                    }
                })
            }
        }
        else {
        }
    }
    
    func renderViewDidMoveToPoint(endPoint: CGPoint, fromPoint startPoint: CGPoint, isFinished finished: Bool) {
        
    }
    
    private var fineTuneTimer: Timer? = nil
    
    // MARK: - UI variables
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var logView: UIView!
    @IBOutlet var fpvView: FPVView!
    
    @IBOutlet weak var lb_userLocation: UILabel!
    @IBOutlet weak var lb_gpsSignalLevel: UILabel!
    @IBOutlet weak var lb_phonePitch: UILabel!
    @IBOutlet weak var lb_phoneHeading: UILabel!
    @IBOutlet weak var lb_aircraftLocation: UILabel!
    @IBOutlet var lb_currentControlMode: UILabel!
    @IBOutlet weak var lb_roll: UILabel!
    @IBOutlet weak var lb_pitch: UILabel!
    @IBOutlet weak var lb_yaw: UILabel!
    @IBOutlet weak var lb_gimbalPitch: UILabel!
    @IBOutlet weak var lb_throttleMode: UILabel!
    @IBOutlet weak var lb_yawControlMode: UILabel!
    @IBOutlet weak var lb_status: UILabel!
    
    @IBOutlet var btn_GoStop: UIButton!
    @IBOutlet var btn_FineTuning: UIButton!
    @IBOutlet var btn_TakeoffLanding: UIButton!
    @IBOutlet var btn_Snap: UIButton!
    @IBOutlet weak var upButton: UIButton!
    @IBOutlet weak var downButton: UIButton!
    @IBOutlet weak var leftButton: UIButton!
    @IBOutlet weak var rightButton: UIButton!
    @IBOutlet weak var zoomInButton: UIButton!
    @IBOutlet weak var zoomOutButton: UIButton!
    @IBOutlet weak var moveNearButton: UIButton!
    @IBOutlet weak var moveFarButton: UIButton!
    @IBOutlet weak var maskView: UIView!
    
    //MARK - Tracking variables
    @IBOutlet weak var renderView: TrackingRenderView!
    var isNeedConfirm = false
    var isTrackingMissionRunning = false
    var currentTrackingRect: CGRect?
    var missionOperator: DJIActiveTrackMissionOperator {
        return (DJISDKManager.missionControl()?.activeTrackMissionOperator())!
    }
    
//    enum FineTuningDirection {
//        case Left
//        case Right
//        case Up
//        case Down
//    }
    
    //Log some information about aircraft
    @IBAction func showLogView(_ sender: UIButton) {
        logView.isHidden = !logView.isHidden
        if !logView.isHidden{
            if let _ = skyfieController?.aircraft {
                lb_gpsSignalLevel.text = "Level \(String(describing: skyfieController?.currentFCState?.gpsSignalLevel.rawValue))"
                lb_aircraftLocation.text = "(\(String(describing: skyfieController?.aircraftLocation.latitude)), \(String(describing: skyfieController?.aircraftLocation.longitude)))"
                lb_roll.text = "\(String(describing: skyfieController?.currentFCState?.attitude.roll))"
                lb_pitch.text = "\(String(describing: skyfieController?.currentFCState?.attitude.pitch))"
                lb_yaw.text = "\(String(describing: skyfieController?.currentFCState?.attitude.yaw))"
                lb_gimbalPitch.text = String(format: "%.3f", (skyfieController?.currentGimbalState?.attitudeInDegrees.pitch)!)
                lb_throttleMode.text = "\(String(describing: skyfieController?.aircraft.flightController?.verticalControlMode.rawValue))"
                lb_yawControlMode.text = "\(String(describing: skyfieController?.aircraft.flightController?.yawControlMode.rawValue))"
            } else {
                lb_gpsSignalLevel.text = "No Aircraft connected"
                lb_aircraftLocation.text = "Aircraft location invalid"
            }
        }
    }
    
    @IBAction func SetCenterToAircraftLocation(_ sender: Any) {
        skyfieController?.setCenterToAircraftLocation()
    }
    
    @IBAction func onZoomInButtonTouchDown(_ sender: UIButton) {
        
        let moveSpeed: Float = 1.5
        var flightInfo: Dictionary<String, Any> = [:]
        flightInfo = ["mode": FlightMode.gimbal, "moveNear": true, "speed": moveSpeed]
        skyfieController?.startTimerForZoomInOutMoveWith(flightInfo)
     
    }
    
    @IBAction func onZoomOutButtonTouchDown(_ sender: UIButton) {
        
        let moveSpeed: Float = 1.5
        var flightInfo: Dictionary<String, Any> = [:]
        flightInfo = ["mode": FlightMode.gimbal, "moveNear": false, "speed": moveSpeed]
        skyfieController?.startTimerForZoomInOutMoveWith(flightInfo)
    }
    
    @IBAction func onZoomButtonTouchUp(_ sender: UIButton) {
        // stop the aircraft and motion getting
        skyfieController?.stopFineTuningControlTimer()
        skyfieController?.stopAndHover()
        skyfieController?.startRadiusUpdateTimerWith(flightMode: .spherical)
        skyfieController?.recoverUI()
    }

    @IBAction func onMoveNearButtonTouchDown(_ sender: UIButton) {
        skyfieController?.startTimerForNearFarMove(moveNear: true)
    }
    
    @IBAction func onMoveFarButtonTouchDown(_ sender: UIButton) {
        skyfieController?.startTimerForNearFarMove(moveNear: false)
    }
    
    @IBAction func onNearFarButtonTouchUp(_ sender: UIButton) {
    }
    
    
    @IBAction func onTuningButtonTouchDown(_ sender: UIButton) {
    
        switch sender.currentTitle! {
        case "up":
            self.finetuningFor(.Up)
        case "down":
            self.finetuningFor(.Down)
        case "left":
            self.finetuningFor(.Left)
        case "right":
            self.finetuningFor(.Right)
        default:
            return
        }
    }

    
    @IBAction func onTuningButtonTouchUp(_ sender: UIButton) {
        
        var direction: FineTuningDirection
        switch sender.currentTitle! {
        case "up":
            direction = .Up
        case "down":
            direction = .Down
        case "left":
            direction = .Left
        case "right":
            direction = .Right
        default:
            return
        }
        // 如果還有被按著的按鈕要處理放開的方向
        if (skyfieController?.pressedFinetuningButtonCount)! > 0 {
            skyfieController?.stopFineTuningFor(direction: direction)
            skyfieController?.pressedFinetuningButtonCount -= 1
            
            // 當所有finetuning按鈕都放開時
            if (skyfieController?.pressedFinetuningButtonCount)! == 0 {
                self.newFineTuningEnd()
            }
        }
    }

    //var fineTuningView: FineTuningView = FineTuningView()
    weak var aircraft: DJIAircraft? = nil
    var skyfieController: SkyfieController? = nil
    
    // tmp varable store the data using to perform waypoint mission
    var directPointingHeading: CLLocationDirection? = nil
    var directPointingPitchAngle: Double = 0.0
    var directPointingDestLocation: CLLocationCoordinate2D = kCLLocationCoordinate2DInvalid
    var directPointingDestAltitude: Float = 0.0
    
    // CoreLocation related instance
    var userLocation: CLLocationCoordinate2D = kCLLocationCoordinate2DInvalid
    var phoneHeading: CLLocationDirection? = nil
    var phonePitchAngle: Double = 0.0 // in radians
    let locationManager: CLLocationManager = CLLocationManager()
    
    // Fine Tuning mode movement related instance
    var motionManager: CMMotionManager? = nil
    var motionDetect: MotionAnalyzer = MotionAnalyzer(lopaRate: 0.2)
    var motionCommand: FlyCommand?
    
    // In DJI SDK definition, Roll speed is useing as pitch (x axis) movement. Pitch as Roll (y axis) movement
    var mPitch: Float = 0.0
    var mRoll: Float = 0.0
    var mVerticalThrottle: Float = 0.0
    
    // Speed varable
    var fineTuningSpeed: Float = 1.0
    var pitchSpeedUpperBound: Float = 5
    var pitchSpeedLowerBound: Float = 1

    // Photo shooting related instances
    var isInShootPhotoMode: Bool = false {
        didSet {
            self.toggleShootPhotoButton()
        }
    }
    
    var isShootingPhoto: Bool = false {
        didSet {
            self.toggleShootPhotoButton()
        }
    }
    
    var isStoringPhoto: Bool = false {
        didSet {
            self.toggleShootPhotoButton()
        }
    }
    
    // MARK: - CONTROL FLAGS
    // Control mode flag. false = Direct Pointing Mode, true = Fine Tuning Mode
    var flag_isFineTuningViewExpanded = false
    // Flag of the coordinate system used in Fine Tuning Mode.
    var flag_isSphericalModeEnable = true // false = Cartesian, true = Spherical
    // aircraft's velocity mode in Fine Tuning Mode.
    var flag_isSpeedModeDiscrete = false // false = Linear speed, true = Discrete speed
    var flag_isFromDPtoFineTuning = true
//    var flag_isRecordingVideo: Bool = false
    // MARK:
    
    override func viewDidLoad() {
        super.viewDidLoad()
        maskView.isHidden = true
        self.aircraft = DJISDKManager.product() as? DJIAircraft
        if aircraft != nil {
            // setup skyfieController
            skyfieController = SkyfieController(aircraft: aircraft!)
            //skyfieController?.initWith(aircraft: aircraft!)
            skyfieController?.delegate = self
            // set delegate
//            aircraft?.flightController?.delegate = skyfieController
//            aircraft?.gimbal?.delegate = skyfieController
        }
        
        // fineTuningView Setup
        //self.fineTuningView = FineTuningView.init(frame: CGRect(x: self.view.frame.maxX, y: self.btn_FineTuning.frame.origin.y, width: 352, height: 139))
        //self.fineTuningView.delegate = self
        //self.fineTuningView.layer.masksToBounds = true
        //self.view!.addSubview(self.fineTuningView)
        self.fpvView.delegate = self
        
        // Ask authorisation for use in foreground from user
        // Start update userLocation and phoneHeading
        if CLLocationManager.locationServicesEnabled() {
            
            self.locationManager.delegate = self
            self.locationManager.requestWhenInUseAuthorization()
            self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
            self.locationManager.distanceFilter = 1  // In meters.
            self.locationManager.startUpdatingLocation()
            
            if CLLocationManager.headingAvailable() {
                self.locationManager.headingOrientation = CLDeviceOrientation.portrait
                self.locationManager.startUpdatingHeading()
            }
        }
        // Start update phone's pitch angle
        self.motionManager = CMMotionManager()
        startUpdatePitchAngle()
        
        mapView.showsUserLocation = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateUI), name: .updateUI, object: nil)
    }
    
    // 更新控制按鈕的狀態
    @objc func updateUI() {
        btn_GoStop.isEnabled = (skyfieController?.isGoStopButtonEnable)!
        zoomInButton.isEnabled = (skyfieController?.isZoomButtonEnable)!
        zoomOutButton.isEnabled = (skyfieController?.isZoomButtonEnable)!
        moveNearButton.isEnabled = (skyfieController?.isNearFarButtonEnable)!
        moveFarButton.isEnabled = (skyfieController?.isNearFarButtonEnable)!
        upButton.isEnabled = (skyfieController?.isFramingButtonEnable)!
        downButton.isEnabled = (skyfieController?.isFramingButtonEnable)!
        leftButton.isEnabled = (skyfieController?.isFramingButtonEnable)!
        rightButton.isEnabled = (skyfieController?.isFramingButtonEnable)!
        lb_status.text = skyfieController?.status
    }
    
    func startUpdatePitchAngle() {
        if (self.motionManager?.isDeviceMotionAvailable)! {
            self.motionManager?.deviceMotionUpdateInterval = 0.1
            self.motionManager?.startDeviceMotionUpdates(to: OperationQueue.main, withHandler: { [weak self](motion, error) -> Void in
                if let attitude = motion?.attitude {
                    self?.phonePitchAngle = attitude.pitch // in radians
                    if !(self?.logView.isHidden)! {
                        self?.lb_phonePitch.text = "\(attitude.pitch * (180 / Double.pi))"
                    }
                }
            })
        }
    }
    
    // MARK: - viewDidDisappear
    override func viewDidDisappear(_ animated: Bool) {
        self.fineTuningEnd()
        self.newFineTuningEnd()
    }
    
    // MARK: - viewWillAppear
    override func viewWillAppear(_ animated: Bool) {
        
        self.aircraft = DJISDKManager.product() as? DJIAircraft
        if aircraft != nil {
            skyfieController?.stopNewFineTuningTimer()
            skyfieController?.newFineTuneStopAndHover()
            // fpvPreviewer Setup
            setVideoPreview()
            
            // disable the shoot photo button by default
            self.btn_Snap.isEnabled = false
            
            // set delegate to render camera's video feed into the view
            let camera: DJICamera? = self.aircraft?.camera
            if camera != nil {
                camera?.delegate = self
                camera?.getModeWithCompletion({[weak self](mode: DJICameraMode, error: Error?) -> Void in
                    
                    if error != nil {
                        self?.showAlertResult("ERROR: getCameraModeWithCompletion::\(error!)")
                    }
//                    else if mode != DJICameraMode.recordVideo {
//                        // start to check the pre-condition
//                        self?.setCameraMode()
//                    }
//                    else if mode == DJICameraMode.shootPhoto {
//                        self?.isInShootPhotoMode = true
//                    }
                    else {
                        self?.setCameraMode()
                    }
                })
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.navigationController!.title = ""
        self.navigationController!.isNavigationBarHidden = false
        
        // disable virtual stick control mode
//        skyfieController?.disableVirtualStickControlMode()
        
        // clean the delegate
        let aircraft: DJIAircraft? = DJISDKManager.product() as? DJIAircraft
        if aircraft != nil && aircraft?.flightController?.delegate === skyfieController {
            aircraft!.flightController!.delegate = nil
        }
        let camera: DJICamera? = (DJISDKManager.product() as? DJIAircraft)?.camera
        if camera != nil && camera?.delegate === self {
            camera?.delegate = nil
        }
        if aircraft != nil && aircraft?.gimbal?.delegate === skyfieController {
            aircraft!.gimbal!.delegate = nil
        }
        // clean fpvPreviewer
        self.cleanVideoPreview()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // show alert msg method
    func showAlertResult(_ info:String) {
        // create the alert
        var message:String? = info
        
        if info.hasSuffix(":nil") {
            message = info.replacingOccurrences(of: ":nil", with: " success")
        }
        
        let alert = UIAlertController(title: "Message", message: "\(message ?? "")", preferredStyle: UIAlertControllerStyle.alert)
        // add an action (button)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
        // show the alert
        self.present(alert, animated: true, completion: nil)
    }
    
    // MARK: - States Update Callback Method
    
    // Tells the delegate that new location data is available.
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        self.userLocation = (locations.last?.coordinate)!
        if !logView.isHidden {
            lb_userLocation.text = "(" + String(format: "%.8f", userLocation.latitude) + ", " + String(format: "%.8f", userLocation.longitude) + ")"
        }
    }
    
    // Tells the delegate that the location manager received updated heading information.
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        if newHeading.headingAccuracy < 0 {
            return
        }
        else {
            self.phoneHeading = newHeading.magneticHeading
            if !self.logView.isHidden {
                lb_phoneHeading.text = "\(phoneHeading!)"
            }
        }
    }
    
    // MARK: - Video Previewer And Photo Shooting Method
    func setVideoPreview() {
        VideoPreviewer.instance().setView(self.fpvView)
        let product = DJISDKManager.product()
        
        //Use "SecondaryVideoFeed" if the DJI Product is A3, N3, Matrice 600, or Matrice 600 Pro, otherwise, use "primaryVideoFeed".
        if ((product?.model == DJIAircraftModelNameA3)
        || (product?.model == DJIAircraftModelNameN3)
        || (product?.model == DJIAircraftModelNameMatrice600)
        || (product?.model == DJIAircraftModelNameMatrice600Pro)) {
            DJISDKManager.videoFeeder()?.secondaryVideoFeed.add(self, with: nil)
        }
        else {
            DJISDKManager.videoFeeder()?.primaryVideoFeed.add(self, with: nil)
        }
        VideoPreviewer.instance().start()
    }
    
    func cleanVideoPreview() {
        VideoPreviewer.instance().unSetView()
        let product = DJISDKManager.product();
        
        //Use "SecondaryVideoFeed" if the DJI Product is A3, N3, Matrice 600, or Matrice 600 Pro, otherwise, use "primaryVideoFeed".
        if ((product?.model == DJIAircraftModelNameA3)
        || (product?.model == DJIAircraftModelNameN3)
        || (product?.model == DJIAircraftModelNameMatrice600)
        || (product?.model == DJIAircraftModelNameMatrice600Pro)) {
            DJISDKManager.videoFeeder()?.secondaryVideoFeed.remove(self)
        }
        else {
            DJISDKManager.videoFeeder()?.primaryVideoFeed.remove(self)
        }
    }
    
    func videoFeed(_ videoFeed: DJIVideoFeed, didUpdateVideoData rawData: Data) {
        let videoData = rawData as NSData
        let videoBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: videoData.length)
        videoData.getBytes(videoBuffer, length: videoData.length)
        VideoPreviewer.instance().push(videoBuffer, length: Int32(videoData.length))
    }
    
    func camera(_ camera: DJICamera, didUpdate systemState: DJICameraSystemState) {
//        self.flag_isRecordingVideo = systemState.isRecording
        self.isShootingPhoto = systemState.isShootingSinglePhoto || systemState.isShootingIntervalPhoto || systemState.isShootingBurstPhoto
        self.isStoringPhoto = systemState.isStoringPhoto
    }
    
    func toggleShootPhotoButton() {
        self.btn_Snap.isEnabled = (self.isInShootPhotoMode && !self.isShootingPhoto && !self.isStoringPhoto)
    }
    /**
     *  Set the camera's mode to DJICameraMode.shootPhoto.
     *  If it succeeds, we can enable the take photo button.
     */
    
    func setCameraMode() {
        let camera: DJICamera? = (DJISDKManager.product() as? DJIAircraft)?.camera
        if camera != nil {
//            camera?.setMode(DJICameraMode.recordVideo, withCompletion: nil)
            camera?.setMode(DJICameraMode.shootPhoto, withCompletion: {[weak self](error: Error?) -> Void in
                
                if error != nil {
                    self?.showAlertResult("ERROR: setCameraMode:withCompletion:\(error!)")
                }
                else {
                    // Normally, once an operation is finished, the camera still needs some time to finish up
                    // all the work. It is safe to delay the next operation after an operation is finished.
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(1 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC), execute: {() -> Void in
                        
                        self?.isInShootPhotoMode = true
                    })
                }
            })
            camera?.setPhotoAspectRatio(.ratio4_3, withCompletion: nil)
        }
    }
    
    // MARK: - Button Action Method
//    @IBAction func onFineTuningButtonClicked(_ sender: UIButton) {
//        if !flag_isFineTuningViewExpanded {
//            // open fineTuningView animated and stop update pitch angle
////            fineTuningView.frame.origin.y = btn_FineTuning.frame.origin.y
//            UIView.animate(withDuration: 0.5, animations: {() -> Void in
//                self.fineTuningView.frame.origin = CGPoint(x: self.view.frame.maxX - 352, y: self.fineTuningView.frame.origin.y)
//                self.btn_FineTuning.frame.origin = CGPoint(x: self.fineTuningView.frame.origin.x - 23, y: self.btn_FineTuning.frame.origin.y)
//            })
//            flag_isFineTuningViewExpanded = true
//            motionManager?.stopDeviceMotionUpdates()
//        }
//        else {
//            // close fineTuningView animated and start update pitch angle
//            UIView.animate(withDuration: 0.5, animations: {() -> Void in
//                self.btn_FineTuning.frame.origin = CGPoint(x: self.view.frame.maxX - 23, y: self.btn_FineTuning.frame.origin.y)
//                self.fineTuningView.frame.origin = CGPoint(x: self.view.frame.maxX, y: self.fineTuningView.frame.origin.y)
//            })
//            flag_isFineTuningViewExpanded = false
//            startUpdatePitchAngle()
//        }
//    }
    
    @IBAction func onTakeoffLandingButtonClicked(_ sender: UIButton) {
        if self.btn_TakeoffLanding.currentTitle == "Takeoff" {
            skyfieController?.aircraftTakeoff()
            maskView.isHidden = false
        }
        else if self.btn_TakeoffLanding.currentTitle == "Landing" {
            skyfieController?.aircraftLanding()
        }
    }
    
    @IBAction func onSphereModeGoStopButtonClicked(_ sender: UIButton) {
        switch btn_GoStop.currentTitle! {
        case "GO":
            // save current heading & pitchAngle, setting up direct pointing
            directPointingHeading = phoneHeading
            directPointingPitchAngle = phonePitchAngle
            skyfieController?.calibrateHeading(userHeading: directPointingHeading, userPhonePitch: directPointingPitchAngle)
        case "Stop":
            skyfieController?.interruptDirectPointing()
        default:
            return
        }
    }
    
    @IBAction func onGoStopButtonClicked(_ sender: UIButton) {
        switch btn_GoStop.currentTitle! {
        case "GO":
            // save current heading & pitchAngle, setting up direct pointing
            setUserCenter(location: userLocation)
            directPointingHeading = phoneHeading
            directPointingPitchAngle = phonePitchAngle
            skyfieController?.setDirectPointingDestinationWith(directPointingHeading: directPointingHeading!, userElevation: directPointingPitchAngle)
        case "Stop":
            skyfieController?.stopDirectPointing()
        default:
            return
        }
    }
    
    @IBAction func onSnapButtonClicked(_ sender: UIButton) {
        // record the video
        let camera: DJICamera? = (DJISDKManager.product() as? DJIAircraft)?.camera
        
        if camera != nil {
//            if flag_isRecordingVideo == false {
//                // start record
//                camera?.startRecordVideo(completion: {[weak self](error: Error?) -> Void in
//                    if error != nil {
//                        self?.showAlertResult("ERROR: startRecordVideoWithCompletion::\(error!)")
//                    }
//                    else {
//                        self?.btn_Snap.setTitleColor(UIColor.red, for: UIControlState.normal)
//                    }
//                })
//            }
//            else {
//                // stop record
//                camera?.stopRecordVideo(completion: {[weak self](error: Error?) -> Void in
//                    if error != nil {
//                        self?.showAlertResult("ERROR: stopRecordVideoWithCompletion::\(error!)")
//                    }
//                    else {
//                        self?.btn_Snap.setTitleColor(UIColor.blue, for: UIControlState.normal)
//                    }
//                })
//            }
            self.btn_Snap.isEnabled = false
            camera?.startShootPhoto(completion: {[weak self](error: Error?) -> Void in
                if error != nil {
                    self?.showAlertResult("ERROR: startShootPhoto:withCompletion::\(error!)")
                }
                else {
                    self?.showAlertResult("Photo has been saved")
                }
            })
        }
    }
    
    // MARK: - SkyfieController delegate Methods
    func didAircraftTakeoff() {
        self.btn_TakeoffLanding.setTitle("Landing", for: UIControlState.normal)
        self.maskView.isHidden = true
    }
    
    // for takeoff without using btn_TakeoffLanding
    func aircraftIsTakingOff() {
        self.btn_TakeoffLanding.setTitle("Landing", for: UIControlState.normal)
    }
    
    func didAircraftLanding() {
        btn_TakeoffLanding.setTitle("Takeoff", for: UIControlState.normal)
    }
    
    func didDirectPointingStartWith(destLocation: CLLocationCoordinate2D, destAltitude: Float) {
        flag_isFromDPtoFineTuning = true
        directPointingDestLocation = destLocation
        directPointingDestAltitude = destAltitude
        btn_GoStop.setTitle("Stop", for: UIControlState.normal)
    }
    
    func didDirectPointingEnd() {
        btn_GoStop.setTitle("GO", for: UIControlState.normal)
    }
    
    func didDirectPointingStop() {
        //showAlertResult("Mission complete")
        btn_GoStop.setTitle("GO", for: UIControlState.normal)
    }
    
    func didAircraftHeadingCalibrated() {
        print("Heading Calibration Finished")
        btn_GoStop.setTitle("GO", for: UIControlState.normal)
//        fpvView.flag_isHeadingOK = true
    }
    
    func showAlertResultOnView(_ info: String) {
        self.showAlertResult(info)
    }
    
    // MARK: - FineTuningView Delegate Method
    func pitchControlStart() {
//        fpvView.flag_isHeadingOK = false
        clearCtrlData()
        // start pitch control for aircraft's front/back movement
        startGetMotion()
    }
    
    func pitchControlEnd() {
        // stop the aircraft and motion getting
        skyfieController?.stopFineTuningControlTimer()
        skyfieController?.stopAndHover()
        stopGetMotion()
        
        // start timer to reset circular radius to current real radius when aircraft being hover
        if flag_isSphericalModeEnable {
            skyfieController?.startRadiusUpdateTimerWith(flightMode: .spherical)
        }
        else { // cartesian
            skyfieController?.startRadiusUpdateTimerWith(flightMode: .cartesian)
        }
    }
    
    func finetuningFor(_ direction: FineTuningDirection) {
        clearCtrlData()
        skyfieController?.newFineTuneMove(direction: direction)
    }
    
    func fineTuningEnd() {
        // stop the aircraft
        clearCtrlData()
        skyfieController?.stopFineTuningControlTimer()
        skyfieController?.stopAndHover()
        skyfieController?.startRadiusUpdateTimerWith(flightMode: .spherical)
    }
    
    func newFineTuningEnd() {
        skyfieController?.stopNewFineTuningTimer()
        skyfieController?.newFineTuneStopAndHover()
        skyfieController?.startRadiusUpdateTimerWith(flightMode: .spherical)
        skyfieController?.recoverUI()
    }
    
    func shouldControlModeChange(to mode: FlightMode) {
        lb_currentControlMode.text = mode.rawValue
        if mode == .spherical{
            flag_isSphericalModeEnable = true
        }
        if mode == .cartesian{
            flag_isSphericalModeEnable = false
        }
    }
    
    // MARK: - Fine Tuning Mode Movement Method
    func startGetMotion() {
        if (self.motionManager?.isDeviceMotionAvailable)! {
            var initTimer = 0
            var prevMotion: Dictionary<String, Double>?
            motionManager?.deviceMotionUpdateInterval = 0.1
            motionManager?.startDeviceMotionUpdates(to: OperationQueue.main, withHandler: { [weak self](motion, error) -> Void in
                if initTimer <= 2 {
                    if prevMotion == nil{
                        prevMotion = ["x":(motion?.gravity.x)!, "y": (motion?.gravity.y)!, "z": (motion?.gravity.z)!]
                    }
                    else{
                        self?.motionDetect.setInitMotion(firstMotion: prevMotion!, secondMotion: ["x":(motion?.gravity.x)!, "y": (motion?.gravity.y)!, "z": (motion?.gravity.z)!])
                    }
                    initTimer += 1
                }
                else {
                    self?.commandPool(allFlyCommand: (self?.motionDetect.translate(sensorData: motion!))!)
                }
            })
        }
    }
    
    func stopGetMotion() {
        if (motionManager?.isDeviceMotionAvailable)! {
            motionManager?.stopDeviceMotionUpdates()
            motionDetect.clearData()
        }
    }
    
    func commandPool(allFlyCommand: FlyCommand) -> Void {
        motionCommand = allFlyCommand
        var flightInfo: Dictionary<String, Any> = [:]
        
        if motionCommand!.front != 0 { // far
            let moveSpeed = getPitchControlVelocity(motionCommand!.front)
            
//            if flag_isSphericalModeEnable == true {
                flightInfo = ["mode": FlightMode.spherical, "moveNear": false, "speed": moveSpeed]
//            }
//            else { // Cartesian
//                let userHeading = Double(phoneHeading!)
//                flightInfo = ["mode": "cartesian", "heading": userHeading, "speed": moveSpeed, "direction": "front"]
//            }
            skyfieController?.startTimerForZoomInOutMoveWith(flightInfo)
        }
        if motionCommand!.back != 0 { // near
            let moveSpeed = getPitchControlVelocity(motionCommand!.back)
            
//            if flag_isSphericalModeEnable == true {
                flightInfo = ["mode": FlightMode.spherical, "moveNear": true, "speed": moveSpeed]
//            }
//            else { // Cartesian
//                let userHeading = Double(phoneHeading!)
//                flightInfo = ["mode": "cartesian", "heading": userHeading, "speed": moveSpeed, "direction": "back"]
//            }
            skyfieController?.startTimerForZoomInOutMoveWith(flightInfo)
        }
    }
    
    func getPitchControlVelocity(_ rawValue: Float) -> Float {
        if flag_isSpeedModeDiscrete == false { // linear velocity
            if rawValue == 0 {
                return 0
            }
            let remapedSpeed = rawValue * pitchSpeedUpperBound / 15
            return remapedSpeed
        }
        else { // discrete velocity
            let middleSpeed = (pitchSpeedUpperBound + pitchSpeedLowerBound) / 2
            
            if rawValue == 0 {
                return 0
            }
            else if (rawValue < 0 && rawValue >= -5) || (rawValue > 0 && rawValue <= 5) {
                if rawValue > 0 {
                    return pitchSpeedLowerBound
                }
                else {
                    return -pitchSpeedLowerBound
                }
            }
            else if (rawValue < -5 && rawValue >= -10) || (rawValue > 5 && rawValue <= 10) {
                if rawValue > 0 {
                    return middleSpeed
                }
                else {
                    return -middleSpeed
                }
            }
            else { // mRoll < -10 or mRoll > 10
                if rawValue > 0 {
                    return pitchSpeedUpperBound
                }
                else {
                    return -pitchSpeedUpperBound
                }
            }
        }
    }
    
    func clearCtrlData() {
        self.mPitch = 0.0
        self.mRoll = 0.0
        self.mVerticalThrottle = 0.0
    }
    
    // MARK: - LogViewController Delegate Method
    func speedRangeUpperBoundShouldChangeTo(_ velocity: Float) {
        self.pitchSpeedUpperBound = velocity
        print("speedUpperBound changed: \(velocity)")
    }
    func speedRangeLowerBoundShouldChangeTo(_ velocity: Float) {
        self.pitchSpeedLowerBound = velocity
        print("speedLowerBound changed: \(velocity)")
    }
    
    func speedModeShouldChange() {
        if flag_isSpeedModeDiscrete {
            flag_isSpeedModeDiscrete = false
        }
        else {
            flag_isSpeedModeDiscrete = true
        }
        ////////
        print("speed Mode changed: \(flag_isSpeedModeDiscrete)")
        ////////
    }

    func setUserCenter(location: CLLocationCoordinate2D) {
        skyfieController?.updateCenterTo(location: location)
    }
    
    // MARK: - FPVView Delegated Method
//    func headingShouldCalibrate() {
//        skyfieController?.startTimerForHeadingCalibration()
//    }
    func framingTuningfor(_ direction: String) {
        if direction == "Up" || direction == "Down" {
            skyfieController?.GimbalTuningForFramingTuning(to: direction)
        }
        if direction == "Right" {
            skyfieController?.startTimerForFramingTuning(1)
        }
        if direction == "Left" {
            skyfieController?.startTimerForFramingTuning(-1)
        }
        if direction == "SoH" { // stay on horizontal direction
            skyfieController?.startTimerForFramingTuning(0)
        }
    }
    
    func framingTuningEnd() {
        skyfieController?.GimbalStop()
        skyfieController?.stopFineTuningControlTimer()
        skyfieController?.stopAndHover()
    }
    
    // MARK: - Navigation to Log Page
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toLog" {
            let logViewController = segue.destination as! LogViewController
            logViewController.delegate = self
            logViewController.heading = self.directPointingHeading
            logViewController.pitchAngle = self.directPointingPitchAngle
            logViewController.userLocation = userLocation
            logViewController.destLocation = self.directPointingDestLocation
            logViewController.destAltitude = self.directPointingDestAltitude
            logViewController.speedUpperBound = Int(self.pitchSpeedUpperBound)
            logViewController.speedLowerBound = Int(self.pitchSpeedLowerBound)
            
            if flag_isSpeedModeDiscrete {
                logViewController.speedModeUsing = "SpeedMode: Discrete"
            }
            else {
                logViewController.speedModeUsing = "SpeedMode: Linear"
            }
            
            if flag_isSphericalModeEnable {
                logViewController.coordiSysUsing = "CoordiSys: Spherical"
            }
            else {
                logViewController.coordiSysUsing = "CoordiSys: Cartesian"
            }
        }
    }
}

extension Notification.Name {
    static let updateUI = Notification.Name("updateUI")
}

