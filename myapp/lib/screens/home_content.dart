import 'package:flutter/material.dart';
import '../models/parking_lot.dart';

class HomeContent extends StatelessWidget {
  final String selectedDistrict;
  final List<String> districts;
  final bool isLoading;
  final List<ParkingLot> Function() getFilteredParkingLots;
  final Function(String?) onDistrictChanged;
  final VoidCallback onSearchChanged;
  final Future<void> Function() onRefresh;
  final Future<void> Function(double, double) openGoogleMaps;
  final Widget Function() buildNearbyParkingLots;

  const HomeContent({
    super.key,
    required this.selectedDistrict,
    required this.districts,
    required this.isLoading,
    required this.getFilteredParkingLots,
    required this.onDistrictChanged,
    required this.onSearchChanged,
    required this.onRefresh,
    required this.openGoogleMaps,
    required this.buildNearbyParkingLots,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<String>(
              value: selectedDistrict,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              items: districts.map((String district) {
                return DropdownMenuItem<String>(
                  value: district,
                  child: Text(district),
                );
              }).toList(),
              onChanged: onDistrictChanged,
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: buildNearbyParkingLots(),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'All Parking Lots',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final lots = getFilteredParkingLots();
                            final lot = lots[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: ListTile(
                                onTap: () => openGoogleMaps(
                                  lot.latitude,
                                  lot.longitude,
                                ),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(
                                    lot.carparkPhoto,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        Container(
                                      width: 60,
                                      height: 60,
                                      color: Colors.grey[300],
                                      child: const Icon(
                                        Icons.local_parking,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  lot.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(lot.displayAddress),
                                    const SizedBox(height: 4),
                                    Text(
                                      lot.remark.isEmpty 
                                          ? 'No remark available' 
                                          : lot.remark,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: lot.vacancy > 0
                                            ? Colors.green
                                            : Colors.red,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${lot.vacancy} spaces',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    if (lot.openingStatus.isNotEmpty)
                                      Text(
                                        lot.openingStatus,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                                isThreeLine: true,
                              ),
                            );
                          },
                          childCount: getFilteredParkingLots().length,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}