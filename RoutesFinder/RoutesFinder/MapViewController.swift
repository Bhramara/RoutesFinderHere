//
//  MapViewController.swift
//  RoutesFinder
//
//  Created by Bhramara dixit on 04/09/21.
//

import heresdk
import UIKit

struct Locations: Codable {
    let locations: [LocationModel]?
}

struct LocationModel: Codable {
    let locationCoordinates: [String]//[[String: Any]]
    let type: String?
}

enum CodingKeys: String, CodingKey {
    case locationCoordinates = "locationcoords"
    case type = "type"
}

class MapViewController: UIViewController {

    @IBOutlet private var mapView: MapViewLite!
    @IBOutlet weak var startAddress: UITextField!
    @IBOutlet weak var endAddress: UITextField!
    @IBOutlet weak var routeButton: UIButton!
    
    private var isMapSceneLoaded = false
    private var routingManager: RoutingManager!
    private var mapMarkers = [MapMarkerLite]()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        mapView.mapScene.loadScene(mapStyle: .normalDay, callback: onLoadScene)
        let camera = mapView.camera
        camera.setTarget(GeoCoordinates(latitude: 52.520798, longitude: 13.409408))
        camera.setZoomLevel(12)
    }

    func onLoadScene(errorCode: MapSceneLite.ErrorCode?) {
        guard errorCode == nil else {
            print("Error: Map scene not loaded, \(String(describing: errorCode))")
            return
        }

        routingManager = RoutingManager(viewController: self, mapView: mapView!)
        isMapSceneLoaded = true
        
        fetchLocationAlertsData()
    }

    // Task 2 - Fetch JSON list of Location alerts for hazard, congestion and construction types
    func fetchLocationAlertsData() {
        if let url = URL(string: "http://wobdigital.de:44445/alerts") {
            let session = URLSession(configuration: .default)
            
            let task = session.dataTask(with: url) { (data, response, error) in
                                
                if error != nil {
                    print("Error: Could not fetch the location alerts, \(String(describing: error!))")
                    return
                }
                if let locationData = data {
                    
                    do {
                        let jsonResult = try JSONSerialization.jsonObject(with: locationData, options: JSONSerialization.ReadingOptions.mutableContainers) as? [Any]
                        print("FETCHED LOCATION ALERTS FOR \(jsonResult!.count) locations")
                        for locationDict in jsonResult as! [Dictionary<String, AnyObject>] {
                            let type = locationDict["type"] as! String
                            let locationCoordinatesArr = locationDict["locationcoords"] as! [Double]
                            let latitude =  locationCoordinatesArr[0] // 52.5200
                            let longitude = locationCoordinatesArr[1] // 13.4050

                            let coordinates = GeoCoordinates(latitude: latitude, longitude: longitude)
                            print("ADDING \(type) MARKERS FOR THE COORDINATES \(latitude) \(longitude))")
                            self.routingManager.addCircleMapMarker(geoCoordinates: coordinates, imageName: type)
                        }
                    } catch {
                        print(error)
                    }
                }
            }
            task.resume()
        }
    }
 
    @IBAction func didTapRoute(_ sender: UIButton) {
        guard let startLoc = startAddress.text else {
            routingManager.showDialog(title: "Fields Empty", message: "Enter the address")
            return
        }

        routingManager.fetchRoute(from: startLoc, to: endAddress.text!)
    }

    @IBAction func didTapUserLocation(_ sender: UIButton) {
        routingManager.fetchCurrentLocation()
    }

    @IBAction func zoomIn(_ sender: UIButton) {

        let camera = mapView.camera
        let currentZoomLevel = camera.getZoomLevel()
        camera.setZoomLevel(currentZoomLevel-1)
    }

    @IBAction func zoomOut(_ sender: UIButton) {

        let camera = mapView.camera
        let currentZoomLevel = camera.getZoomLevel()
        camera.setZoomLevel(currentZoomLevel+1)
    }
}

extension MapViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
