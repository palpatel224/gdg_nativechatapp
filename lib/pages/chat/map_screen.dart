import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/map/map_bloc.dart';
import '../../blocs/map/map_event.dart';
import '../../blocs/map/map_state.dart';

/// MapScreen - Displays real-time location updates on a Google Map
/// Shows the sender's live location with a marker that updates in real-time
/// Uses MapBloc for state management
class MapScreen extends StatefulWidget {
  final String chatId;
  final String recipientId;
  final String recipientName;

  const MapScreen({
    super.key,
    required this.chatId,
    required this.recipientId,
    required this.recipientName,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late MapBloc _mapBloc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Save reference to the bloc in didChangeDependencies
    _mapBloc = context.read<MapBloc>();
    // Initialize map bloc with location data
    _mapBloc.add(
      MapInitialize(
        chatId: widget.chatId,
        recipientId: widget.recipientId,
        recipientName: widget.recipientName,
      ),
    );
  }

  @override
  void dispose() {
    // Cleanup map resources using saved reference
    _mapBloc.add(const MapDispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Icon(Icons.location_on, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.recipientName} Location',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text(
                    'Live location',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: BlocBuilder<MapBloc, MapState>(
        builder: (context, state) {
          // Handle error state
          if (state is MapError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    state.message,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // Handle loading state
          if (state is MapLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Handle location sharing ended state
          if (state is MapLocationSharingEnded) {
            return Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target:
                        state.lastKnownPosition ??
                        const LatLng(37.7749, -122.4194),
                    zoom: 15.0,
                  ),
                  markers: const {},
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                  mapType: MapType.normal,
                ),
                // Overlay message when sharing has ended
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_off,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Location sharing has ended',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${widget.recipientName} stopped sharing their location',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          // Handle loaded state with location data
          if (state is MapLoaded) {
            return Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: state.initialPosition,
                    zoom: 15.0,
                  ),
                  markers: state.markers,
                  onMapCreated: (controller) {
                    context.read<MapBloc>().add(MapCreated(controller));
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                  mapType: MapType.normal,
                ),
                // Last updated indicator
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Live location',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          context.read<MapBloc>().getTimeAgo(state.lastUpdated),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Location coordinates info
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.pin_drop,
                              size: 20,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${widget.recipientName} is here',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Lat: ${state.position.latitude.toStringAsFixed(6)}, Long: ${state.position.longitude.toStringAsFixed(6)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          // Default/Initial state
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
