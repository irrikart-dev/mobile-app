import 'package:flutter/material.dart';
import 'package:irrikart/components/coming_soon_view.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      appBarTitle: 'Search',
      icon: Icons.search,
      title: 'Search the catalogue',
      message:
          'Keyword search with filters for category, brand, price, pack size '
          'and availability is being built.',
    );
  }
}
