//
//  ContentView.swift
//  FitnessApp
//
//  Created by Liam Ford on 10/16/24.
//

import SwiftUI
import CoreMotion
import CoreLocation

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
    
    
    var body: some View {
        VStack {
            Spacer()
            
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
            
            HStack {
                VStack {
                    Text("Time")
                        .font(.caption)
                    Text("\(String(format: "%.2f", elapsedTime)) sec")
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
            .padding(.bottom, 20)
            
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
                    .background(isWorkoutActive ? Color.red : Color.green)
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
    }
}

class CardioManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var steps: Int = 0
    @Published var distance: Double = 0.0
    @Published var averageSpeed: Double = 0.0
    
    private var pedometer: CMPedometer
    private var locationManager: CLLocationManager
    private var lastLocation: CLLocation?
    private var workoutDistance: Double = 0.0
    private var workoutStartTime: Date? = nil
    
    override init() {
        self.pedometer = CMPedometer()
        self.locationManager = CLLocationManager()
        self.lastLocation = nil
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
    }
    
    func stopWorkout() {
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
