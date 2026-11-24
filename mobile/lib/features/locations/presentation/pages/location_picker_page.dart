import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models/selected_facility.dart';

class LocationPickerPage extends StatelessWidget {
  const LocationPickerPage({
    super.key,
    required this.facilities,
    this.distancesInMeters = const {},
    this.coordinatesById = const {},
  });

  final List<SelectedFacility> facilities;
  final Map<String, double> distancesInMeters;
  final Map<String, ({double latitude, double longitude})> coordinatesById;

  void _selectFacility(BuildContext context, SelectedFacility facility) {
    Navigator.pop<SelectedFacility>(context, facility);
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];

    for (final facility in facilities) {
      final coordinates = coordinatesById[facility.id];
      if (coordinates == null) continue;

      markers.add(
        Marker(
          point: LatLng(coordinates.latitude, coordinates.longitude),
          width: 48,
          height: 48,
          child: IconButton.filled(
            tooltip: facility.name,
            onPressed: () => _selectFacility(context, facility),
            icon: const Icon(Icons.location_on),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Select Location')),
      body: facilities.isEmpty
          ? const Center(child: Text('No locations available'))
          : Column(
              children: [
                if (markers.isNotEmpty)
                  Expanded(
                    child: FlutterMap(
                      options: MapOptions(
                        initialCameraFit: CameraFit.coordinates(
                          coordinates: [
                            for (final marker in markers) marker.point,
                          ],
                          padding: const EdgeInsets.all(36),
                          maxZoom: 19,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.group4.smart_daily_planner',
                        ),
                        MarkerLayer(markers: markers),
                        const SimpleAttributionWidget(
                          source: Text('OpenStreetMap contributors'),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    itemCount: facilities.length,
                    itemBuilder: (context, index) {
                      final facility = facilities[index];
                      final distance = distancesInMeters[facility.id];

                      return ListTile(
                        leading: const Icon(Icons.location_on_outlined),
                        title: Text(facility.name),
                        subtitle: distance == null
                            ? null
                            : Text('${distance.toStringAsFixed(0)} m away'),
                        onTap: () => _selectFacility(context, facility),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}