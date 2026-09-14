import 'package:flutter/material.dart';
import 'estimate_list_view.dart';

// Kept for compatibility with your existing Admin dashboard import.
class EstimatedOrdersScreen extends StatelessWidget {
  const EstimatedOrdersScreen({super.key});
  @override
  Widget build(BuildContext context) => const EstimateListView(adminView: true);
}
