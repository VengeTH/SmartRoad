import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../providers/hazards_provider.dart";
import "../../models/hazard.dart";
import "../../widgets/hazard_marker.dart";
import "../map/map_screen.dart";
import "../../widgets/hazard_detail_sheet.dart";

/// * Feed screen showing list of hazards
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});
  
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return "${difference.inDays}d ago";
    } else if (difference.inHours > 0) {
      return "${difference.inHours}h ago";
    } else if (difference.inMinutes > 0) {
      return "${difference.inMinutes}m ago";
    } else {
      return "Just now";
    }
  }
  
  void _showHazardDetail(BuildContext context, Hazard hazard) {
    showModalBottomSheet(
      context: context,
      builder: (context) => HazardDetailSheet(
        hazard: hazard,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }
  
  void _navigateToMapWithHazard(BuildContext context, Hazard hazard) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const MapScreen(),
      ),
    );
    // * Show detail sheet after navigation
    Future.delayed(const Duration(milliseconds: 500), () {
      _showHazardDetail(context, hazard);
    });
  }
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hazardsAsync = ref.watch(hazardsProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hazards Feed"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(hazardsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: hazardsAsync.when(
        data: (hazards) {
          if (hazards.isEmpty) {
            return const Center(
              child: Text("No hazards reported yet"),
            );
          }
          
          return RefreshIndicator(
            onRefresh: () => ref.read(hazardsProvider.notifier).refresh(),
            child: ListView.builder(
              itemCount: hazards.length,
              itemBuilder: (context, index) {
                final hazard = hazards[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    leading: SizedBox(
                      width: 50,
                      height: 50,
                      child: HazardMarker(hazard: hazard),
                    ),
                    title: Text(
                      hazard.type.value.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          hazard.description.length > 100
                              ? "${hazard.description.substring(0, 100)}..."
                              : hazard.description,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Chip(
                              label: Text(hazard.severity.value),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatTimeAgo(hazard.createdAt),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: hazard.imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              hazard.imageUrl!,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const SizedBox(
                                  width: 60,
                                  height: 60,
                                  child: Icon(Icons.broken_image),
                                );
                              },
                            ),
                          )
                        : null,
                    onTap: () => _navigateToMapWithHazard(context, hazard),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text("Error loading hazards: $error"),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(hazardsProvider.notifier).refresh(),
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

