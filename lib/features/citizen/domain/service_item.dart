import 'package:flutter/material.dart';

class ServiceItem {
  const ServiceItem({
    required this.name,
    required this.description,
    required this.icon,
    required this.available,
    required this.route,
  });

  final String name;
  final String description;
  final IconData icon;
  final bool available;

  /// Where tapping this tile navigates -- carried on the item itself
  /// rather than matched by [name] in the presentation layer, so adding or
  /// renaming a service can't silently fall through to "Coming Soon".
  final String route;
}
