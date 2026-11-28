import 'package:material_ui/material_ui.dart';
import '../../../../app/app_theme.dart';

class SelectedFacility {
  final String? facilityId;
  final String name;
  final double latitude;
  final double longitude;
  final int distanceMeters;

  const SelectedFacility({
    this.facilityId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
  });
}

class LocationPickerScreen extends StatefulWidget {
  final String? initialLocation;
  const LocationPickerScreen({super.key, this.initialLocation});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  SelectedFacility? _selected;

  // Sample facilities near UTS (until Dominic integrates live GPS + backend /api/facilities)
  final List<SelectedFacility> _facilities = const [
    SelectedFacility(
      facilityId: 'fac-uts-lib',
      name: 'UTS Library',
      latitude: 2.3401,
      longitude: 111.8435,
      distanceMeters: 120,
    ),
    SelectedFacility(
      facilityId: 'fac-uts-hall',
      name: 'Chancellor Hall',
      latitude: 2.3412,
      longitude: 111.8442,
      distanceMeters: 260,
    ),
    SelectedFacility(
      facilityId: 'fac-uts-lab',
      name: 'Computer Lab 3',
      latitude: 2.3395,
      longitude: 111.8428,
      distanceMeters: 340,
    ),
    SelectedFacility(
      facilityId: 'fac-uts-cafe',
      name: 'Student Cafeteria',
      latitude: 2.3389,
      longitude: 111.8419,
      distanceMeters: 480,
    ),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _selected = _facilities.cast<SelectedFacility?>().firstWhere(
            (f) => f?.name == widget.initialLocation,
            orElse: () => null,
          );
    }
    _selected ??= _facilities.first;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _facilities
        .where((f) => f.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Select Location'),
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location, color: AppColors.primary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Centered on current location (sample)')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search campus facilities...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textHint),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Map preview area (placeholder for Dominic's flutter_map)
          Container(
            height: 200,
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8EEFF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Subtle grid lines for map look
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _selected?.name ?? 'Select a pin',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Icon(Icons.location_on, size: 40, color: AppColors.primary),
                  ],
                ),
                Positioned(
                  bottom: 10,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Sample Map Preview (flutter_map)',
                      style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Nearby facilities header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Nearby Facilities (Sample)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Facilities list
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No matching facilities found.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final facility = filtered[index];
                      final isSelected = _selected?.facilityId == facility.facilityId;
                      return GestureDetector(
                        onTap: () => setState(() => _selected = facility),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primaryLight : AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : const Color(0xFFE5E7EB),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.location_on_outlined,
                                  size: 20,
                                  color: isSelected ? Colors.white : AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      facility.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      '${facility.distanceMeters} m away',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle, color: AppColors.primary),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Confirm button
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _selected == null
                  ? null
                  : () => Navigator.pop(context, _selected),
              child: const Text('Confirm Location'),
            ),
          ),
        ],
      ),
    );
  }
}
