import 'package:flutter/services.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

final _logger = Logger('QuickTileHelper');
const _methodChannel = MethodChannel('org.localsend.localsend_app/localsend');

typedef QuickBeamLaunchCallback = void Function();

class QuickTileHelper {
  static QuickBeamLaunchCallback? _onLaunchCallback;

  static void init({QuickBeamLaunchCallback? onLaunch}) {
    if (checkPlatformIsNot([TargetPlatform.android])) return;
    _onLaunchCallback = onLaunch;

    _methodChannel.setMethodCallHandler((call) async {
      if (call.method == 'onQuickBeamLaunched') {
        _logger.info('Quick Beam launched from Quick Tile (onNewIntent)');
        _onLaunchCallback?.call();
      }
    });
  }

  static Future<void> updateTileState(String state) async {
    if (checkPlatformIsNot([TargetPlatform.android])) return;
    try {
      await _methodChannel.invokeMethod('updateQuickTileState', {
        'state': state,
      });
    } catch (e) {
      _logger.warning('Failed to update Quick Tile state: $e');
    }
  }

  static Future<bool> checkLaunchFromTile() async {
    if (checkPlatformIsNot([TargetPlatform.android])) return false;
    try {
      final bool? launched = await _methodChannel.invokeMethod<bool>('checkLaunchFromTile');
      return launched ?? false;
    } catch (e) {
      _logger.warning('Failed to check Quick Tile launch intent: $e');
      return false;
    }
  }
}
