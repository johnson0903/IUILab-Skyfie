//
//  LogViewController.swift
//  DJI_DPControl
//
//  Created by 康平 on 2017/1/14.
//  Copyright © 2017年 康平. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

protocol LogViewControllerDelegate: NSObjectProtocol {
    func speedRangeUpperBoundShouldChangeTo(_ velocity : Float)
    func speedRangeLowerBoundShouldChangeTo(_ velocity : Float)
    func speedModeShouldChange()
    func setUserCenter(location: CLLocationCoordinate2D)
}

class LogViewController: UIViewController, UITextFieldDelegate, MKMapViewDelegate {
    @IBOutlet var lb_heading: UILabel!
    @IBOutlet var lb_pitchAngle: UILabel!
    @IBOutlet var lb_usrLocation: UILabel!
    @IBOutlet var lb_destLocation: UILabel!
    @IBOutlet var lb_destAltitude: UILabel!
    
    // display the statuses of the three kinds of control mode using
    @IBOutlet var lb_speedMode: UILabel!
    @IBOutlet var lb_coordinateSystem: UILabel!
    @IBOutlet var lb_centerMode: UILabel!
    
    @IBOutlet var upperBoundTextField: UITextField!
    @IBOutlet var lowerBoundTextField: UITextField!
    @IBOutlet var resetCenterButton: UIButton!

    //Add by johnson
    @IBOutlet weak var mapView: MKMapView!
    let locationManager = CLLocationManager()
    let places = Place.getPlaces()
    
    var heading: CLLocationDirection? = nil
    var pitchAngle: Double = 0.0
    var userLocation: CLLocationCoordinate2D = kCLLocationCoordinate2DInvalid
    var destLocation: CLLocationCoordinate2D = kCLLocationCoordinate2DInvalid
    var destAltitude: Float = 0.0
    var speedModeUsing: String = ""
    var coordiSysUsing: String = ""
    var centerModeUsing: String = ""
    var speedUpperBound: Int = 0
    var speedLowerBound: Int = 0
    
    weak var delegate: LogViewControllerDelegate? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        //Add by Johnson
        mapView?.showsUserLocation = true
        requestLocationAccess()
        addAnnotations()
        
        // Set the zoom level
        let region =
            MKCoordinateRegionMakeWithDistance(userLocation, 250, 250)
        self.mapView.setRegion(region, animated: false)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if heading == nil {
            lb_heading.text = "Heading: -"
        }
        else{
            lb_heading.text = "Heading: " + String(format: "%.3f", heading!)
        }
        lb_pitchAngle.text = "PitchAngle: " + String(format: "%.3f", (pitchAngle * 180 / .pi))
        lb_usrLocation.text = "Center Location: (" + String(format: "%.6f", userLocation.longitude) + ", " + String(format: "%.6f", userLocation.latitude) + ")"
        lb_destLocation.text = "DestLocation: (" + String(format: "%.6f", destLocation.longitude) + ", " + String(format: "%.6f", destLocation.latitude) + ")"
        lb_destAltitude.text = "DestAltitude: " + String(format:"%.3f", destAltitude)
        lb_speedMode.text = speedModeUsing
        lb_coordinateSystem.text = coordiSysUsing
        lb_centerMode.text = centerModeUsing
        upperBoundTextField.text = String(speedUpperBound)
        lowerBoundTextField.text = String(speedLowerBound)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Button Action
    @IBAction func onSpeedModeButtonClicked(_ sender: UIButton) {
        if lb_speedMode.text == "SpeedMode: Linear" {
            lb_speedMode.text = "SpeedMode: Discrete"
        }
        else if lb_speedMode.text == "SpeedMode: Discrete" {
            lb_speedMode.text = "SpeedMode: Linear"
        }
        
        self.delegate?.speedModeShouldChange()
    }

    @IBAction func onResetCenterButtonClicked(_ sender: UIButton) {
        self.delegate?.setUserCenter(location: userLocation)
    }
    @IBAction func onEnterSpeedRangeUpperBound(_ sender: UITextField) {
        if Float(sender.text!)! > 15 {
            showProgressAlert("Upper bound cannot larger than 15")
            sender.text = "15"
        }
        self.delegate?.speedRangeUpperBoundShouldChangeTo(Float(sender.text!)!)
    }
    @IBAction func onEnterSpeedRangeLowerBound(_ sender: UITextField) {
        self.delegate?.speedRangeLowerBoundShouldChangeTo(Float(sender.text!)!)
    }
    

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField.isFirstResponder {
            textField.resignFirstResponder()
        }

        return true
    }
    
    func showProgressAlert(_ msg: String?) {
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
    
    //Get access to user's location.
    func requestLocationAccess() {
        let status = CLLocationManager.authorizationStatus()
        
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            return
            
        case .denied, .restricted:
            print("location access denied")
            
        default:
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    //Add annotations to mapView
    func addAnnotations() {
        mapView?.delegate = self
        mapView?.addAnnotations(places)
    }

    @IBAction func setCenterToLocation(_ sender: UIButton) {
        let index = Int(sender.currentTitle!)! - 1
        let newCenterLocation = places[index].coordinate
        self.delegate?.setUserCenter(location: newCenterLocation)
    }

}
