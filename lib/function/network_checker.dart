import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class NetworkConnectivity {
  // Singleton instance
  static final NetworkConnectivity _singleton = NetworkConnectivity._internal();
  NetworkConnectivity._internal();

  static NetworkConnectivity get instance => _singleton;

  // Stream controller for network status updates
  final _networkStatusController = StreamController<bool>.broadcast();
  Stream<bool> get networkStatus => _networkStatusController.stream;

  // Connectivity plugin instance
  final Connectivity _connectivity = Connectivity();

  // Variables to track the state
  bool _isInitialized = false;
  bool _hasConnectivity = true;
  bool _initialCheckDone = false;
  StreamSubscription? _connectivitySubscription;
  Timer? _pingTimer;

  // Initialize connectivity monitoring
  Future<bool> initialize() async {
    if (_isInitialized) {
      return _hasConnectivity;
    }

    // First check for current status using a more reliable method
    _hasConnectivity = await _hasRealInternetConnection();
    _initialCheckDone = true;

    // Listen for connectivity changes
    try {
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
        List<ConnectivityResult> results,
      ) async {
        // If any connectivity type other than none is found
        bool maybeConnected = results.any(
          (result) => result != ConnectivityResult.none,
        );

        if (!maybeConnected) {
          // If adapter reports no connectivity, we're definitely offline
          if (_hasConnectivity) {
            _hasConnectivity = false;
            _networkStatusController.add(false);
            print("Network lost (adapter reported)");
          }
        } else {
          // Adapter reports connectivity, but let's verify with a real internet check
          final realConnection = await _hasRealInternetConnection();
          if (_hasConnectivity != realConnection) {
            _hasConnectivity = realConnection;
            _networkStatusController.add(realConnection);
            print("Network status changed to: $realConnection (verified)");
          }
        }
      });
    } catch (e) {
      print("Error setting up connectivity listener: $e");
      // Fallback to ping timer only
    }

    // Start ping timer for periodic connectivity checks
    _startPingTimer();

    _isInitialized = true;
    return _hasConnectivity;
  }

  // Start periodic ping checks
  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      final currentStatus = await _hasRealInternetConnection();
      if (_hasConnectivity != currentStatus) {
        _hasConnectivity = currentStatus;
        _networkStatusController.add(currentStatus);
        print("Network status changed to: $currentStatus (by periodic check)");
      }
    });
  }

  // Thorough check for actual internet connectivity
  Future<bool> _hasRealInternetConnection() async {
    try {
      // Try multiple sources with a short timeout
      final futures = [
        _pingHost('8.8.8.8'), // Google DNS
        _pingHost('1.1.1.1'), // Cloudflare DNS
        _pingHost('208.67.222.222'), // OpenDNS
      ];

      // If any ping succeeds, we have connectivity
      final results = await Future.wait(
        futures,
        eagerError: false,
      ).timeout(const Duration(seconds: 5));

      return results.any((result) => result);
    } catch (e) {
      print("Internet check error: $e");
      return false;
    }
  }

  // Try to ping a single host
  Future<bool> _pingHost(String host) async {
    try {
      final result = await InternetAddress.lookup(
        host,
      ).timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Public method to check current connectivity status
  Future<bool> checkConnectivity() async {
    return await _hasRealInternetConnection();
  }

  // Check if initial check is done
  bool get initialCheckDone => _initialCheckDone;

  // Get current connectivity status
  bool get hasConnectivity => _hasConnectivity;

  // Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _pingTimer?.cancel();
    _networkStatusController.close();
    _isInitialized = false;
    _initialCheckDone = false;
  }
}

// Widget to display when app starts without network
class NoNetworkScreen extends StatefulWidget {
  final VoidCallback onRetry;

  const NoNetworkScreen({Key? key, required this.onRetry}) : super(key: key);

  @override
  State<NoNetworkScreen> createState() => _NoNetworkScreenState();
}

