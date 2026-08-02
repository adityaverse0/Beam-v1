import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/send_mode.dart';
import 'package:localsend_app/provider/animation_provider.dart';
import 'package:localsend_app/provider/favorites_provider.dart';
import 'package:localsend_app/provider/network/nearby_devices_provider.dart';
import 'package:localsend_app/provider/network/scan_facade.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/provider/progress_provider.dart';
import 'package:localsend_app/provider/selection/selected_sending_files_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/device_type_ext.dart';
import 'package:localsend_app/util/favorites.dart';
import 'package:localsend_app/util/native/file_picker.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:localsend_isolates/model/session_status.dart';
import 'package:localsend_isolates/util/file_size_helper.dart';
import 'package:localsend_isolates/util/file_speed_helper.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

class QuickBeamPage extends StatefulWidget {
  const QuickBeamPage({super.key});

  static Future<void> open(BuildContext context) async {
    await context.push(() => const QuickBeamPage());
  }

  @override
  State<QuickBeamPage> createState() => _QuickBeamPageState();
}

class _QuickBeamPageState extends State<QuickBeamPage> with TickerProviderStateMixin, Refena {
  late AnimationController _radarController;
  late AnimationController _pulseController;
  late AnimationController _particleController;
  late AnimationController _morphController;

  bool _isSuccess = false;
  Timer? _dismissTimer;
  int _lastSpeedBytes = 0;
  int _lastTimeUpdate = 0;
  String _remainingTimeStr = '-';

