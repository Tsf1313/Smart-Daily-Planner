import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/widgets/planner_primary_button.dart';
import '../../data/models/selected_facility.dart';

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({
    super.key,
    required this.facilities,
    this.distancesInMeters = const {},
    this.coordinatesById = const {},
    this.initialFacilityId,
    this.sampleData = false,
  });

  final List<SelectedFacility> facilities;
  final String? initialFacilityId;
  final bool sampleData;
  final Map<String, double> distancesInMeters;
  final Map<String, ({double latitude, double longitude})> coordinatesById;

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  String _query = '';
  SelectedFacility? _selection;
  Position? _currentPosition;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    for (final facility in widget.facilities) {
      if (facility.id == widget.initialFacilityId) {
        _selection = facility;
        break;
      }
    }
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showLocationMessage('Location is off. You can still pick a place.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        _showLocationMessage('Location access is unavailable. Pick a place manually.');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(timeLimit: Duration(seconds: 15)),
      );
      if (mounted) setState(() => _currentPosition = position);
    } catch (_) {
      _showLocationMessage('Current location is unavailable. Pick a place manually.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showLocationMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  double? _distanceOf(SelectedFacility facility) {
    final position = _currentPosition;
    final point = _locationOf(facility);
    if (position == null || point == null) {
      return widget.distancesInMeters[facility.id];
    }
    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      point.latitude,
      point.longitude,
    );
  }

  void _confirm() {
    final facility = _selection;
    if (facility == null) return;

    final point = _locationOf(facility);
    Navigator.pop<SelectedFacility>(
      context,
      SelectedFacility(
        id: facility.id,
        name: facility.name,
        latitude: point?.latitude,
        longitude: point?.longitude,
      ),
    );
  }

  LatLng? _locationOf(SelectedFacility facility) {
    final coordinates = widget.coordinatesById[facility.id];
    final latitude = coordinates?.latitude ?? facility.latitude;
    final longitude = coordinates?.longitude ?? facility.longitude;
    if (latitude == null || longitude == null) return null;
    return LatLng(latitude, longitude);
  }

  @override
  Widget build(BuildContext context) {
    final results = widget.facilities
        .where((facility) => facility.name.toLowerCase().contains(_query))
        .toList();
    if (_currentPosition != null) {
      results.sort((a, b) => (_distanceOf(a) ?? double.infinity)
          .compareTo(_distanceOf(b) ?? double.infinity));
    }
    final pointsById = <String, LatLng>{};
    for (final facility in widget.facilities) {
      final point = _locationOf(facility);
      if (point != null) pointsById[facility.id] = point;
    }
    final currentPosition = _currentPosition;
    final markers = [
      if (currentPosition != null)
        Marker(
          point: LatLng(currentPosition.latitude, currentPosition.longitude),
          child: const Icon(Icons.my_location, color: Colors.blue),
        ),
      for (final facility in results)
        if (pointsById[facility.id] case final LatLng point)
          Marker(
            point: point,
            width: 48,
            height: 48,
            child: IconButton(
              tooltip: facility.name,
              onPressed: () => setState(() => _selection = facility),
              color: _selection?.id == facility.id ? AppColors.primary : Colors.blueGrey,
              icon: const Icon(Icons.location_on),
            ),
          ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Select Location'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Use current location',
            onPressed: _locating ? null : _locate,
            color: AppColors.primary,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search campus or place',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (pointsById.isNotEmpty) ...[
                const SizedBox(height: 12),
                Flexible(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FlutterMap(
                      options: MapOptions(
                        initialCameraFit: CameraFit.coordinates(
                          coordinates: pointsById.values.toList(),
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
                ),
              ],
              const SizedBox(height: 12),
              Text(
                widget.sampleData
                    ? 'SAMPLE CAMPUS SPOTS'
                    : 'SAVED & NEARBY CAMPUS SPOTS',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: results.isEmpty
                    ? Center(
                        child: Text(
                          widget.facilities.isEmpty
                              ? 'No locations available'
                              : 'No locations match your search',
                        ),
                      )
                    : ListView.separated(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: results.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final facility = results[index];
                          final selected = _selection?.id == facility.id;
                          final distance = _distanceOf(facility);

                          return Card(
                            margin: EdgeInsets.zero,
                            color: selected ? AppColors.primaryLight : Colors.white,
                            elevation: 0,
                            child: ListTile(
                              selected: selected,
                              selectedColor: AppColors.primary,
                              leading: const Icon(Icons.location_on_outlined),
                              title: Text(facility.name),
                              subtitle: distance == null
                                  ? null
                                  : Text('${distance.toStringAsFixed(0)} m away'),
                              trailing: selected
                                  ? const Icon(Icons.check_circle)
                                  : null,
                              onTap: () => setState(() => _selection = facility),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              PlannerPrimaryButton(
                onPressed: _selection == null ? null : _confirm,
                label: 'Confirm Location',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
