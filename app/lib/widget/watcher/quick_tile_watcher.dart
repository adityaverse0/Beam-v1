import 'dart:async';

import 'package:flutter/material.dart';
import 'package:localsend_app/pages/quick_beam_page.dart';
import 'package:localsend_app/provider/network/nearby_devices_provider.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/util/native/quick_tile_helper.dart';
import 'package:localsend_isolates/model/session_status.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

class QuickTileWatcher extends StatefulWidget {
  final Widget child;

  const QuickTileWatcher({required this.child, super.key});

  @override
  State<QuickTileWatcher> createState() => _QuickTileWatcherState();
}

class _QuickTileWatcherState extends State<QuickTileWatcher> with Refena {
  String _lastTileState = 'idle';

  @override
  void initState() {
    super.initState();

    QuickTileHelper.init(onLaunch: () {
      _checkAndOpenQuickBeam();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndOpenQuickBeam();
    });
  }

  Future<void> _checkAndOpenQuickBeam() async {
    final launchedFromTile = await QuickTileHelper.checkLaunchFromTile();
    if (launchedFromTile && mounted) {
      // Open Quick Beam Page directly
      final context = Routerino.navigatorKey.currentContext;
      if (context != null) {
        QuickBeamPage.open(context);
      }
    }
  }

  void _syncTileState(WatchableRef ref) {
    final nearbyState = ref.watch(nearbyDevicesProvider);
    final sendSessions = ref.watch(sendProvider);
    final serverSession = ref.watch(serverProvider.select((s) => s?.session));

    final isSending = sendSessions.values.any((s) => s.status == SessionStatus.sending);
    final isReceiving = serverSession?.status == SessionStatus.sending;

    final isConnectedSend = sendSessions.values.any((s) => s.status == SessionStatus.finished || s.status == SessionStatus.waiting);
    final isConnectedReceive = serverSession?.status == SessionStatus.finished || serverSession?.status == SessionStatus.waiting;

    final isScanning = nearbyState.runningIps.isNotEmpty || nearbyState.runningFavoriteScan;

    String state;
    if (isSending || isReceiving) {
      state = 'transferring';
    } else if (isConnectedSend || isConnectedReceive) {
      state = 'connected';
    } else if (isScanning) {
      state = 'searching';
    } else {
      state = 'idle';
    }

    if (state != _lastTileState) {
      _lastTileState = state;
      QuickTileHelper.updateTileState(state);
    }
  }

  @override
  Widget build(BuildContext context) {
    _syncTileState(context.ref);
    return widget.child;
  }
}
