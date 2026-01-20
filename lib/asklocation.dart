import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

Future<Position?> askAndGetLocation() async {
  try {
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  } catch (e) {
    print('Location error: $e');
    if (kIsWeb) {
      print('Web geolocation error: $e');
    }
    return null;
  }
}
