import 'package:flutter/material.dart';
import 'package:whoxa/dependency_injection.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/error/app_error.dart';
import 'package:whoxa/design/fp_components.dart';
import 'package:whoxa/design/fp_tokens.dart';
import 'package:whoxa/featuers/provider/theme_provider.dart';

/// WhatsApp-Web-style "link a browser".
///
/// The web login page shows a QR that encodes
/// `https://web.flickpitch.com/link-device?sid=<uuid>&key=<secret>`.
/// This screen scans it, asks the account holder to confirm, then approves the
/// pairing. The browser picks up a normal access token on its next poll and
/// then appears under linked devices like any other session.
enum _Stage { scanning, confirming, working, done, failed }

class FpLinkDeviceScreen extends StatefulWidget {
  const FpLinkDeviceScreen({super.key});

  @override
  State<FpLinkDeviceScreen> createState() => _FpLinkDeviceScreenState();
}

class _FpLinkDeviceScreenState extends State<FpLinkDeviceScreen> {
  final ApiClient _api = getIt<ApiClient>();

  _Stage _stage = _Stage.scanning;
  List<_Device> _devices = const [];
  bool _loadingDevices = true;
  String? _sid;
  String? _secret;
  String? _browser;
  String? _ip;
  String? _error;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _loadingDevices = true);
    try {
      final res = await _api.request('/auth/devices');
      dynamic node = res;
      if (node is Map && node['data'] != null) node = node['data'];
      final list = (node is Map && node['devices'] is List)
          ? (node['devices'] as List)
          : const [];
      if (!mounted) return;
      setState(() {
        _devices = list.whereType<Map>().map(_Device.fromJson).toList();
        _loadingDevices = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingDevices = false);
    }
  }

  Future<void> _signOutDevice(_Device device) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(Fp.s12),
        padding: const EdgeInsets.all(Fp.s24),
        decoration: BoxDecoration(
          color: Fp.inkSoft,
          borderRadius: BorderRadius.circular(Fp.rLg),
          border: Border.all(color: Fp.hairlineStrong),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Log out ${device.title}?',
              style: Fp.h2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Fp.s8),
            Text(
              'That device is signed out immediately and has to scan a new QR code to come back.',
              style: Fp.body.copyWith(color: Fp.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Fp.s24),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(Fp.rPill),
                  onTap: () => Navigator.pop(ctx, true),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Fp.coral, Color(0xFFD7263D)],
                      ),
                      borderRadius: BorderRadius.circular(Fp.rPill),
                    ),
                    child: Text(
                      'Log out device',
                      style: Fp.bodyStrong.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Fp.s8),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: Fp.bodyStrong.copyWith(color: Fp.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await _api.request('/auth/devices/${device.deviceId}', method: 'DELETE');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not log that device out. Try again.'),
        ),
      );
      return;
    }
    await _loadDevices();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: Fp.ink,
      body: FpCanvas(
        child: SafeArea(
          child: Column(
            children: [
              _header(),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Fp.s24, Fp.s16, Fp.s16, Fp.s8),
      child: Row(
        children: [
          Expanded(child: Text('Linked devices', style: Fp.h2)),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            color: Fp.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _body() {
    switch (_stage) {
      case _Stage.scanning:
        return _scanner();
      case _Stage.confirming:
        return _confirm();
      case _Stage.working:
        return _centered(
          icon: Icons.sync,
          title: 'Linking browser…',
          body: 'Hold on a moment.',
          busy: true,
        );
      case _Stage.done:
        return _centered(
          icon: Icons.check_circle_outline,
          tint: Fp.mint,
          title: 'Browser linked',
          body: 'That browser is now signed in. You can remove it any time from Linked devices.',
          actionLabel: 'Done',
          onAction: () => Navigator.pop(context),
        );
      case _Stage.failed:
        return _centered(
          icon: Icons.error_outline,
          tint: Fp.coral,
          title: 'Could not link',
          body: _error ?? 'That QR code is not valid any more.',
          actionLabel: 'Try again',
          onAction: _reset,
        );
    }
  }

  Widget _scanner() {
    return Column(
      children: [
        _devicesSection(),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Fp.s24),
            child: MobileScanner(
              onDetect: _onDetect,
              errorBuilder: (context, error) => _centered(
                icon: Icons.no_photography_outlined,
                tint: Fp.coral,
                title: 'Camera unavailable',
                body: 'Allow camera access for Flickpitch, then reopen this screen to scan the code.',
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Fp.s24, Fp.s20, Fp.s24, Fp.s24),
          child: Column(
            children: [
              Text(
                'Point at the QR code',
                style: Fp.h2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Fp.s8),
              Text(
                'Open web.flickpitch.com on your computer and scan the code shown on the login screen.',
                style: Fp.body.copyWith(color: Fp.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _confirm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Fp.s24),
      child: Column(
        children: [
          const SizedBox(height: Fp.s8),
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: Fp.violetGlow.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.laptop_mac, color: Fp.violetGlow, size: 34),
          ),
          const SizedBox(height: Fp.s20),
          Text('Link this browser?', style: Fp.h2, textAlign: TextAlign.center),
          const SizedBox(height: Fp.s8),
          Text(
            'Only continue if you started this on your own computer.',
            style: Fp.body.copyWith(color: Fp.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Fp.s16),
          Container(
            padding: const EdgeInsets.all(Fp.s16),
            decoration: BoxDecoration(
              color: Fp.inkRaised,
              borderRadius: BorderRadius.circular(Fp.s16),
              border: Border.all(color: Fp.hairline),
            ),
            child: Column(
              children: [
                _kv('Browser', _browser ?? 'Unknown device'),
                const SizedBox(height: Fp.s8),
                _kv('Network', _ip ?? 'Unknown'),
              ],
            ),
          ),
          const SizedBox(height: Fp.s24),
          SizedBox(
            height: 54,
            width: double.infinity,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(Fp.rPill),
                onTap: _approve,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: Fp.accent,
                    borderRadius: BorderRadius.circular(Fp.rPill),
                  ),
                  child: Text(
                    'Link this browser',
                    style: Fp.bodyStrong.copyWith(color: Fp.onAccent),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: Fp.s8),
          TextButton(
            onPressed: _rejectAndReset,
            child: Text(
              'Not me — cancel',
              style: Fp.bodyStrong.copyWith(color: Fp.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 92,
        child: Text(k, style: Fp.label.copyWith(color: Fp.textMuted)),
      ),
      Expanded(
        child: Text(
          v,
          style: Fp.bodyStrong.copyWith(fontSize: 13),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );

  Widget _centered({
    required IconData icon,
    required String title,
    required String body,
    Color? tint,
    bool busy = false,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.all(Fp.s24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (busy)
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            )
          else
            Icon(icon, size: 56, color: tint ?? Fp.violetGlow),
          const SizedBox(height: Fp.s16),
          Text(title, style: Fp.h2, textAlign: TextAlign.center),
          const SizedBox(height: Fp.s8),
          Text(
            body,
            style: Fp.body.copyWith(color: Fp.textMuted),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: Fp.s24),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(Fp.rPill),
                  onTap: onAction,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: Fp.accent,
                      borderRadius: BorderRadius.circular(Fp.rPill),
                    ),
                    child: Text(
                      actionLabel,
                      style: Fp.bodyStrong.copyWith(color: Fp.onAccent),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _devicesSection() {
    if (_loadingDevices) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: Fp.s16),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_devices.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(Fp.s24, Fp.s8, Fp.s24, 0),
      padding: const EdgeInsets.all(Fp.s12),
      decoration: BoxDecoration(
        color: Fp.inkSoft,
        borderRadius: BorderRadius.circular(Fp.rLg),
        border: Border.all(color: Fp.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              'Signed in devices (${_devices.length})',
              style: Fp.label.copyWith(color: Fp.textMuted),
            ),
          ),
          ..._devices.map(
            (d) => Row(
              children: [
                Icon(
                  d.isWeb ? Icons.laptop_mac : Icons.smartphone,
                  size: 18,
                  color: Fp.textMuted,
                ),
                const SizedBox(width: Fp.s8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.title,
                        style: Fp.bodyStrong.copyWith(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (d.subtitle.isNotEmpty)
                        Text(
                          d.subtitle,
                          style: Fp.body.copyWith(
                            color: Fp.textFaint,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Log out this device',
                  onPressed: () => _signOutDevice(d),
                  icon: Icon(Icons.logout, size: 18, color: Fp.coral),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _reset() {
    setState(() {
      _stage = _Stage.scanning;
      _handled = false;
      _error = null;
      _sid = null;
      _secret = null;
      _browser = null;
      _ip = null;
    });
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled || _stage != _Stage.scanning) return;
    if (capture.barcodes.isEmpty) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    final parsed = _parsePayload(raw);
    if (parsed == null) return; // not one of our codes — keep scanning
    _handled = true;

    setState(() {
      _sid = parsed.$1;
      _secret = parsed.$2;
      _stage = _Stage.working;
    });

    try {
      final res = await _api.request(
        '/auth/qr/${parsed.$1}/scan',
        method: 'POST',
        body: {'secret': parsed.$2},
      );
      final data = (res is Map && res['data'] is Map)
          ? res['data'] as Map
          : const {};
      if (!mounted) return;
      setState(() {
        _browser = data['browser'] as String?;
        _ip = data['ip'] as String?;
        _stage = _Stage.confirming;
      });
    } catch (e) {
      if (!mounted) return;
      // A 401 means THIS phone's session is no longer valid (e.g. after a
      // forced sign-out). Without this branch the screen silently showed
      // "code expired" and the browser just waited forever.
      final sessionDead = e is AppError && e.statusCode == 401;
      setState(() {
        _error = sessionDead
            ? 'Your session on this phone has expired. Sign in again, then scan the code.'
            : 'This code expired or was already used. Ask the browser for a new one.';
        _stage = _Stage.failed;
        _handled = false;
      });
    }
  }

  /// Returns (sessionId, secret), or null when the payload is not ours.
  (String, String)? _parsePayload(String raw) {
    try {
      final uri = Uri.parse(raw);
      final sid = uri.queryParameters['sid'];
      final key = uri.queryParameters['key'];
      if (sid == null || key == null) return null;
      if (!sid.contains('-') || key.length < 16) return null;
      return (sid, key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _approve() async {
    final sid = _sid;
    final secret = _secret;
    if (sid == null || secret == null) return;
    setState(() => _stage = _Stage.working);
    try {
      await _api.request(
        '/auth/qr/$sid/approve',
        method: 'POST',
        body: {'secret': secret},
      );
      if (!mounted) return;
      setState(() => _stage = _Stage.done);
    } catch (e) {
      if (!mounted) return;
      final sessionDead = e is AppError && e.statusCode == 401;
      setState(() {
        _error = sessionDead
            ? 'Your session on this phone has expired. Sign in again, then scan the code.'
            : 'We could not approve this browser. Try again.';
        _stage = _Stage.failed;
      });
    }
  }

  Future<void> _rejectAndReset() async {
    final sid = _sid;
    final secret = _secret;
    if (sid != null && secret != null) {
      try {
        await _api.request(
          '/auth/qr/$sid/reject',
          method: 'POST',
          body: {'secret': secret},
        );
      } catch (_) {
        // best effort — the code expires on its own anyway
      }
    }
    _reset();
  }
}

class _Device {
  const _Device({
    required this.deviceId,
    required this.name,
    required this.platform,
    required this.location,
  });

  final String deviceId;
  final String name;
  final String platform;
  final String location;

  bool get isWeb => platform.toLowerCase().contains('web');

  String get title =>
      name.isNotEmpty ? name : (isWeb ? 'Web browser' : 'Mobile device');

  String get subtitle => [
    if (location.isNotEmpty) location,
    if (platform.isNotEmpty) platform,
  ].join(' · ');

  static _Device fromJson(Map m) => _Device(
    deviceId: '${m['deviceId'] ?? m['device_id'] ?? ''}',
    name: '${m['deviceName'] ?? m['device_name'] ?? ''}'.trim(),
    platform: '${m['platform'] ?? ''}'.trim(),
    location: '${m['lastLocation'] ?? m['last_location'] ?? ''}'.trim(),
  );
}
