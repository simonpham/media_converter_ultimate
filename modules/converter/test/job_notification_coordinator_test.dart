import 'dart:async';

import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final parameters = JobNotificationServiceStartParams(
    notificationTitle: 'Conversion',
    notificationText: 'Processing files',
    iconBackgroundColor: ThemeData.light().colorScheme.primary,
  );

  test(
    'duplicate background updates do not restart a running service',
    () async {
      final service = _Notifications();
      final coordinator = JobNotificationCoordinator(service);
      await coordinator.update(shouldRun: true, parameters: parameters);
      await coordinator.update(shouldRun: true, parameters: parameters);
      expect(service.events, ['start']);
      await coordinator.update(shouldRun: false);
      expect(service.events, ['start', 'stop']);
      expect(service.running, isFalse);
    },
  );

  test('finishing during native startup stops the eventual service', () async {
    final service = _Notifications()..startGate = Completer<void>();
    final coordinator = JobNotificationCoordinator(service);
    final starting = coordinator.update(
      shouldRun: true,
      parameters: parameters,
    );
    await service.startEntered.future;
    final finishing = coordinator.update(shouldRun: false);
    expect(service.events, ['start']);
    service.startGate!.complete();
    await Future.wait([starting, finishing]);
    expect(service.events, ['start', 'stop']);
    expect(service.running, isFalse);
    expect(service.maxActiveRequests, 1);
  });

  test(
    'a stale queued start cannot run after returning to the foreground',
    () async {
      final service = _Notifications()..queryGate = Completer<void>();
      final coordinator = JobNotificationCoordinator(service);
      final background = coordinator.update(
        shouldRun: true,
        parameters: parameters,
      );
      await service.queryEntered.future;
      final foreground = coordinator.update(shouldRun: false);
      service.queryGate!.complete();
      await Future.wait([background, foreground]);
      expect(service.events, isEmpty);
      expect(service.running, isFalse);
    },
  );

  test('new work waits for a pending stop before starting again', () async {
    final service = _Notifications()
      ..running = true
      ..stopGate = Completer<void>();
    final coordinator = JobNotificationCoordinator(service);
    final stopping = coordinator.update(shouldRun: false);
    await service.stopEntered.future;
    final restarting = coordinator.update(
      shouldRun: true,
      parameters: parameters,
    );
    expect(service.events, ['stop']);
    service.stopGate!.complete();
    await Future.wait([stopping, restarting]);
    expect(service.events, ['stop', 'start']);
    expect(service.running, isTrue);
    expect(service.maxActiveRequests, 1);
  });

  test(
    'a failed native request does not poison later cleanup or retry',
    () async {
      final service = _Notifications()..failNextStart = true;
      final coordinator = JobNotificationCoordinator(service);
      await coordinator.update(shouldRun: true, parameters: parameters);
      expect(service.running, isFalse);
      await coordinator.update(shouldRun: true, parameters: parameters);
      expect(service.running, isTrue);
      await coordinator.update(shouldRun: false);
      expect(service.running, isFalse);
      expect(service.events, ['start', 'start', 'stop']);
    },
  );
}

class _Notifications implements JobNotificationService {
  final events = <String>[];
  final queryEntered = Completer<void>();
  final startEntered = Completer<void>();
  final stopEntered = Completer<void>();
  Completer<void>? queryGate;
  Completer<void>? startGate;
  Completer<void>? stopGate;
  bool running = false;
  bool failNextStart = false;
  int activeRequests = 0;
  int maxActiveRequests = 0;

  @override
  Future<bool> isServiceRunning() async {
    if (!queryEntered.isCompleted) queryEntered.complete();
    await queryGate?.future;
    return running;
  }

  void _begin(String event) {
    events.add(event);
    activeRequests++;
    if (activeRequests > maxActiveRequests) maxActiveRequests = activeRequests;
  }

  @override
  Future<void> start(JobNotificationServiceStartParams parameters) async {
    _begin('start');
    if (!startEntered.isCompleted) startEntered.complete();
    try {
      await startGate?.future;
      if (failNextStart) {
        failNextStart = false;
        throw StateError('Native start rejected');
      }
      running = true;
    } finally {
      activeRequests--;
    }
  }

  @override
  Future<void> stop() async {
    _begin('stop');
    if (!stopEntered.isCompleted) stopEntered.complete();
    try {
      await stopGate?.future;
      running = false;
    } finally {
      activeRequests--;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
