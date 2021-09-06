//
//  RoutingManager.swift
//  RoutesFinder
//
//  Created by Bhramara dixit on 04/09/21.
//

import heresdk
import UIKit
import CoreLocation

// Core location instance is needed for requesting location authorization.
private let locationManager = CLLocationManager()

class RoutingManager: LocationDelegate {

    private var viewController: UIViewController
    private var mapView: MapViewLite
    private var mapMarkers = [MapMarkerLite]()
    private var mapPolylineList = [MapPolylineLite]()
    private var routingEngine: RoutingEngine
    private var startGeoCoordinates: GeoCoordinates?
    private var destinationGeoCoordinates: GeoCoordinates?
    private var searchEngine: SearchEngine
    private var mapScene: MapSceneLite

    private var shouldFetchCoordinatesForStartLocation = false
    private var shouldFetchCoordinatesForDestLocation = false
    private var endLocationString = ""

    init(viewController: UIViewController, mapView: MapViewLite) {
        self.viewController = viewController
        self.mapView = mapView
        let camera = mapView.camera
        camera.setTarget(GeoCoordinates(latitude: 52.520798, longitude: 13.409408))
        camera.setZoomLevel(12)
        mapScene = mapView.mapScene

        do {
            try routingEngine = RoutingEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize routing engine. Cause: \(engineInstantiationError)")
        }
        
        do {
            try searchEngine = SearchEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize SearchEngine. Cause: \(engineInstantiationError)")
        }
        
        self.ensureLocationAuthorization()
    }
    
    func fetchCurrentLocation() {
        let locaationManager = CLLocationManager()
        let currentLocation = locaationManager.location
        let currentLocationCoordinates = currentLocation?.coordinate
        
        let currentLocationLatitude = Double (currentLocationCoordinates!.latitude)
        let currentLocationLongitude = Double (currentLocationCoordinates!.longitude)
        
        let currentLocationGeoCoordinates = GeoCoordinates(latitude: currentLocationLatitude, longitude: currentLocationLongitude)

        let camera = mapView.camera
        camera.setTarget(currentLocationGeoCoordinates)
        camera.setZoomLevel(12)
        addCircleMapMarker(geoCoordinates: currentLocationGeoCoordinates, imageName: "poi.png")
    }

