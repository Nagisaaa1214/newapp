import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/parking_lot.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'notes_screen.dart';
import 'news_screen.dart';
import 'settings_screen.dart';
import 'home_content.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  List<ParkingLot> parkingLots = [];
  bool isLoading = true;
  Position? userLocation;
  String selectedDistrict = 'All Districts';
  List<String> districts = ['All Districts'];
  int _selectedIndex = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadParkingData();
    _getCurrentLocation();
    
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _loadParkingData();
    });
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  List<ParkingLot> getSortedByDistance(Position userLocation) {
    final lots = List<ParkingLot>.from(parkingLots);
    lots.sort((a, b) {
      double distA = _calculateDistance(
        userLocation.latitude,
        userLocation.longitude,
        a.latitude,
        a.longitude,
      );
      double distB = _calculateDistance(
        userLocation.latitude,
        userLocation.longitude,
        b.latitude,
        b.longitude,
      );
      return distA.compareTo(distB);
    });
    return lots;
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location services are disabled. Please enable location services.'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are denied. Some features may be limited.'),
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied. Please enable them in settings.'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        userLocation = position;
      });
    } catch (e) {
      print('Error getting location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting location: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _loadParkingData() async {
    try {
      setState(() {
        isLoading = true;
      });
      
      final infoResponse = await http.get(
        Uri.parse('https://api.data.gov.hk/v1/carpark-info-vacancy?data=info'),
      );
      final vacancyResponse = await http.get(
        Uri.parse('https://api.data.gov.hk/v1/carpark-info-vacancy?data=vacancy'),
      );

      if (infoResponse.statusCode == 200 && vacancyResponse.statusCode == 200) {
        final infoData = json.decode(infoResponse.body)['results'];
        final vacancyData = json.decode(vacancyResponse.body)['results'];

        Map<String, dynamic> vacancyMap = {};
        for (var vacancy in vacancyData) {
          vacancyMap[vacancy['park_Id']] = vacancy;
        }

        List<ParkingLot> lots = [];
        Set<String> distinctDistricts = {'All Districts'};

        for (var info in infoData) {
          if (vacancyMap.containsKey(info['park_Id'])) {
            lots.add(ParkingLot.fromJson(info, vacancyMap[info['park_Id']]));
            if (info['district'] != null && info['district'].toString().isNotEmpty) {
              distinctDistricts.add(info['district']);
            }
          }
        }

        setState(() {
          parkingLots = lots;
          districts = distinctDistricts.toList()..sort();
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load parking data: ${e.toString()}'),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _loadParkingData,
            ),
          ),
        );
      }
      print('Error loading parking data: $e');
    }
  }

  List<ParkingLot> getFilteredParkingLots() {
    return parkingLots.where((lot) {
      return selectedDistrict == 'All Districts' || lot.district == selectedDistrict;
    }).toList();
  }

  Widget _buildNearbyParkingLots() {
    if (userLocation == null) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Card(
          child: ListTile(
            leading: Icon(Icons.location_off),
            title: Text('Location services are disabled'),
            subtitle: Text('Enable location to see nearby parking lots'),
          ),
        ),
      );
    }

    final nearbyLots = getSortedByDistance(userLocation!)
        .where((lot) => lot.vacancy > 0)
        .take(3)
        .toList();

    if (nearbyLots.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Card(
          child: ListTile(
            leading: Icon(Icons.warning),
            title: Text('No available parking lots nearby'),
            subtitle: Text('Try expanding your search area'),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Nearest Available Parking',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: nearbyLots.length,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemBuilder: (context, index) {
              final lot = nearbyLots[index];
              final distance = _calculateDistance(
                userLocation!.latitude,
                userLocation!.longitude,
                lot.latitude,
                lot.longitude,
              );
              
              return SizedBox(
                width: 300,
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  child: InkWell(
                    onTap: () => _openGoogleMaps(lot.latitude, lot.longitude),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                          child: Image.network(
                            lot.carparkPhoto,
                            height: 100,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: 100,
                              color: Colors.grey[300],
                              child: const Icon(
                                Icons.local_parking,
                                size: 50,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lot.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 16,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${(distance / 1000).toStringAsFixed(1)} km away',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Vacancy: ${lot.vacancy}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openGoogleMaps(double lat, double lng) async {
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Parking Finder'),
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              bool confirm = await showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Logout'),
                      ),
                    ],
                  );
                },
              ) ?? false;

              if (confirm) {
                await _authService.signOut();
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeContent(
            selectedDistrict: selectedDistrict,
            districts: districts,
            isLoading: isLoading,
            getFilteredParkingLots: getFilteredParkingLots,
            onDistrictChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  selectedDistrict = newValue;
                });
              }
            },
            onSearchChanged: () {
              setState(() {});
            },
            onRefresh: _loadParkingData,
            openGoogleMaps: _openGoogleMaps,
            buildNearbyParkingLots: _buildNearbyParkingLots,
          ),
          const NotesScreen(),
          const NewsScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.white, // Changed to white for dark mode
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.grey[900], // Added dark background
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.note),
            label: 'Notes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.newspaper),
            label: 'News',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}