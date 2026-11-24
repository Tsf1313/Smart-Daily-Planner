import 'package:material_ui/material_ui.dart';
import 'package:geolocator/geolocator.dart';

import 'features/locations/data/models/selected_facility.dart';
import 'features/locations/presentation/pages/location_picker_page.dart';

void main() {
  runApp(const MaterialApp(home: LocationPickerDemo()));
}

class LocationPickerDemo extends StatefulWidget {
  const LocationPickerDemo({super.key});

  @override
  State<LocationPickerDemo> createState() => _LocationPickerDemoState();
}

class _LocationPickerDemoState extends State<LocationPickerDemo> {
  static const sampleFacilities = [
    SelectedFacility(id: 'sample_library', name: 'Library'),
    SelectedFacility(id: 'sample_cafeteria', name: 'Cafeteria'),
  ];

  SelectedFacility? _selectedFacility;
  Position? _currentPosition;
bool _isLocating = false;
String _locationMessage = '';

Future<void> _getCurrentLocation() async {
  setState(() {
    _isLocating = true;
    _locationMessage = 'Getting location…';
  });

  String message;
  Position? position;
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      message = 'Turn on Location in Android Settings.';
    } else {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        message = 'Allow location access in Android app settings.';
      } else if (permission == LocationPermission.denied) {
        message = 'Location permission denied. You can still pick manually.';
      } else {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            timeLimit: Duration(seconds: 15),
          ),
        );
        message = 'Latitude: ${position.latitude.toStringAsFixed(5)}\n'
            'Longitude: ${position.longitude.toStringAsFixed(5)}';
      }
    }
  } catch (_) {
    message = 'Could not get location. Try again.';
  }

  if (!mounted) return;
  setState(() {
    _isLocating = false;
    _locationMessage = message;
    _currentPosition = position;
  });
}

  Future<void> _pickLocation() async {
  const sampleCoordinates = {
    'sample_library': (latitude: 37.42300, longitude: -122.08400),
    'sample_cafeteria': (latitude: 37.42220, longitude: -122.08400),
  };

  final facilities = [...sampleFacilities];
  final distances = <String, double>{};
  final position = _currentPosition;

  if (position != null) {
    for (final facility in facilities) {
      final coordinates = sampleCoordinates[facility.id]!;
      distances[facility.id] = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        coordinates.latitude,
        coordinates.longitude,
      );
    }

    facilities.sort(
      (first, second) => distances[first.id]!.compareTo(distances[second.id]!),
    );
  }

  final facility = await Navigator.of(context).push<SelectedFacility>(
    MaterialPageRoute<SelectedFacility>(
      builder: (context) => LocationPickerPage(
        facilities: facilities,
        distancesInMeters: distances,
         coordinatesById: sampleCoordinates,
      ),
    ),
  );

  if (!mounted || facility == null) return;

  setState(() {
    _selectedFacility = facility;
  });
}

  @override
  Widget build(BuildContext context) {
    final facility = _selectedFacility;

    return Scaffold(
      appBar: AppBar(title: const Text('Location Picker Demo')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: _pickLocation,
              child: const Text('Select Location'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
  onPressed: _isLocating ? null : _getCurrentLocation,
  child: const Text('Use My Location'),
),
Text(_locationMessage, textAlign: TextAlign.center),
const SizedBox(height: 16),
            if (facility == null)
              const Text('No location selected')
            else ...[
              Text('Selected: ${facility.name}'),
              Text('ID: ${facility.id}'),
            ],
          ],
        ),
      ),
    );
  }
}