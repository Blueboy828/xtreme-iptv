import 'package:flutter/material.dart';

import '../../domain/entities/live_entities.dart';

/// A modal drawer or side panel listing all Live TV categories.
///
/// Tapping a category triggers channel loading for that category.
class CategoryDrawer extends StatelessWidget {
  final List<LiveCategory> categories;
  final String? selectedCategoryId;
  final ValueChanged<String> onCategorySelected;

  const CategoryDrawer({
    super.key,
    required this.categories,
    this.selectedCategoryId,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      backgroundColor: theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Categories',
                style: theme.textTheme.titleLarge,
              ),
            ),
            const Divider(height: 1),
            // "All" option
            ListTile(
              leading: const Icon(Icons.grid_view),
              title: const Text('All Channels'),
              selected: selectedCategoryId == null ||
                  selectedCategoryId == '__all__',
              selectedColor: theme.colorScheme.primary,
              onTap: () {
                onCategorySelected('__all__');
                Navigator.of(context).pop();
              },
            ),
            // Category list
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final isSelected = cat.categoryId == selectedCategoryId;

                  return ListTile(
                    leading: Icon(
                      Icons.folder,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    title: Text(
                      cat.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    selected: isSelected,
                    selectedColor: theme.colorScheme.primary,
                    onTap: () {
                      onCategorySelected(cat.categoryId);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
