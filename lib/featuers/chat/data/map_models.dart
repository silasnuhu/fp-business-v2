// models/geocode_response.dart
class GeocodeResponse {
  final List<Result> results;

  GeocodeResponse({required this.results});

  factory GeocodeResponse.fromJson(Map<String, dynamic> json) {
    return GeocodeResponse(
      results: (json['results'] as List)
          .map((result) => Result.fromJson(result))
          .toList(),
    );
  }
}

class Result {
  final String formattedAddress;
  final Geometry geometry;

  Result({required this.formattedAddress, required this.geometry});

  factory Result.fromJson(Map<String, dynamic> json) {
    return Result(
      formattedAddress: json['formatted_address'],
      geometry: Geometry.fromJson(json['geometry']),
    );
  }
}

class Geometry {
  final Location location;

  Geometry({required this.location});

  factory Geometry.fromJson(Map<String, dynamic> json) {
    return Geometry(location: Location.fromJson(json['location']));
  }
}

class Location {
  final double lat;
  final double lng;

  Location({required this.lat, required this.lng});

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(lat: json['lat'], lng: json['lng']);
  }
}

// models/nearby_places_response.dart
class NearbyPlacesResponse {
  final List<Place> results;

  NearbyPlacesResponse({required this.results});

  factory NearbyPlacesResponse.fromJson(Map<String, dynamic> json) {
    return NearbyPlacesResponse(
      results: (json['results'] as List)
          .map((place) => Place.fromJson(place))
          .toList(),
    );
  }
}

class Place {
  final String name;
  final String vicinity;

  Place({required this.name, required this.vicinity});

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      name: json['name'],
      vicinity: json['vicinity'],
    );
  }
}

// models/place_suggestions_response.dart
class PlaceSuggestionsResponse {
  final List<Prediction> predictions;

  PlaceSuggestionsResponse({required this.predictions});

  factory PlaceSuggestionsResponse.fromJson(Map<String, dynamic> json) {
    return PlaceSuggestionsResponse(
      predictions: (json['predictions'] as List)
          .map((prediction) => Prediction.fromJson(prediction))
          .toList(),
    );
  }
}

class Prediction {
  final String description;

  Prediction({required this.description});

  factory Prediction.fromJson(Map<String, dynamic> json) {
    return Prediction(description: json['description']);
  }
}
