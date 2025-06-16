import 'package:core/core.dart';
import 'package:flutter/material.dart';

extension BuildContextContext on BuildContext {
  GoRouter get router {
    return GoRouter.of(this);
  }
}
