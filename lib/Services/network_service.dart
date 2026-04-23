import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  static final Connectivity _connectivity = Connectivity();

  static Future<bool> isConnected() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  static Future<void> checkOrThrow() async {
    if (!await isConnected()) {
      throw Exception('No internet connection. Please check your network.');
    }
  }
}