class _NoNetworkScreenState extends State<NoNetworkScreen> {
  bool _checkingConnection = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // No internet icon
            Icon(Icons.signal_wifi_off, size: 100, color: Colors.red[400]),
            const SizedBox(height: 24),
            const Text(
              'No Internet Connection',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Please check your connection and try again',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed:
                  _checkingConnection
                      ? null
                      : () async {
                        setState(() {
                          _checkingConnection = true;
                        });

                        // Wait a moment and check connection
                        await Future.delayed(Duration(seconds: 1));
                        bool isConnected =
                            await NetworkConnectivity.instance
                                .checkConnectivity();

                        if (isConnected) {
                          widget.onRetry();
                        } else {
                          setState(() {
                            _checkingConnection = false;
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Still no internet connection. Please try again.',
                              ),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
              icon:
                  _checkingConnection
                      ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : Icon(Icons.refresh),
              label: Text(_checkingConnection ? 'Checking...' : 'Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget that wraps the app and handles network connectivity
class NetworkAwareWidget extends StatefulWidget {
  final Widget child;
  final Widget? loadingWidget;
  final bool showOfflineScreenOnStart;

  const NetworkAwareWidget({
    Key? key,
    required this.child,
    this.loadingWidget,
    this.showOfflineScreenOnStart = true,
  }) : super(key: key);

  @override
  State<NetworkAwareWidget> createState() => _NetworkAwareWidgetState();
}

class _NetworkAwareWidgetState extends State<NetworkAwareWidget> {
  late Future<bool> _initFuture;
  bool _isFirstRun = true;
  bool _isSnackBarVisible = false;

  @override
  void initState() {
    super.initState();
    _initFuture = NetworkConnectivity.instance.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _initFuture,
      builder: (context, snapshot) {
        // Show loading widget while checking connectivity
        if (snapshot.connectionState != ConnectionState.done) {
          return widget.loadingWidget ??
              Scaffold(
                backgroundColor: Colors.black,
                body: Center(child: CircularProgressIndicator()),
              );
        }

        // If this is the first run and there's no connectivity, show the no network screen
        final bool hasConnectivity = snapshot.data ?? false;
        if (_isFirstRun &&
            !hasConnectivity &&
            widget.showOfflineScreenOnStart) {
          _isFirstRun = false;
          return NoNetworkScreen(
            onRetry: () {
              setState(() {
                _initFuture = NetworkConnectivity.instance.initialize();
                _isFirstRun = true;
              });
            },
          );
        }

        // If we have connectivity or it's not the first run, show the app
        _isFirstRun = false;

        // Listen for connectivity changes with StreamBuilder
        return StreamBuilder<bool>(
          stream: NetworkConnectivity.instance.networkStatus,
          initialData: hasConnectivity,
          builder: (context, streamSnapshot) {
            final bool currentConnectivity = streamSnapshot.data ?? false;

            // Show snackbars for connectivity changes (don't show on first build)
            if (NetworkConnectivity.instance.initialCheckDone) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!currentConnectivity && !_isSnackBarVisible) {
                  _isSnackBarVisible = true;
                  // Network lost during app use
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: const [
                          Icon(Icons.signal_wifi_off, color: Colors.white),
                          SizedBox(width: 8),
                          Expanded(child: Text('No internet connection')),
                        ],
                      ),
                      backgroundColor: Colors.red,
                      duration: const Duration(
                        days: 1,
                      ), // Will be dismissed when connection returns
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(8),
                      onVisible: () {
                        _isSnackBarVisible = true;
                      },
                      dismissDirection: DismissDirection.horizontal,
                    ),
                  );
                } else if (currentConnectivity && _isSnackBarVisible) {
                  _isSnackBarVisible = false;
                  // Network restored during app use
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: const [
                          Icon(Icons.wifi, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Internet connection restored'),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 3),
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(8),
                      onVisible: () {
                        // Will auto-close after duration
                      },
                    ),
                  );
                }
              });
            }

            return widget.child;
          },
        );
      },
    );
  }
}
