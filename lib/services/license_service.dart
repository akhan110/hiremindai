import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LicenseService {
  static const String _licenseKeyPref = 'hiremind_license_key';
  static const String _validMockKey = 'HIREMIND-PRO-2027';

  static Future<String> getHardwareId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isWindows) {
      final windowsInfo = await deviceInfo.windowsInfo;
      // Using a combination of identifiers as a unique fingerprint
      return '${windowsInfo.computerName}-${windowsInfo.numberOfCores}-${windowsInfo.systemMemoryInMegabytes}';
    } else if (Platform.isMacOS) {
      final macInfo = await deviceInfo.macOsInfo;
      return macInfo.systemGUID ?? 'UNKNOWN_MAC_ID';
    } else if (Platform.isLinux) {
      final linuxInfo = await deviceInfo.linuxInfo;
      return linuxInfo.machineId ?? 'UNKNOWN_LINUX_ID';
    }
    return 'UNKNOWN_DEVICE_ID';
  }

  static Future<bool> isLicenseValid() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString(_licenseKeyPref);
    
    // In a real app, you would make an API call here to verify if the key 
    // is STILL active on the LemonSqueezy server for this specific Hardware ID.
    // For now, we mock the check:
    return savedKey == _validMockKey;
  }

  static Future<bool> activateLicense(String key) async {
    // 1. Get Hardware ID
    await getHardwareId();
    
    // 2. Simulate API Call to Licensing Server (e.g., LemonSqueezy)
    await Future.delayed(const Duration(seconds: 2)); // Simulate network latency

    if (key.trim() == _validMockKey) {
      // 3. Save valid status
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_licenseKeyPref, key.trim());
      // Here you might also save the hardwareId locally or handle it server-side
      return true;
    }

    return false; // Invalid key
  }

  static Future<void> deactivateLicense() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_licenseKeyPref);
  }
}
