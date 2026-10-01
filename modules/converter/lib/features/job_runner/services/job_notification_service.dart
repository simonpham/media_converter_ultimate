import 'package:core/utils/utils.dart';
import 'package:flutter/widgets.dart';
import 'package:platform_utils/platform_utils.dart';

const kJobNotificationServiceId = 999;
const kJobNotificationChannelId = 'media_converter_ultimate';

class JobNotificationServiceInitParams {
  final String channelName;
  final String channelDescription;

  const JobNotificationServiceInitParams({
    required this.channelName,
    required this.channelDescription,
  });
}

class JobNotificationServiceStartParams {
  final String notificationTitle;
  final String notificationText;
  final Color iconBackgroundColor;

  const JobNotificationServiceStartParams({
    required this.notificationTitle,
    required this.notificationText,
    required this.iconBackgroundColor,
  });
}

abstract class JobNotificationService {
  const JobNotificationService();

  Future<bool> isServiceRunning();
  Future<bool> isNotificationPermissionGranted();

  Future<void> init(JobNotificationServiceInitParams params);
  Future<void> requestPermission();
  Future<void> start(JobNotificationServiceStartParams params);
  Future<void> stop();
}

class JobNotificationServiceImpl implements JobNotificationService {
  bool _initialized = false;

  @override
  Future<bool> isNotificationPermissionGranted() async {
    final status = await FlutterForegroundTask.checkNotificationPermission();
    return status == NotificationPermission.granted;
  }

  @override
  Future<bool> isServiceRunning() {
    if (!_initialized) {
      return Future.value(false);
    }
    return FlutterForegroundTask.isRunningService;
  }

  JobNotificationServiceImpl();

  @override
  Future<void> requestPermission() async {
    // Android 13+, you need to allow notification permission to display foreground service notification.
    //
    // iOS: If you need notification, ask for permission.
    final notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (Platform.isAndroid) {
      // Android 12+, there are restrictions on starting a foreground service.
      //
      // To restart the service on device reboot or unexpected problem, you need to allow below permission.
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        // This function requires `android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` permission.
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    }
  }

  @override
  Future<void> init(JobNotificationServiceInitParams params) async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: kJobNotificationChannelId,
        channelName: params.channelName,
        channelDescription: params.channelDescription,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
    _initialized = true;
  }

  @override
  Future<void> start(JobNotificationServiceStartParams params) async {
    if (!_initialized) {
      return;
    }

    if (await isServiceRunning()) {
      return;
    }
    final result = await FlutterForegroundTask.startService(
      serviceId: kJobNotificationServiceId,
      notificationTitle: params.notificationTitle,
      notificationText: params.notificationText,
      notificationIcon: NotificationIcon(
        metaDataName: 'io.sofluffy.mcu.NOTIFICATION_ICON',
        backgroundColor: params.iconBackgroundColor,
      ),
      serviceTypes: [
        ForegroundServiceTypes.mediaProcessing,
      ],
    );
    if (result case ServiceRequestFailure(:final error)) throw error;
  }

  @override
  Future<void> stop() async {
    if (!_initialized) {
      return;
    }

    if (!await isServiceRunning()) {
      return;
    }
    final result = await FlutterForegroundTask.stopService();
    if (result case ServiceRequestFailure(:final error)) throw error;
  }
}

// The callback function should always be a top-level or static function.
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(JobNotificationServiceHandler());
}

class JobNotificationServiceHandler extends TaskHandler {
  // Called when the task is started.
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    printLog('[JobNotificationServiceHandler]: onStart ${starter.name}');
  }

  // Called based on the eventAction set in ForegroundTaskOptions.
  @override
  void onRepeatEvent(DateTime timestamp) {
    // Send data to main isolate.
    final Map<String, dynamic> data = {
      'timestampMillis': timestamp.millisecondsSinceEpoch,
    };
    FlutterForegroundTask.sendDataToMain(data);
  }

  // Called when the task is destroyed.
  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    printLog(
      '[JobNotificationServiceHandler]: onDestroy isTimeout: $isTimeout',
    );
  }

  // Called when data is sent using `FlutterForegroundTask.sendDataToTask`.
  @override
  void onReceiveData(Object data) {
    printLog('[JobNotificationServiceHandler]: onReceiveData: $data');
  }

  // Called when the notification button is pressed.
  @override
  void onNotificationButtonPressed(String id) {
    printLog(
      '[JobNotificationServiceHandler]: onNotificationButtonPressed: $id',
    );
  }

  // Called when the notification itself is pressed.
  @override
  void onNotificationPressed() {
    printLog('[JobNotificationServiceHandler]: onNotificationPressed');
  }

  // Called when the notification itself is dismissed.
  @override
  void onNotificationDismissed() {
    printLog('[JobNotificationServiceHandler]: onNotificationDismissed');
  }
}
