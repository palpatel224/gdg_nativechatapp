import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'map_event.dart';
import 'map_state.dart';

/// MapBloc - Handles all map-related logic and state management
/// Manages:
/// - Real-time location updates from Firestore
/// - Marker updates
/// - Map controller and camera animations
/// - Location sharing status
class MapBloc extends Bloc<MapEvent, MapState> {
  GoogleMapController? _mapController;
  StreamSubscription? _locationSubscription;
  String? _recipientId;
  String? _recipientName;

  MapBloc() : super(const MapInitial()) {
    // Register event handlers
    on<MapInitialize>(_onMapInitialize);
    on<MapLocationUpdated>(_onLocationUpdated);
    on<MapCreated>(_onMapCreated);
    on<MapLocationSharingEndedEvent>(_onLocationSharingEnded);
    on<MapAnimateToPosition>(_onAnimateToPosition);
    on<MapDispose>(_onDispose);
  }

  /// Handle map initialization
  /// Sets up chat/recipient info and begins listening to location updates
  Future<void> _onMapInitialize(
    MapInitialize event,
    Emitter<MapState> emit,
  ) async {
    try {
      emit(const MapLoading());

      _recipientId = event.recipientId;
      _recipientName = event.recipientName;

      // Default position (San Francisco)
      const defaultPosition = LatLng(37.7749, -122.4194);

      // Start listening to location updates
      _locationSubscription = FirebaseFirestore.instance
          .collection('chats')
          .doc(event.chatId)
          .collection('liveLocations')
          .doc(event.recipientId)
          .snapshots()
          .listen(
            (snapshot) {
              if (snapshot.exists) {
                final data = snapshot.data() as Map<String, dynamic>;
                final latitude = data['latitude'] as double;
                final longitude = data['longitude'] as double;
                final lastUpdated = data['lastUpdated'] as Timestamp?;

                final position = LatLng(latitude, longitude);
                add(
                  MapLocationUpdated(
                    position: position,
                    lastUpdated: lastUpdated?.toDate() ?? DateTime.now(),
                  ),
                );
              } else {
                // Location sharing has ended
                add(const MapLocationSharingEndedEvent());
              }
            },
            onError: (error) {
              add(const MapLocationSharingEndedEvent());
            },
          );

      // Emit initial loading state with default position
      emit(
        MapLoaded(
          position: defaultPosition,
          lastUpdated: DateTime.now(),
          markers: {},
          initialPosition: defaultPosition,
          hasInitialized: false,
        ),
      );
    } catch (e) {
      emit(MapError('Failed to initialize map: $e'));
    }
  }

  /// Handle location updates
  /// Updates markers and emits new state with updated position
  Future<void> _onLocationUpdated(
    MapLocationUpdated event,
    Emitter<MapState> emit,
  ) async {
    try {
      if (state is MapLoaded) {
        final currentState = state as MapLoaded;

        // Create marker for the location
        final marker = Marker(
          markerId: MarkerId(_recipientId ?? 'unknown'),
          position: event.position,
          infoWindow: InfoWindow(
            title: '$_recipientName Location',
            snippet: 'Live location',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        );

        // Emit updated state
        emit(
          currentState.copyWith(
            position: event.position,
            lastUpdated: event.lastUpdated,
            markers: {marker},
            initialPosition: !currentState.hasInitialized
                ? event.position
                : currentState.initialPosition,
            hasInitialized: true,
          ),
        );

        // Animate camera to new position
        _animateCameraToPosition(event.position);
      }
    } catch (e) {
      emit(MapError('Failed to update location: $e'));
    }
  }

  /// Handle map controller creation
  Future<void> _onMapCreated(MapCreated event, Emitter<MapState> emit) async {
    try {
      _mapController = event.controller as GoogleMapController?;

      // If we already have a position, animate to it
      if (state is MapLoaded) {
        final currentState = state as MapLoaded;
        _animateCameraToPosition(currentState.position);
      }
    } catch (e) {
      emit(MapError('Failed to create map: $e'));
    }
  }

  /// Handle location sharing ended
  Future<void> _onLocationSharingEnded(
    MapLocationSharingEndedEvent event,
    Emitter<MapState> emit,
  ) async {
    // Keep the last known position visible
    if (state is MapLoaded) {
      final currentState = state as MapLoaded;
      emit(MapLocationSharingEnded(lastKnownPosition: currentState.position));
    } else {
      emit(const MapLocationSharingEnded());
    }
  }

  /// Handle camera animation
  Future<void> _onAnimateToPosition(
    MapAnimateToPosition event,
    Emitter<MapState> emit,
  ) async {
    _animateCameraToPosition(event.position);
  }

  /// Handle disposal
  Future<void> _onDispose(MapDispose event, Emitter<MapState> emit) async {
    await _locationSubscription?.cancel();
    _mapController?.dispose();
  }

  /// Helper method to animate camera to position
  void _animateCameraToPosition(LatLng position) {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: position, zoom: 15.0),
        ),
      );
    }
  }

  /// Format time ago string from DateTime
  String getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 10) {
      return 'just now';
    } else if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  @override
  Future<void> close() {
    _locationSubscription?.cancel();
    _mapController?.dispose();
    return super.close();
  }
}
