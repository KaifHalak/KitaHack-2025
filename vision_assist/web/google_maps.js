let map;
let directionsService;
let directionsRenderer;
let currentLocationMarker;
let destinationMarker;

// Expose functions to Flutter via global scope
window.initMap = function() {
    try {
        if (!window.google || !window.google.maps) {
            console.error('Google Maps API not loaded');
            return;
        }

        const mapElement = document.getElementById('map');
        if (!mapElement) {
            console.error('Map element not found');
            return;
        }

        const apiKey = window.MAPS_API_KEY;
        if (!apiKey || apiKey === 'MAPS_API_KEY_PLACEHOLDER') {
            console.error('Invalid Google Maps API key');
            return;
        }

        // Create map instance
        map = new google.maps.Map(mapElement, {
            zoom: 15,
            center: { lat: 0, lng: 0 },
            disableDefaultUI: true,
            gestureHandling: 'greedy',
            clickableIcons: false
        });

        // Initialize directions service and renderer
        directionsService = new google.maps.DirectionsService();
        directionsRenderer = new google.maps.DirectionsRenderer({
            map: map,
            suppressMarkers: true,
            polylineOptions: {
                strokeColor: '#4285F4',
                strokeWeight: 5
            }
        });

        // Get current location
        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(
                (position) => {
                    const pos = {
                        lat: position.coords.latitude,
                        lng: position.coords.longitude
                    };

                    // Create current location marker
                    if (google.maps.marker && google.maps.marker.AdvancedMarkerElement) {
                        currentLocationMarker = new google.maps.marker.AdvancedMarkerElement({
                            map: map,
                            position: pos,
                            title: 'Current Location',
                            gmpClickable: true
                        });
                    } else {
                        currentLocationMarker = new google.maps.Marker({
                            map: map,
                            position: pos,
                            title: 'Current Location'
                        });
                    }

                    map.setCenter(pos);
                    console.log('Map initialized with current location:', pos);
                },
                (error) => {
                    console.error('Error getting location:', error);
                    map.setCenter({ lat: 0, lng: 0 });
                }
            );
        } else {
            console.error('Geolocation is not supported by this browser');
            map.setCenter({ lat: 0, lng: 0 });
        }

        // Create destination marker
        if (google.maps.marker && google.maps.marker.AdvancedMarkerElement) {
            destinationMarker = new google.maps.marker.AdvancedMarkerElement({
                map: map,
                position: { lat: 0, lng: 0 },
                title: 'Destination',
                gmpClickable: true
            });
        } else {
            destinationMarker = new google.maps.Marker({
                map: map,
                position: { lat: 0, lng: 0 },
                title: 'Destination'
            });
        }

        // Notify Flutter that the map is ready
        if (window.flutter_inappwebview) {
            window.flutter_inappwebview.callHandler('mapReady');
        }
        
        console.log("Google Maps initialized successfully!");
    } catch (error) {
        console.error('Error initializing Google Maps:', error);
    }
};

window.updateCurrentLocation = function(lat, lng) {
    if (!map || !window.google || !window.google.maps) {
        console.error('Map not initialized');
        return;
    }

    const pos = { lat, lng };
    
    if (currentLocationMarker) {
        currentLocationMarker.position = pos;
    } else {
        // Create new marker if it doesn't exist
        currentLocationMarker = new google.maps.marker.AdvancedMarkerElement({
            map: map,
            position: pos,
            title: 'Current Location',
            gmpClickable: true
        });
    }

    map.setCenter(pos);
    console.log('Current location updated:', pos);
};

window.calculateRoute = function(origin, destination) {
    console.log('calculateRoute called with:', 
                JSON.stringify(origin), 
                JSON.stringify(destination));
    
    return new Promise((resolve) => {
        if (!map || !directionsService || !directionsRenderer) {
            console.error('Map or services not initialized');
            resolve({
                steps: [],
                distance: 'Unknown',
                duration: 'Unknown'
            });
            return;
        }

        const request = {
            origin: origin,
            destination: destination,
            travelMode: google.maps.TravelMode.WALKING
        };

        console.log('Calling directionsService.route with request:', 
                    JSON.stringify(request));
        
        directionsService.route(request, (result, status) => {
            console.log('Route result status:', status);
            
            if (status === 'OK') {
                directionsRenderer.setDirections(result);
                
                // Update destination marker
                if (destinationMarker) {
                    destinationMarker.position = destination;
                } else {
                    try {
                        if (google.maps.marker && google.maps.marker.AdvancedMarkerElement) {
                            destinationMarker = new google.maps.marker.AdvancedMarkerElement({
                                map: map,
                                position: destination,
                                title: 'Destination',
                                gmpClickable: true
                            });
                        } else {
                            // Fallback to regular marker
                            destinationMarker = new google.maps.Marker({
                                map: map,
                                position: destination,
                                title: 'Destination'
                            });
                        }
                    } catch (e) {
                        console.error('Error creating destination marker:', e);
                    }
                }

                try {
                    // Extract route information
                    const route = result.routes[0];
                    const leg = route.legs[0];
                    
                    console.log('Route leg data available:', !!leg);
                    
                    const steps = [];
                    for (let i = 0; i < leg.steps.length; i++) {
                        const step = leg.steps[i];
                        steps.push({
                            instruction: step.instructions,
                            distance: step.distance.text,
                            duration: step.duration.text
                        });
                    }

                    console.log('Route calculated successfully:', {
                        steps: steps.length,
                        distance: leg.distance.text,
                        duration: leg.duration.text
                    });

                    // Create a response object with the expected format
                    const response = {
                        steps: steps,
                        distance: leg.distance.text,
                        duration: leg.duration.text
                    };
                    
                    console.log('Returning steps array length:', steps.length);
                    resolve(response);
                } catch (e) {
                    console.error('Error extracting route data:', e);
                    resolve({
                        steps: [],
                        distance: 'Unknown',
                        duration: 'Unknown'
                    });
                }
            } else {
                console.error('Error calculating route:', status);
                resolve({
                    steps: [],
                    distance: 'Unknown',
                    duration: 'Unknown'
                });
            }
        });
    });
};

window.clearRoute = function() {
    if (directionsRenderer) {
        directionsRenderer.setDirections({ routes: [] });
    }
    
    if (destinationMarker) {
        destinationMarker.setMap(null);
    }
    
    console.log("Route cleared");
}; 