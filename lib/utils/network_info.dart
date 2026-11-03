// import 'package:internet_connection_checker/internet_connection_checker.dart';

// abstract class NetworkInfo {
//   Future<bool> get isConnected;
// }

// class NetworkInfoImpl implements NetworkInfo {
//   final InternetConnectionChecker connectionChecker;

//   NetworkInfoImpl(this.connectionChecker);

//   @override
//   Future<bool> get isConnected => connectionChecker.hasConnection;
// }

// ignore_for_file: unrelated_type_equality_checks

import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';
import 'package:whoxa/core/api/api_endpoint.dart';

abstract class NetworkInfo {
  Future<bool> get isConnected;
}

class NetworkInfoImpl implements NetworkInfo {
  final Connectivity connectivity;

  NetworkInfoImpl(this.connectivity);

  @override
  Future<bool> get isConnected async {
    var result = await connectivity.checkConnectivity();
    if (result == ConnectivityResult.none) return false;

    // Reachability check. Previously this only looked up google.com, which
    // reads as "offline" in any region where Google is blocked even though
    // the user has working access to Whoxa's own servers. Try Whoxa's own
    // host first (the thing this check actually gates access to), then fall
    // back to google.com as a second opinion rather than a single point of
    // failure, so a transient blip on one host alone doesn't misreport the
    // user as offline.
    if (await _canResolve(Uri.parse(ApiEndpoints.baseUrl).host)) return true;
    return _canResolve('google.com');
  }

  Future<bool> _canResolve(String host) async {
    try {
      final lookup = await InternetAddress.lookup(host);
      return lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }
}