  @override
  void initState() {
    super.initState();
    HapticFeedback.lightImpact();

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Automatically trigger smart scan on Quick Beam open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.redux(nearbyDevicesProvider).dispatch(ClearFoundDevicesAction());
      ref.global.dispatchAsync(StartSmartScan(forceLegacy: true));
    });
  }

  @override
  void dispose() {
    _radarController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    _morphController.dispose();
    _dismissTimer?.cancel();
    super.dispose();
  }

  void _triggerSuccess(String sessionId) {
    if (_isSuccess) return;
    setState(() => _isSuccess = true);
    HapticFeedback.heavyImpact();
    _morphController.forward(from: 0.0);

    _dismissTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        ref.notifier(sendProvider).closeSession(sessionId);
        context.pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final nearbyDevices = ref.watch(nearbyDevicesProvider.select((s) => s.devices.values.toList()));
    final favoriteDevices = ref.watch(favoritesProvider);
    final selectedFiles = ref.watch(selectedSendingFilesProvider);
    final sendSessions = ref.watch(sendProvider);
    final receiveSession = ref.watch(serverProvider.select((s) => s?.session));
    final animationsEnabled = ref.watch(animationProvider);

    // Determine current active session
    final activeSendSessionEntry = sendSessions.entries.firstWhere(
      (e) => e.value.status == SessionStatus.sending || e.value.status == SessionStatus.finished,
      orElse: () => MapEntry('', sendSessions.values.firstOrNull ?? (throw Exception('No session'))),
    );

    final activeSendSession = sendSessions.isNotEmpty && activeSendSessionEntry.key.isNotEmpty
        ? activeSendSessionEntry.value
        : null;

    final isTransferring = (activeSendSession != null && activeSendSession.status == SessionStatus.sending) ||
        (receiveSession != null && receiveSession.status == SessionStatus.sending);

    final isFinished = (activeSendSession != null && activeSendSession.status == SessionStatus.finished) ||
        (receiveSession != null && receiveSession.status == SessionStatus.finished);

    if (isFinished && !_isSuccess && activeSendSession != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerSuccess(activeSendSession.sessionId);
      });
    }

    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background Blur Overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                color: theme.brightness == Brightness.dark
                    ? Colors.black.withOpacity(0.75)
                    : Colors.white.withOpacity(0.85),
              ),
            ),
          ),

          // Floating Ambient Particles Custom Painter
          if (animationsEnabled)
            Positioned.fill(
              child: CustomPaint(
                painter: _FloatingParticlesPainter(
                  animation: _particleController,
                  color: primaryColor.withOpacity(0.15),
                ),
              ),
            ),

          // Content Layout
          SafeArea(
            child: Column(
              children: [
                // Top Header Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: primaryColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt, color: primaryColor, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              'BEAM QUICK',
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      IconButton.filledTonal(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.close),
                        tooltip: t.general.close,
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: isTransferring || _isSuccess
                      ? _buildTransferView(
                          context,
                          activeSendSession,
                          receiveSession,
                          primaryColor,
                        )
                      : _buildDiscoveryView(
                          context,
                          nearbyDevices,
                          favoriteDevices,
                          selectedFiles,
                          primaryColor,
                          animationsEnabled,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoveryView(
    BuildContext context,
    List<Device> nearbyDevices,
    List<FavoriteEntry> favoriteDevices,
    List<CrossFile> selectedFiles,
    Color primaryColor,
    bool animationsEnabled,
  ) {
    return Column(
      children: [
        const SizedBox(height: 10),
        // Radar Scan Hero Area
        SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Concentric Radar Scanner Rings
              if (animationsEnabled)
                CustomPaint(
                  size: const Size(220, 220),
                  painter: _RadarScannerPainter(
                    animation: _radarController,
                    color: primaryColor,
                  ),
                ),
              // Center Pulsing Circle
              ScaleTransition(
                scale: Tween<double>(begin: 0.95, end: 1.08).animate(
                  CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
                ),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [primaryColor, primaryColor.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.4),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.wifi_tethering, color: Colors.white, size: 40),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Opacity(
              opacity: 0.6 + (_pulseController.value * 0.4),
              child: Text(
                t.sendTab.nearbyDevices,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
              ),
            );
          },
        ),

        const SizedBox(height: 8),

        // Files selection bar if selected
        if (selectedFiles.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.file_present, color: primaryColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${selectedFiles.length} file(s) selected (${selectedFiles.fold<int>(0, (p, c) => p + c.size).asReadableFileSize})',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref.redux(selectedSendingFilesProvider).dispatch(ClearSelectionAction()),
                    child: Text(t.general.clear),
                  ),
                ],
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () async {
                final options = FilePickerOption.getOptionsForPlatform();
                if (options.isNotEmpty) {
                  await ref.global.dispatchAsync(
                    PickFileAction(
                      option: options.first,
                      context: context,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(t.sendTab.selection.title),
            ),
          ),

        const SizedBox(height: 12),

        // Device Cards List
        Expanded(
          child: nearbyDevices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Searching for nearby devices...',
                        style: TextStyle(color: Theme.of(context).colorScheme.outline),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () async {
                          ref.redux(nearbyDevicesProvider).dispatch(ClearFoundDevicesAction());
                          await ref.global.dispatchAsync(StartSmartScan(forceLegacy: true));
                        },
                        icon: const Icon(Icons.refresh),
                        label: Text(t.sendTab.scan),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: nearbyDevices.length,
                  itemBuilder: (context, index) {
                    final device = nearbyDevices[index];
                    final favoriteEntry = favoriteDevices.findDevice(device);
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 300 + (index * 100)),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, (1 - value) * 20),
                          child: Opacity(
                            opacity: value,
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              elevation: 2,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: CircleAvatar(
                                  radius: 26,
                                  backgroundColor: primaryColor.withOpacity(0.15),
                                  child: Icon(device.deviceType.icon, color: primaryColor, size: 28),
                                ),
                                title: Text(
                                  favoriteEntry?.alias ?? device.alias,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                                ),
                                subtitle: Text(
                                  '${device.deviceModel ?? device.deviceType.name} • ${device.ip}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                trailing: IconButton.filledTonal(
                                  icon: const Icon(Icons.send_rounded),
                                  onPressed: () async {
                                    HapticFeedback.mediumImpact();
                                    final selectedFiles = ref.read(selectedSendingFilesProvider);
                                    if (selectedFiles.isEmpty) {
                                      final options = FilePickerOption.getOptionsForPlatform();
                                      if (options.isNotEmpty) {
                                        await ref.global.dispatchAsync(
                                          PickFileAction(
                                            option: options.first,
                                            context: context,
                                          ),
                                        );
                                      }
                                    }

                                    if (ref.read(selectedSendingFilesProvider).isNotEmpty) {
                                      await ref.notifier(sendProvider).startSession(
                                            target: device,
                                            files: ref.read(selectedSendingFilesProvider),
                                          );
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTransferView(
    BuildContext context,
    dynamic sendSession,
    dynamic receiveSession,
    Color primaryColor,
  ) {
    final progressNotifier = ref.watch(progressProvider);
    final String sessionId = sendSession?.sessionId ?? receiveSession?.sessionId ?? '';
    final files = sendSession?.files.values.map((f) => f.file).toList() ??
        receiveSession?.files.values.map((f) => f.file).toList() ??
        [];

    final totalBytes = files.fold<int>(0, (p, c) => p + (c.size as int));
    final currBytes = files.fold<int>(
      0,
      (p, c) => p + ((progressNotifier.getProgress(sessionId: sessionId, fileId: c.id) * (c.size as int)).round()),
    );

    final double progress = totalBytes == 0 ? 0.0 : currBytes / totalBytes;
    final int now = DateTime.now().millisecondsSinceEpoch;

    if (sendSession?.startTime != null && currBytes > 100 * 1024) {
      _lastSpeedBytes = getFileSpeed(
        start: sendSession.startTime as int,
        end: (sendSession.endTime as int?) ?? now,
        bytes: currBytes,
      );
      if (now - _lastTimeUpdate >= 1000) {
        _remainingTimeStr = getRemainingTime(
          bytesPerSeconds: _lastSpeedBytes,
          remainingBytes: totalBytes - currBytes,
          strings: notificationStrings,
        );
        _lastTimeUpdate = now;
      }
    }

    final targetDeviceName = sendSession?.target.alias ?? receiveSession?.sender.alias ?? 'Nearby Device';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          // Morphing Ring / Success Checkmark Hero Container
          SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_isSuccess)
                  CustomPaint(
                    size: const Size(180, 180),
                    painter: _ParticleBurstPainter(animation: _morphController, color: Colors.green),
                  ),
                AnimatedBuilder(
                  animation: _morphController,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(160, 160),
                      painter: _MorphingProgressPainter(
                        progress: _isSuccess ? 1.0 : progress,
                        morphValue: _morphController.value,
                        primaryColor: _isSuccess ? Colors.green : primaryColor,
                      ),
                    );
                  },
                ),
                Icon(
                  _isSuccess ? Icons.check_rounded : Icons.swap_vert_rounded,
                  size: 64,
                  color: _isSuccess ? Colors.green : primaryColor,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          Text(
            _isSuccess
                ? t.general.finished
                : sendSession != null
                    ? t.progressPage.titleSending
                    : t.progressPage.titleReceiving,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            targetDeviceName,
            style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 16),
          ),

          const SizedBox(height: 24),

          // Transfer Speed & Remaining Time Stats
          if (!_isSuccess) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        _lastSpeedBytes.asReadableFileSize + '/s',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Speed',
                        style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12),
                      ),
                    ],
                  ),
                  Container(height: 30, width: 1, color: Theme.of(context).dividerColor),
                  Column(
                    children: [
                      Text(
                        _remainingTimeStr,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Remaining',
                        style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const Spacer(),

          // Controls (Cancel / Close)
          if (!_isSuccess)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () {
                  if (sendSession != null) {
                    ref.notifier(sendProvider).cancelSession(sessionId);
                  } else if (receiveSession != null) {
                    ref.notifier(serverProvider).cancelSession();
                  }
                  context.pop();
                },
                icon: const Icon(Icons.close),
                label: Text(t.general.cancel),
              ),
            ),
        ],
      ),
    );
  }
}

