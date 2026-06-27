import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final userLocationProvider = StateProvider<Position?>((ref) => null);
