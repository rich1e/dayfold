// Views/Map/EntryAnnotation.swift
import Foundation
import MapKit
import CoreData

final class EntryAnnotation: NSObject, MKAnnotation {
    let entryObjectID: NSManagedObjectID
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?

    init(entryObjectID: NSManagedObjectID,
         coordinate: CLLocationCoordinate2D,
         title: String?,
         subtitle: String?) {
        self.entryObjectID = entryObjectID
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        super.init()
    }
}
