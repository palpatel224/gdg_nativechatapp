import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Abstract class for all Map states
abstract class MapState extends Equatable {
  const MapState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class MapInitial extends MapState {
  const MapInitial();
}

/// Loading state
class MapLoading extends MapState {
  const MapLoading();
}

/// Loaded state with location data
class MapLoaded extends MapState {
  final LatLng position;
  final DateTime lastUpdated;
  final Set<Marker> markers;
  final LatLng initialPosition;
  final bool hasInitialized;

  const MapLoaded({
    required this.position,
    required this.lastUpdated,
    required this.markers,
    required this.initialPosition,
    required this.hasInitialized,
  });

  @override
  List<Object?> get props => [
    position,
    lastUpdated,
    markers,
    initialPosition,
    hasInitialized,
  ];

  /// CopyWith method for creating modified copies
  MapLoaded copyWith({
    LatLng? position,
    DateTime? lastUpdated,
    Set<Marker>? markers,
    LatLng? initialPosition,
    bool? hasInitialized,
  }) {
    return MapLoaded(
      position: position ?? this.position,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      markers: markers ?? this.markers,
      initialPosition: initialPosition ?? this.initialPosition,
      hasInitialized: hasInitialized ?? this.hasInitialized,
    );
  }
}

/// Location sharing ended state
class MapLocationSharingEnded extends MapState {
  final LatLng? lastKnownPosition;

  const MapLocationSharingEnded({this.lastKnownPosition});

  @override
  List<Object?> get props => [lastKnownPosition];
}

/// Error state
class MapError extends MapState {
  final String message;

  const MapError(this.message);

  @override
  List<Object?> get props => [message];
}
