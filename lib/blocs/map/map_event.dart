import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Abstract class for all Map events
abstract class MapEvent extends Equatable {
  const MapEvent();

  @override
  List<Object?> get props => [];
}

/// Event to initialize map with location data
class MapInitialize extends MapEvent {
  final String chatId;
  final String recipientId;
  final String recipientName;

  const MapInitialize({
    required this.chatId,
    required this.recipientId,
    required this.recipientName,
  });

  @override
  List<Object?> get props => [chatId, recipientId, recipientName];
}

/// Event when location data is received
class MapLocationUpdated extends MapEvent {
  final LatLng position;
  final DateTime lastUpdated;

  const MapLocationUpdated({required this.position, required this.lastUpdated});

  @override
  List<Object?> get props => [position, lastUpdated];
}

/// Event when map is created
class MapCreated extends MapEvent {
  final dynamic controller; // GoogleMapController

  const MapCreated(this.controller);

  @override
  List<Object?> get props => [controller];
}

/// Event when location sharing has ended
class MapLocationSharingEndedEvent extends MapEvent {
  const MapLocationSharingEndedEvent();
}

/// Event to animate camera to position
class MapAnimateToPosition extends MapEvent {
  final LatLng position;

  const MapAnimateToPosition(this.position);

  @override
  List<Object?> get props => [position];
}

/// Event to dispose map resources
class MapDispose extends MapEvent {
  const MapDispose();
}
