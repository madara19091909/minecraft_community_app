import 'package:flutter/material.dart';

import '../../../core/widgets/empty_view.dart';

/// Empty state used by tabs whose feature ships in a later phase.
class PlaceholderTab extends StatelessWidget {
  const PlaceholderTab({super.key, required this.title, required this.icon, required this.message});
  final String title;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: EmptyView(icon: icon, title: title, subtitle: message),
      );
}
