// Models/Location.swift
import Foundation
import CoreData
import CoreLocation

extension Location {
    var wrappedPlaceName: String {
        placeName ?? ""
    }

    var wrappedAddress: String {
        address ?? ""
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    static func create(latitude: Double, longitude: Double, in context: NSManagedObjectContext) -> Location {
        let location = Location(context: context)
        location.id = UUID()
        location.latitude = latitude
        location.longitude = longitude
        return location
    }
}
