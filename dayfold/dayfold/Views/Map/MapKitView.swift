// Views/Map/MapKitView.swift
import SwiftUI
import MapKit
import CoreData

struct MapKitView: UIViewRepresentable {
    let entries: [Entry]
    var onSelect: ([Entry]) -> Void
    var onDeselect: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.pointOfInterestFilter = .excludingAll
        map.register(MKMarkerAnnotationView.self,
                     forAnnotationViewWithReuseIdentifier: "EntryPin")
        map.register(MKMarkerAnnotationView.self,
                     forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)

        // 默认聚焦：若有数据则 fit；否则上海
        DispatchQueue.main.async {
            self.applyInitialRegion(on: map)
        }
        return map
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let existing = mapView.annotations.compactMap { $0 as? EntryAnnotation }
        let existingIDs = Set(existing.map { $0.entryObjectID })
        let desiredIDs = Set(entries.compactMap { $0.location != nil ? $0.objectID : nil })

        // 删除多余
        let toRemove = existing.filter { !desiredIDs.contains($0.entryObjectID) }
        if !toRemove.isEmpty { mapView.removeAnnotations(toRemove) }

        // 新增缺失
        let toAdd: [EntryAnnotation] = entries.compactMap { entry in
            guard let loc = entry.location else { return nil }
            if existingIDs.contains(entry.objectID) { return nil }
            let subtitle = entry.location?.placeName
            return EntryAnnotation(
                entryObjectID: entry.objectID,
                coordinate: loc.coordinate,
                title: entry.wrappedTitle.isEmpty ? subtitle : entry.wrappedTitle,
                subtitle: subtitle
            )
        }
        if !toAdd.isEmpty { mapView.addAnnotations(toAdd) }
    }

    private func applyInitialRegion(on map: MKMapView) {
        if !entries.isEmpty {
            let coords = entries.compactMap { $0.location?.coordinate }
            if let region = boundingRegion(for: coords) {
                map.setRegion(region, animated: false)
                return
            }
        }
        // fallback: 上海
        map.setRegion(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 31.23, longitude: 121.47),
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        ), animated: false)
    }

    private func boundingRegion(for coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
        guard !coords.isEmpty else { return nil }
        if coords.count == 1 {
            return MKCoordinateRegion(
                center: coords[0],
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        }
        let lats = coords.map { $0.latitude }
        let lons = coords.map { $0.longitude }
        let minLat = lats.min()!; let maxLat = lats.max()!
        let minLon = lons.min()!; let maxLon = lons.max()!
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.02, (maxLat - minLat) * 1.4),
            longitudeDelta: max(0.02, (maxLon - minLon) * 1.4)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        let parent: MapKitView
        init(parent: MapKitView) { self.parent = parent }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }

            if let cluster = annotation as? MKClusterAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier,
                    for: cluster
                ) as? MKMarkerAnnotationView
                view?.markerTinkClusterDefault()
                return view
            }

            if let entry = annotation as? EntryAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: "EntryPin",
                    for: entry
                ) as? MKMarkerAnnotationView
                view?.clusteringIdentifier = "entry"
                view?.markerTintColor = UIColor(red: 0.88, green: 0.35, blue: 0.23, alpha: 1.0) // warmAccent
                view?.glyphImage = UIImage(systemName: "book.closed.fill")
                view?.displayPriority = .required
                return view
            }
            return nil
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            let context = CoreDataStack.shared.viewContext

            if let cluster = view.annotation as? MKClusterAnnotation {
                let members = cluster.memberAnnotations.compactMap { $0 as? EntryAnnotation }
                let entries: [Entry] = members.compactMap {
                    try? context.existingObject(with: $0.entryObjectID) as? Entry
                }
                if !entries.isEmpty { parent.onSelect(entries) }
                mapView.deselectAnnotation(view.annotation, animated: false)
                return
            }

            if let ann = view.annotation as? EntryAnnotation,
               let entry = try? context.existingObject(with: ann.entryObjectID) as? Entry {
                parent.onSelect([entry])
                mapView.deselectAnnotation(view.annotation, animated: false)
            }
        }
    }
}

private extension MKMarkerAnnotationView {
    func markerTinkClusterDefault() {
        self.markerTintColor = UIColor(red: 0.18, green: 0.18, blue: 0.20, alpha: 1.0)
        self.glyphTintColor = .white
        self.displayPriority = .defaultHigh
    }
}
