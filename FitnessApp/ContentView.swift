//
//  ContentView.swift
//  FitnessApp
//
//  Created by Liam Ford on 10/16/24.
//

import SwiftUI
import MapKit
import CoreMotion
import CoreLocation

struct WorkoutLocation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

struct ContentView: View {
    var body: some View {
        TabView {
            CardioView()
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text("Cardio")
                }

            CaloriesView()
                .tabItem {
                    Image(systemName: "flame")
                    Text("Calories")
                }

            WorkoutsView()
                .tabItem {
                    Image(systemName: "dumbbell")
                    Text("Workout")
                }
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.crop.circle")
                    Text("Profile")
                }
        }
    }
}



struct CardioView: View {
    @StateObject private var cardioManager = CardioManager()
    @State private var isWorkoutActive = false
    @State private var workoutStartTime: Date? = nil
    @State private var elapsedTime: TimeInterval = 0
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    func formatElapsedTime(_ seconds: TimeInterval) -> String {
            let hours = Int(seconds) / 3600
            let minutes = (Int(seconds) % 3600) / 60
            let secs = Int(seconds) % 60
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }
    
    var body: some View {
        VStack {
            
            HStack {
                VStack {
                    Text("Steps")
                        .font(.caption)
                    Text("\(cardioManager.steps)")
                        .font(.title2)
                        .bold()
                }
                .padding()
               
                Spacer()
                
                VStack {
                    Text("Distance")
                        .font(.caption)
                    Text("\(String(format: "%.2f", cardioManager.distance)) mi")
                        .font(.title2)
                        .bold()
                }
                .padding()
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 20)
            
            DisclosureGroup("Previous Workouts") {
                if cardioManager.workouts.isEmpty {
                    Text("No Previous Workouts")
                        .italic()
                        .padding()
                } else {
                    ForEach(cardioManager.workouts) { workout in
                        VStack(alignment: .leading) {
                            // Use dateFormatter for workout date
                            Text("Date: \(dateFormatter.string(from: workout.date))")
                            Text("Distance: \(String(format: "%.2f", workout.distance)) mi")
                            Text("Time: \(formatElapsedTime(workout.time))")
                            Text("Average Speed: \(String(format: "%.2f", workout.averageSpeed)) mph")
                        }
                        .padding(.vertical, 5)
                    }
                    
                    Button(action: {
                        cardioManager.workouts.removeAll()
                    }) {
                        Text("Clear Workouts")
                            .foregroundColor(.red)
                            .padding()
                    }
                }
            }
            .padding()
            
            
            Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: cardioManager.locations) { location in
                MapMarker(coordinate: location.coordinate)
                    }
                    .overlay(
                        MapOverlay(polyline: cardioManager.locations.map { $0.coordinate })
                            .stroke(Color.blue, lineWidth: 3)
                    )
                    .frame(height: 300)
                    .cornerRadius(15)
                    .padding()

            
            HStack {
                VStack {
                    Text("Time")
                        .font(.caption)
                    Text("\(formatElapsedTime(elapsedTime))")
                        .font(.title2)
                        .bold()
                }
                .padding()
                
                Spacer()
                
                VStack {
                    Text("Pace")
                        .font(.caption)
                    Text("\(String(format: "%.2f", cardioManager.averageSpeed)) mph")
                        .font(.title2)
                        .bold()
                }
                .padding()
            }
            
            
            Button(action: {
                if isWorkoutActive {
                    isWorkoutActive = false
                    cardioManager.stopWorkout()
                } else {
                    isWorkoutActive = true
                    workoutStartTime = Date()
                    cardioManager.startWorkout()
                }
            }) {
                Text(isWorkoutActive ? "End Workout" : "Start Workout")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(isWorkoutActive ? Color.red : Color.blue)
                    .cornerRadius(10)
            }
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear() {
            cardioManager.startTracking()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if isWorkoutActive, let startTime = workoutStartTime {
                elapsedTime = Date().timeIntervalSince(startTime)
            }
        }
        .onChange(of: cardioManager.lastLocation) {
            if let newLocation = cardioManager.lastLocation {
                region.center = newLocation.coordinate
            }
        }
    }
}

struct MapOverlay: Shape {
    var polyline: [CLLocationCoordinate2D]
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let firstPoint = polyline.first else { return path }
        path.move(to: CGPoint(x: firstPoint.latitude, y: firstPoint.longitude))
        
        for point in polyline.dropFirst() {
            path.addLine(to: CGPoint(x: point.latitude, y: point.longitude))
        }
        return path
    }
}

struct Workout: Identifiable {
    let id = UUID()
    let date: Date
    let distance: Double
    let time: TimeInterval
    let averageSpeed: Double
}

class CardioManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var steps: Int = 0
    @Published var distance: Double = 0.0
    @Published var workoutDistance: Double = 0.0
    @Published var averageSpeed: Double = 0.0
    @Published var workouts: [Workout] = []
    @Published var locations: [WorkoutLocation] = []
    @Published var lastLocation: CLLocation?
    
    private var pedometer: CMPedometer
    private var locationManager: CLLocationManager
    private var workoutStartTime: Date? = nil
    
    override init() {
        self.pedometer = CMPedometer()
        self.locationManager = CLLocationManager()
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func startTracking() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
        if CMPedometer.isStepCountingAvailable() {
                    pedometer.startUpdates(from: Date()) { data, error in
                        guard let data = data, error == nil else { return }
                        DispatchQueue.main.async {
                            self.steps = data.numberOfSteps.intValue
                        }
                    }
                }
    }
    
    func startWorkout() {
        workoutStartTime = Date()
        workoutDistance = 0.0
        locations.removeAll()
    }
    
    func stopWorkout() {
        if let startTime = workoutStartTime {
            let timeElasped = Date().timeIntervalSince(startTime)
            let workout = Workout(date: Date(), distance: workoutDistance, time: timeElasped, averageSpeed: averageSpeed)
            workouts.append(workout)
        }
        workoutStartTime = nil
        workoutDistance = 0.0
        averageSpeed = 0.0
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let currentLocation = locations.last else { return }

        if let lastLocation = lastLocation {
            let distanceInMeters = currentLocation.distance(from: lastLocation)
            DispatchQueue.main.async {
                let distanceInKilometers = distanceInMeters / 1000.0
                let distanceInMiles = distanceInKilometers * 0.621371
                self.distance += distanceInMiles
                
                if self.workoutStartTime != nil {
                    self.workoutDistance += distanceInMiles
                    let elapsedTime = Date().timeIntervalSince(self.workoutStartTime!)
                    self.averageSpeed = self.workoutDistance / (elapsedTime / 3600)
                }
                
                let workoutLocation = WorkoutLocation(coordinate: currentLocation.coordinate)
                self.locations.append(workoutLocation)
            }
        }

        self.lastLocation = currentLocation
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
                locationManager.startUpdatingLocation()
            }
        }
}

struct CaloriesView: View {
    var body: some View {
        VStack {
            Text("Calories Tracker")
                .font(.largeTitle)
                .padding(.top, 50)
            Spacer()
        }
    }
}

struct WorkoutsView: View {
    var body: some View {
        VStack {
            Text("Workout Tracker")
                .font(.largeTitle)
                .padding(.top, 50)
            Spacer()
        }
    }
}

struct ProfileView: View {
    var body: some View {
        VStack {
            Text("Profile")
                .font(.largeTitle)
                .padding(.top, 50)
            Spacer()
        }
    }
}

#Preview {
    ContentView()
}