/// Custom Painter for Radar Scanning Animation
class _RadarScannerPainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  _RadarScannerPainter({required this.animation, required this.color}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final progress = (animation.value + (i / 3)) % 1.0;
      final radius = progress * maxRadius;
      final opacity = (1.0 - progress).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = color.withOpacity(opacity * 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarScannerPainter oldDelegate) => true;
}

/// Floating Particles Painter for Ambient Background Effect
class _FloatingParticlesPainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  _FloatingParticlesPainter({required this.animation, required this.color}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(42);
    final paint = Paint()..color = color;

    for (int i = 0; i < 12; i++) {
      final startX = rand.nextDouble() * size.width;
      final startY = rand.nextDouble() * size.height;
      final speed = 0.2 + rand.nextDouble() * 0.5;
      final radius = 2.0 + rand.nextDouble() * 4.0;

      final currentY = (startY - (animation.value * size.height * speed)) % size.height;
      final currentX = startX + math.sin(animation.value * math.pi * 2 + i) * 15;

      canvas.drawCircle(Offset(currentX, currentY), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FloatingParticlesPainter oldDelegate) => true;
}

/// Morphing Progress Ring & Checkmark Painter
class _MorphingProgressPainter extends CustomPainter {
  final double progress;
  final double morphValue;
  final Color primaryColor;

  _MorphingProgressPainter({
    required this.progress,
    required this.morphValue,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 8;

    final bgPaint = Paint()
      ..color = primaryColor.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0;

    canvas.drawCircle(center, radius, bgPaint);

    final progressPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10.0;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MorphingProgressPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.morphValue != morphValue;
}

/// Radial Particle Burst Painter for Success State
class _ParticleBurstPainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  _ParticleBurstPainter({required this.animation, required this.color}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final progress = animation.value;
    final paint = Paint()..color = color.withOpacity((1.0 - progress).clamp(0.0, 1.0));

    for (int i = 0; i < 16; i++) {
      final angle = (i / 16) * 2 * math.pi;
      final distance = 40 + (progress * 50);
      final x = center.dx + math.cos(angle) * distance;
      final y = center.dy + math.sin(angle) * distance;

      canvas.drawCircle(Offset(x, y), 3.5 * (1.0 - progress), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticleBurstPainter oldDelegate) => true;
}
