//
//  ViewController.swift
//  MapGo
//
//  Created by Islam on 4/10/20.
//  Copyright © 2020 Islam. All rights reserved.
//

import UIKit
import YandexMapKit
import YandexMapKitPlaces
import YandexMapKitDirections
import YandexMapKitSearch
import CoreLocation

class ViewController: UIViewController {
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var mapView: YMKMapView!
    
    let locationManager = CLLocationManager()
    let geoCoder: YMKGeoObject! = YMKGeoObject()
    let searchManager = YMKSearch.sharedInstance().createSearchManager(with: .combined)
    var searchSession: YMKSearchSession?
    var userLocationLayer: YMKUserLocationLayer!
    
    var currentLocation: YMKPoint?
    var directonLocation: YMKPoint?
    var drivingSession: YMKDrivingSession?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocationManager()
        checkLocationAuthorization()
    }
    
    func centerViewOnUserLocation() {
        if let location = YMKLocationManager.lastKnownLocation()?.position {
            
            mapView.mapWindow.map.isRotateGesturesEnabled = false
            let mapKit = YMKMapKit.sharedInstance()
            
            if userLocationLayer == nil{
                userLocationLayer = mapKit.createUserLocationLayer(with: mapView.mapWindow)
                userLocationLayer.setVisibleWithOn(true)
                userLocationLayer.isHeadingEnabled = true
                let yLocation = YMKPoint(latitude: location.latitude, longitude: location.longitude)
                mapView.mapWindow.map.move(with:
                    YMKCameraPosition(target: yLocation, zoom: 14, azimuth: 0, tilt: 0))
                mapView.mapWindow.map.addTapListener(with: self)
                mapView.mapWindow.map.addCameraListener(with: self)
                userLocationLayer.setObjectListenerWith(self)
            }
        }
    }
    
    func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func checkLocationServices() {
        if CLLocationManager.locationServicesEnabled() {
            setupLocationManager()
            checkLocationAuthorization()
        } else {
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    func checkLocationAuthorization() {
        switch CLLocationManager.authorizationStatus() {
        case .authorizedWhenInUse:
            centerViewOnUserLocation()
        case .denied:
            // Show alert instructing them how to turn on permissions
            break
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            break
        case .restricted:
            // Show an alert letting them know what's up
            break
        case .authorizedAlways:
            break
        @unknown default:
            break
        }
    }
    
    @IBAction func goBtnDirectios(_ sender: Any) {
        
        let requestPoints : [YMKRequestPoint] = [
            YMKRequestPoint(point: currentLocation!, type: .waypoint, pointContext: nil),
            YMKRequestPoint(point: directonLocation!, type: .waypoint, pointContext: nil),
        ]
        
        let responseHandler = {(routesResponse: [YMKDrivingRoute]?, error: Error?) -> Void in
            if let routes = routesResponse {
                self.onRoutesReceived(routes)
            } else {
                self.onRoutesError(error!)
            }
        }
        
        
        let drivingRouter = YMKDirections.sharedInstance().createDrivingRouter()
        drivingSession = drivingRouter.requestRoutes(
            with: requestPoints,
            drivingOptions: YMKDrivingDrivingOptions(),
            routeHandler: responseHandler)
    }
    
    func onRoutesReceived(_ routes: [YMKDrivingRoute]) {
        
        let mapObjects = mapView.mapWindow.map.mapObjects
        mapObjects.clear()
        mapObjects.addPlacemark(with: directonLocation!, image: #imageLiteral(resourceName: "pin"), style: YMKIconStyle(anchor: CGPoint(x: 0.5, y: 0.5) as NSValue,
                    rotationType: YMKRotationType.rotate.rawValue as NSNumber,
                    zIndex: 2,
                    flat: true,
                    visible: true,
                    scale: 0.15,
                    tappableArea: nil))
        
        for route in routes {
            mapObjects.addPolyline(with: route.geometry).strokeColor = generateRandomColor()
        }
    }
    
    @IBAction func cleanMap(_ sender: Any) {
        let mapObjects = mapView.mapWindow.map.mapObjects
        mapObjects.clear()
    }
    
    func generateRandomColor() -> UIColor {
        let redValue = CGFloat.random(in: 0...1)
        let greenValue = CGFloat.random(in: 0...1)
        let blueValue = CGFloat.random(in: 0...1)
        
        let randomColor = UIColor(red: redValue, green: greenValue, blue: blueValue, alpha: 1.0)
        
        return randomColor
    }
    
    func onRoutesError(_ error: Error) {
        let routingError = (error as NSError).userInfo[YRTUnderlyingErrorKey] as! YRTError
        var errorMessage = "Unknown error"
        if routingError.isKind(of: YRTNetworkError.self) {
            errorMessage = "Network error"
        } else if routingError.isKind(of: YRTRemoteError.self) {
            errorMessage = "Remote server error"
        }
        
        let alert = UIAlertController(title: "Error", message: errorMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        
        present(alert, animated: true, completion: nil)
    }
    
    
}

extension ViewController: YMKUserLocationObjectListener{
    func onObjectRemoved(with view: YMKUserLocationView) {
        
    }
    
    func onObjectUpdated(with view: YMKUserLocationView, event: YMKObjectEvent) {
        
    }
    
    func onObjectAdded(with view: YMKUserLocationView) {
        
        view.arrow.setIconWith(UIImage(named:"UserArrow")!)
        
        let pinPlacemark = view.pin.useCompositeIcon()
        
        pinPlacemark.setIconWithName(
            "pin",
            image: UIImage(named:"SearchResult")!,
            style:YMKIconStyle(
                anchor: CGPoint(x: 0.5, y: 0.5) as NSValue,
                rotationType:YMKRotationType.rotate.rawValue as NSNumber,
                zIndex: 1,
                flat: true,
                visible: true,
                scale: 1,
                tappableArea: nil))
        
        view.accuracyCircle.fillColor = #colorLiteral(red: 0.4745098054, green: 0.8392156959, blue: 0.9764705896, alpha: 0.7636986301)
    }
    
    
    
}


extension ViewController: YMKMapCameraListener, YMKLayersGeoObjectTapListener{
    func onCameraPositionChanged(with map: YMKMap, cameraPosition: YMKCameraPosition, cameraUpdateSource: YMKCameraUpdateSource, finished: Bool) {
        addressLabel.text = ""
        
        let point = YMKPoint(latitude: cameraPosition.target.latitude, longitude: cameraPosition.target.longitude)
        
        let responseHandler = {(searchResponse: YMKSearchResponse?, error: Error?) -> Void in
            if let response = searchResponse {
                self.onSearchResponse(response)
            }
        }
        
        searchSession = searchManager.submit(with: point, zoom: 15, searchOptions: YMKSearchOptions(), responseHandler: responseHandler)
        
        guard let location = YMKLocationManager.lastKnownLocation()?.position else { return }
        currentLocation = location
        directonLocation = point
        return
    }
    
    func onObjectTap(with event: YMKGeoObjectTapEvent) -> Bool {
        addressLabel.text = ""
        let obj = event.geoObject
        addressLabel.text = obj.name ?? ""
        
        guard let point = obj.geometry.first?.point else {
            return true
        }
        
        let responseHandler = {(searchResponse: YMKSearchResponse?, error: Error?) -> Void in
            if let response = searchResponse {
                self.onSearchResponse(response)
            }
        }
        
        searchSession = searchManager.submit(with: point, zoom: 15, searchOptions: YMKSearchOptions(), responseHandler: responseHandler)
        
        return true
    }
    
    func onSearchResponse(_ response: YMKSearchResponse) {
        
        guard let searchResult = response.collection.children.first else{ return }
        
        guard let obj = searchResult.obj else { return }
        addressLabel.text = obj.name ?? ""

    }
    
    func onSearchError(_ error: Error) {
        
        let searchError = (error as NSError).userInfo[YRTUnderlyingErrorKey] as! YRTError
        var errorMessage = "Unknown error"
        if searchError.isKind(of: YRTNetworkError.self) {
            errorMessage = "Network error"
        } else if searchError.isKind(of: YRTRemoteError.self) {
            errorMessage = "Remote server error"
        }
        let alert = UIAlertController(title: "Error", message: errorMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
    }
}

extension ViewController: CLLocationManagerDelegate{
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        checkLocationAuthorization()
    }
}
