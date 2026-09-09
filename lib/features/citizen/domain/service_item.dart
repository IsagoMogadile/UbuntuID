import 'package:flutter/material.dart';

class ServiceItem {
  const ServiceItem({
    required this.name,
    required this.description,
    required this.icon,
    required this.available,
  });

  final String name;
  final String description;
  final IconData icon;
  final bool available;
}
