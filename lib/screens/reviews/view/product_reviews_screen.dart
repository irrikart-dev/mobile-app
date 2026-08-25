import 'package:flutter/material.dart';
import 'package:irrikart/components/coming_soon_view.dart';

class ProductReviewsScreen extends StatelessWidget {
  const ProductReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      appBarTitle: 'Reviews',
      icon: Icons.star_outline,
      title: 'Ratings & reviews',
      message:
          'Reviews from verified buyers, written after delivery, will show up '
          'here.',
    );
  }
}
