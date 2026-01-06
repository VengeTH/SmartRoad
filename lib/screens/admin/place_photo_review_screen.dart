import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/theme/app_theme.dart";
import "../../models/place.dart";
import "../../models/place_image.dart";
import "../../models/user_profile.dart";
import "../../providers/auth_provider.dart";
import "../../services/known_places_service.dart";
import "../../services/supabase_service.dart";

/// * Admin-only screen for reviewing pending place photos.
class PlacePhotoReviewScreen extends ConsumerStatefulWidget {
  const PlacePhotoReviewScreen({super.key});

  @override
  ConsumerState<PlacePhotoReviewScreen> createState() => _PlacePhotoReviewScreenState();
}

class _PlacePhotoReviewScreenState extends ConsumerState<PlacePhotoReviewScreen> {
  late Future<List<PlaceImage>> _pendingFuture;
  Map<String, Place> _placesById = {};

  @override
  void initState() {
    super.initState();
    _pendingFuture = _loadPending();
    _loadKnownPlaces();
  }

  Future<void> _loadKnownPlaces() async {
    final places = await KnownPlacesService().getKnownPlaces();
    if (!mounted) return;
    setState(() {
      _placesById = {for (final p in places) p.id: p};
    });
  }

  Future<List<PlaceImage>> _loadPending() async {
    return await SupabaseService().getPendingPlaceImages();
  }

  void _refresh() {
    setState(() {
      _pendingFuture = _loadPending();
    });
  }

  Future<void> _approve(PlaceImage image) async {
    try {
      await SupabaseService().approvePlaceImage(image.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Approved"),
            backgroundColor: AppTheme.successColor,
            duration: Duration(seconds: 2),
          ),
        );
      }
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _reject(PlaceImage image) async {
    final reason = await _askRejectReason();
    if (reason == null) return; // * Cancelled

    try {
      await SupabaseService().rejectPlaceImage(image.id, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Rejected"),
            backgroundColor: AppTheme.warningColor,
            duration: Duration(seconds: 2),
          ),
        );
      }
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<String?> _askRejectReason() async {
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Reject Photo"),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: "Optional reason (e.g., unrelated photo, nudity, low quality)",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text("Reject"),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final service = SupabaseService();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Photo Review"),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh",
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          if (service.isDemoMode) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppTheme.spacingXL),
                child: Text("Photo review is not available in demo mode."),
              ),
            );
          }

          if (profile == null || profile.reporterLevel != ReporterLevel.admin) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppTheme.spacingXL),
                child: Text("Not authorized. Admin access required."),
              ),
            );
          }

          return FutureBuilder<List<PlaceImage>>(
            future: _pendingFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingXL),
                    child: Text("Failed to load pending photos: ${snapshot.error}"),
                  ),
                );
              }

              final pending = snapshot.data ?? [];
              if (pending.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppTheme.spacingXL),
                    child: Text("No pending photos"),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                itemCount: pending.length,
                itemBuilder: (context, index) {
                  final image = pending[index];
                  final placeName = _placesById[image.placeId]?.name ?? image.placeId;

                  return Card(
                    margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingMD),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            placeName,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Submitted by: ${image.userName ?? image.userId}",
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Image.network(
                                image.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, _) =>
                                    const Center(child: Icon(Icons.broken_image)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _approve(image),
                                  icon: const Icon(Icons.check),
                                  label: const Text("Approve"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.successColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _reject(image),
                                  icon: const Icon(Icons.close),
                                  label: const Text("Reject"),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.errorColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spacingXL),
            child: Text("Failed to load profile"),
          ),
        ),
      ),
    );
  }
}

