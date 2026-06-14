import 'package:flutter/material.dart';

enum DeviceType { smallPhone, mediumPhone, largePhone, tablet, largeTablet }

class Responsive {
  final BuildContext context;
  final double screenWidth, screenHeight, pixelRatio, textScaleFactor;
  final DeviceType deviceType;
  final Orientation orientation;

  Responsive._({
    required this.context,
    required this.screenWidth,
    required this.screenHeight,
    required this.pixelRatio,
    required this.textScaleFactor,
    required this.deviceType,
    required this.orientation,
  });

  factory Responsive.of(BuildContext context) {
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final type = w < 360
        ? DeviceType.smallPhone
        : w < 420
            ? DeviceType.mediumPhone
            : w < 600
                ? DeviceType.largePhone
                : w < 1024
                    ? DeviceType.tablet
                    : DeviceType.largeTablet;
    return Responsive._(
      context: context,
      screenWidth: w,
      screenHeight: mq.size.height,
      pixelRatio: mq.devicePixelRatio,
      textScaleFactor: mq.textScaleFactor,
      deviceType: type,
      orientation: mq.orientation,
    );
  }

  double wp(double p) => screenWidth * p / 100;
  double hp(double p) => screenHeight * p / 100;

  double sp(double fs) {
    const factors = {
      DeviceType.smallPhone: 0.85,
      DeviceType.mediumPhone: 1.0,
      DeviceType.largePhone: 1.1,
      DeviceType.tablet: 1.2,
      DeviceType.largeTablet: 1.3,
    };
    return fs * (factors[deviceType] ?? 1.0) * textScaleFactor;
  }

  double scale(double v) {
    const factors = {
      DeviceType.smallPhone: 0.80,
      DeviceType.mediumPhone: 1.0,
      DeviceType.largePhone: 1.15,
      DeviceType.tablet: 1.35,
      DeviceType.largeTablet: 1.50,
    };
    return v * (factors[deviceType] ?? 1.0);
  }

  bool get isPhone => deviceType.index <= DeviceType.largePhone.index;
  bool get isTablet => deviceType == DeviceType.tablet;
  bool get isLargeTablet => deviceType == DeviceType.largeTablet;
  bool get isLandscape => orientation == Orientation.landscape;

  double get buttonHeight => scale(48);
  double get cardRadius => scale(16);

  EdgeInsets all(double v) => EdgeInsets.all(scale(v));
  EdgeInsets symmetric({double h = 16, double v = 16}) =>
      EdgeInsets.symmetric(horizontal: scale(h), vertical: scale(v));
}

extension ResponsiveContext on BuildContext {
  Responsive get r => Responsive.of(this);
}
