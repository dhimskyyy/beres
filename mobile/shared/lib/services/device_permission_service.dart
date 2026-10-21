import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../adapters/map_adapter.dart';

/// Layanan untuk Permintaan Izin Perangkat (Lokasi GPS & Kamera/Galeri)
class DevicePermissionService {
  static final DevicePermissionService _instance =
      DevicePermissionService._internal();
  factory DevicePermissionService() => _instance;
  DevicePermissionService._internal();

  final ImagePicker _picker = ImagePicker();

  /// Default koordinat (Jakarta Pusat) jika izin lokasi ditolak atau GPS mati
  static const MapLatLng defaultLocation = MapLatLng(-6.2088, 106.8456);

  /// Memeriksa dan meminta izin akses lokasi GPS kepada pengguna
  Future<MapLatLng> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[DevicePermissionService] Location services disabled.');
        return defaultLocation;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint(
              '[DevicePermissionService] Location permission denied by user.');
          return defaultLocation;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint(
            '[DevicePermissionService] Location permission denied forever.');
        return defaultLocation;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      return MapLatLng(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('[DevicePermissionService] Error getting location: $e');
      return defaultLocation;
    }
  }

  /// Meminta izin kamera dan mengambil foto langsung dari kamera
  Future<XFile?> pickImageFromCamera() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
    } catch (e) {
      debugPrint('[DevicePermissionService] Error picking from camera: $e');
      return null;
    }
  }

  /// Meminta izin galeri dan memilih foto dari galeri
  Future<XFile?> pickImageFromGallery() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
    } catch (e) {
      debugPrint('[DevicePermissionService] Error picking from gallery: $e');
      return null;
    }
  }

  /// Mengambil bytes dari XFile untuk diunggah ke storage Supabase
  Future<Uint8List?> getImageBytes(XFile file) async {
    try {
      return await file.readAsBytes();
    } catch (e) {
      debugPrint('[DevicePermissionService] Error reading image bytes: $e');
      return null;
    }
  }
}
