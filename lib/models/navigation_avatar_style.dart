import "package:flutter/material.dart";

/// * User-selectable navigation avatar (Waze-style).
enum NavigationAvatarStyle {
  arrow,
  car,
  motorcycle,
  bigBike,
  truck,
  pedestrian,
}

extension NavigationAvatarStyleX on NavigationAvatarStyle {
  String get id {
    return switch (this) {
      NavigationAvatarStyle.arrow => "arrow",
      NavigationAvatarStyle.car => "car",
      NavigationAvatarStyle.motorcycle => "motorcycle",
      NavigationAvatarStyle.bigBike => "big_bike",
      NavigationAvatarStyle.truck => "truck",
      NavigationAvatarStyle.pedestrian => "pedestrian",
    };
  }

  String get label {
    return switch (this) {
      NavigationAvatarStyle.arrow => "Arrow",
      NavigationAvatarStyle.car => "Car",
      NavigationAvatarStyle.motorcycle => "Motorcycle",
      NavigationAvatarStyle.bigBike => "Big Bike",
      NavigationAvatarStyle.truck => "Truck",
      NavigationAvatarStyle.pedestrian => "Pedestrian",
    };
  }

  IconData get icon {
    return switch (this) {
      NavigationAvatarStyle.arrow => Icons.navigation,
      NavigationAvatarStyle.car => Icons.directions_car,
      NavigationAvatarStyle.motorcycle => Icons.two_wheeler,
      NavigationAvatarStyle.bigBike => Icons.motorcycle,
      NavigationAvatarStyle.truck => Icons.local_shipping,
      NavigationAvatarStyle.pedestrian => Icons.directions_walk,
    };
  }

  static NavigationAvatarStyle fromId(String? raw) {
    final id = raw?.trim().toLowerCase();
    return switch (id) {
      "car" => NavigationAvatarStyle.car,
      "motorcycle" => NavigationAvatarStyle.motorcycle,
      "big_bike" => NavigationAvatarStyle.bigBike,
      "truck" => NavigationAvatarStyle.truck,
      "pedestrian" => NavigationAvatarStyle.pedestrian,
      "arrow" || null || "" => NavigationAvatarStyle.arrow,
      _ => NavigationAvatarStyle.arrow,
    };
  }
}

