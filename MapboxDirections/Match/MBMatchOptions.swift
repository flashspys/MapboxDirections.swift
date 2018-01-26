import Foundation

@objc(MBMatchingOptions)
open class MatchingOptions: RouteOptions {
    
    public init(locations: [CLLocation], profileIdentifier: MBDirectionsProfileIdentifier? = nil) {
        let waypoints = locations.map {
            Waypoint(location: $0)
        }
        self.timestamps = locations.map { $0.timestamp }
        super.init(waypoints: waypoints, profileIdentifier: profileIdentifier)
    }
    
    @objc open var resampleTraces: Bool = false
    
    @objc private var timestamps: [Date]?
    
    public required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override internal var params: [URLQueryItem] {
        var params = super.params
        
        params.append(URLQueryItem(name: "tidy", value: String(describing: resampleTraces)))
        
        if let timestamps = timestamps, !timestamps.isEmpty {
            let timeStrings = timestamps.map {
                String(describing: $0.timeIntervalSince1970)
                }.joined(separator: ";")
            
            params.append(URLQueryItem(name: "timestamps", value: timeStrings))
        }
        
        return params
    }
    
    override internal var path: String {
        assert(!queries.isEmpty, "No query")
        
        let queryComponent = queries.joined(separator: ";")
        return "matching/v5/\(profileIdentifier.rawValue)/\(queryComponent).json"
    }
    
    internal func responseMatchOptions(from json: JSONDictionary) -> ([Tracepoint]?, [Match]?) {
        var namedWaypoints: [Tracepoint]?
        if let jsonWaypoints = (json["tracepoints"] as? [JSONDictionary]) {
            namedWaypoints = zip(jsonWaypoints, self.waypoints).map { (api, local) -> Tracepoint in
                let location = api["location"] as! [Double]
                let coordinate = CLLocationCoordinate2D(geoJSON: location)
                let alternateCount = api["alternatives_count"] as! Int
                let waypointIndex = api["waypoint_index"] as! Int
                let matchingIndex = api["matchings_index"] as! Int
                let name = api["name"] as? String
                // TODO: add name
                // let possibleAPIName = api["name"] as? String
                return Tracepoint(coordinate: coordinate, alternateCount: alternateCount, waypointIndex: waypointIndex, matchingIndex: matchingIndex, name: name)
            }
        }
        
        let tracePoints = namedWaypoints!
        
        let matchings = (json["matchings"] as? [JSONDictionary])?.map { 
            Match(json: $0, tracePoints: tracePoints, matchOptions: self)
        }
        return (tracePoints, matchings)
    }
}