    public func ensureLocationAuthorization() {
        // Get current location authorization status.
        let locaationManager = CLLocationManager()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest

        let locationAuthorizationStatus = locaationManager.authorizationStatus

        // Check authorization.
        switch locationAuthorizationStatus {
        case .notDetermined:
            // Not determined, request for authorization.
            locationManager.requestAlwaysAuthorization()
            break
        case .denied, .restricted:
            // Denied or restricted, request for user action.
            let alert = UIAlertController(title: "Location services are disabled", message: "Please enable location services in your device settings.", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            alert.addAction(okAction)
            viewController.present(alert, animated: true, completion: nil)
            break
        case .authorizedAlways, .authorizedWhenInUse:
            // Authorized, ok to continue.
            break
        default:
            fatalError("Unknown location authorization status: \(locationAuthorizationStatus).")
        }
    }
    
    func onLocationUpdated(_ location: Location) {
        print("Location updated")
    }

    private func geocodeAddressAtLocation(queryString: String, geoCoordinates: GeoCoordinates) {
        clearMap()

        let query = AddressQuery(queryString, near: geoCoordinates)
        let geocodingOptions = SearchOptions(languageCode: LanguageCode.deDe,
                                             maxItems: 25)
        _ = searchEngine.search(addressQuery: query,
                                options: geocodingOptions,
                                completion: onGeocodingCompleted)
    }

    // Completion handler to receive geocoding results.
    func onGeocodingCompleted(error: SearchError?, items: [Place]?) {
        if let searchError = error {
            showDialog(title: "Geocoding", message: "Error: \(searchError)")
            return
        }

        for geocodingResult in items! {
            // Note that geoCoordinates are always set, but can be nil for suggestions only.
            let geoCoordinates = geocodingResult.geoCoordinates!

            if (shouldFetchCoordinatesForStartLocation) {
                print("FETCHING COORDINATES for Start Location \(geoCoordinates.latitude) \(geoCoordinates.longitude)")
                startGeoCoordinates = GeoCoordinates(latitude: geoCoordinates.latitude, longitude: geoCoordinates.longitude)
                shouldFetchCoordinatesForStartLocation = !shouldFetchCoordinatesForStartLocation
                
                shouldFetchCoordinatesForDestLocation = true
                geocodeAddressAtLocation(queryString: endLocationString, geoCoordinates: geoCoordinates)
                return
            }
            
            // Task 1 - Display Final Route only after fetching coordinates for both the Start and Destination Locations
            if (shouldFetchCoordinatesForDestLocation) {
                print("FETCHING COORDINATES for Destination Location \(geoCoordinates.latitude) \(geoCoordinates.longitude)")
                destinationGeoCoordinates = GeoCoordinates(latitude: geoCoordinates.latitude, longitude: geoCoordinates.longitude)
                shouldFetchCoordinatesForDestLocation = !shouldFetchCoordinatesForDestLocation

                showFinalRoute(for: startGeoCoordinates!, destCoordinates: destinationGeoCoordinates!)
            }
        }
    }

    // Task 1 - Fetch route map from Start to Destination Locations
    func fetchRoute(from startLocation: String, to endLocation: String) {
        clearMap()

        let geoCoordinates = GeoCoordinates(latitude: 52.537931, longitude: 13.384914)
        shouldFetchCoordinatesForStartLocation = true
        endLocationString = endLocation
        
        geocodeAddressAtLocation(queryString: startLocation, geoCoordinates: geoCoordinates)
    }

    func showFinalRoute(for startCoordinates: GeoCoordinates, destCoordinates: GeoCoordinates) {
        let carOptions = CarOptions()
        routingEngine.calculateRoute(with: [Waypoint(coordinates: startCoordinates),
                                            Waypoint(coordinates: destCoordinates)],
                                     carOptions: carOptions) { (routingError, routes) in

            if let error = routingError {
                self.showDialog(title: "Error while calculating a route:", message: "\(error)")
                return
            }

            // When routingError is nil, routes is guaranteed to contain at least one route.
            let route = routes!.first
            self.showRouteOnMap(route: route!)
        }
    }
    
    private func showRouteOnMap(route: Route) {
        // Show route as polyline.
        let routeGeoPolyline = try! GeoPolyline(vertices: route.polyline)
        let mapPolylineStyle = MapPolylineStyleLite()
        mapPolylineStyle.setColor(0x00908AA0, encoding: .rgba8888)
        mapPolylineStyle.setWidthInPixels(inPixels: 10)
        let routeMapPolyline = MapPolylineLite(geometry: routeGeoPolyline, style: mapPolylineStyle)
        mapView.mapScene.addMapPolyline(routeMapPolyline)
        mapPolylineList.append(routeMapPolyline)

        // Draw a circle to indicate starting point and destination.
        addCircleMapMarker(geoCoordinates: startGeoCoordinates!, imageName: "green_dot.png")
        addCircleMapMarker(geoCoordinates: destinationGeoCoordinates!, imageName: "green_dot.png")

        let startLatitude = Double (startGeoCoordinates!.latitude - 0.5)
        let startLongitude = Double (startGeoCoordinates!.longitude - 0.5)
        let endLatitude = Double (destinationGeoCoordinates!.latitude + 0.5)
        let endLongitude = Double (destinationGeoCoordinates!.longitude + 0.5)

        let startNearGeoCoordinates = GeoCoordinates(latitude: startLatitude, longitude: startLongitude)
        let endNearGeoCoordinates = GeoCoordinates(latitude: endLatitude, longitude: endLongitude)

        // Task 3 - Adding random markers along the route
        addCircleMapMarker(geoCoordinates: startNearGeoCoordinates, imageName: "red_dot.png")
        addCircleMapMarker(geoCoordinates: endNearGeoCoordinates, imageName: "red_dot.png")

        // Log maneuver instructions per route section.
        let sections = route.sections
        for section in sections {
            logManeuverInstructions(section: section)
        }
    }

    private func logManeuverInstructions(section: Section) {
        print("Log maneuver instructions per route section:")
        let maneuverInstructions = section.maneuvers
        for maneuverInstruction in maneuverInstructions {
            let maneuverAction = maneuverInstruction.action
            let maneuverLocation = maneuverInstruction.coordinates
            let maneuverInfo = "\(maneuverInstruction.text)"
                + ", Action: \(maneuverAction)"
                + ", Location: \(maneuverLocation)"
            print(maneuverInfo)
        }
    }

    func clearMap() {
        clearWaypointMapMarker()
        clearRoute()
    }

    private func clearWaypointMapMarker() {
        for mapMarker in mapMarkers {
            mapView.mapScene.removeMapMarker(mapMarker)
        }
        mapMarkers.removeAll()
    }

    private func clearRoute() {
        for mapPolyline in mapPolylineList {
            mapView.mapScene.removeMapPolyline(mapPolyline)
        }
        mapPolylineList.removeAll()
    }

    public func addCircleMapMarker(geoCoordinates: GeoCoordinates, imageName: String) {
        let mapMarker = MapMarkerLite(at: geoCoordinates)
        let image = UIImage(named: imageName) // "poi"
        let mapImage = MapImageLite(image!)
        mapMarker.addImage(mapImage!, style: MapMarkerImageStyleLite())
        mapView.mapScene.addMapMarker(mapMarker)
        mapMarkers.append(mapMarker)
    }

    public func showDialog(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        viewController.present(alertController, animated: true, completion: nil)
    }
}
