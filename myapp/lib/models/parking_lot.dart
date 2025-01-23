class ParkingLot {
  final String parkId;
  final String name;
  final String displayAddress;
  final String district;
  final double latitude;
  final double longitude;
  final String openingStatus;
  final String carparkPhoto;
  final String remark;
  final int vacancy;

  ParkingLot({
    required this.parkId,
    required this.name,
    required this.displayAddress,
    required this.district,
    required this.latitude,
    required this.longitude,
    required this.openingStatus,
    required this.carparkPhoto,
    required this.remark,
    required this.vacancy,
  });

  factory ParkingLot.fromJson(Map<String, dynamic> info, Map<String, dynamic> vacancy) {
    return ParkingLot(
      parkId: info['park_Id'] ?? '',
      name: info['name'] ?? '',
      displayAddress: info['displayAddress'] ?? '',
      district: info['district'] ?? '',
      latitude: info['latitude'] ?? 0.0,
      longitude: info['longitude'] ?? 0.0,
      openingStatus: info['opening_status'] ?? '',
      carparkPhoto: info['renditionUrls']?['carpark_photo'] ?? '',
      remark: info['heightLimits']?[0]?['remark'] ?? '',
      vacancy: vacancy['privateCar']?[0]?['vacancy'] ?? -1,
    );
  }
}