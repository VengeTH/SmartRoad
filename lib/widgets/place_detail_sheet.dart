import "dart:io";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:image_picker/image_picker.dart";

import "../core/constants/app_constants.dart";
import "../core/theme/app_theme.dart";
import "../models/place.dart";
import "../models/place_image.dart";
import "../providers/place_comments_provider.dart";
import "../services/supabase_service.dart";

/// * Bottom sheet showing place details with photos + likes + comments.
/// *
/// * Photos are user-submitted and must be approved by an Admin before they appear publicly.
class PlaceDetailSheet extends ConsumerStatefulWidget {
  final Place place;
  final VoidCallback onClose;
  final VoidCallback? onGetDirections;

  const PlaceDetailSheet({
    super.key,
    required this.place,
    required this.onClose,
    this.onGetDirections,
  });

  @override
  ConsumerState<PlaceDetailSheet> createState() => _PlaceDetailSheetState();
}

class _PlaceDetailSheetState extends ConsumerState<PlaceDetailSheet> {
  final _commentController = TextEditingController();
  bool _isSubmittingComment = false;

  bool _isLoadingLikes = true;
  bool _isTogglingLike = false;
  bool _hasLiked = false;
  int _likesCount = 0;

  bool _isLoadingRatings = true;
  bool _isSubmittingRating = false;
  double _avgRating = 0.0;
  int _ratingsCount = 0;
  int? _myRating; // * 1–5

  int _activeImageIndex = 0;
  late Future<List<PlaceImage>> _approvedImagesFuture;

  @override
  void initState() {
    super.initState();
    _approvedImagesFuture = _loadApprovedImages();
    _loadLikes();
    _loadRatings();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<List<PlaceImage>> _loadApprovedImages() async {
    return await SupabaseService().getPlaceImages(
      placeId: widget.place.id,
      status: PlaceImageStatus.approved,
    );
  }

  Future<void> _loadLikes() async {
    setState(() => _isLoadingLikes = true);
    try {
      final service = SupabaseService();
      final count = await service.getPlaceLikesCount(widget.place.id);
      final liked = await service.hasLikedPlace(widget.place.id);
      if (!mounted) return;
      setState(() {
        _likesCount = count;
        _hasLiked = liked;
        _isLoadingLikes = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingLikes = false);
    }
  }

  Future<void> _toggleLike() async {
    if (!SupabaseService().isAuthenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You must be logged in to like places")),
        );
      }
      return;
    }

    setState(() => _isTogglingLike = true);
    try {
      await SupabaseService().togglePlaceLike(widget.place.id);
      await _loadLikes();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
      }
    } finally {
      if (mounted) {
        setState(() => _isTogglingLike = false);
      }
    }
  }

  Future<void> _loadRatings() async {
    setState(() => _isLoadingRatings = true);
    try {
      final service = SupabaseService();
      final summary = await service.getPlaceRatingsSummary(widget.place.id);
      final myRating = await service.getMyPlaceRating(widget.place.id);

      final avg = summary["avgRating"];
      final count = summary["ratingsCount"];

      if (!mounted) return;
      setState(() {
        _avgRating = (avg is num) ? avg.toDouble() : 0.0;
        _ratingsCount = (count is int) ? count : ((count is num) ? count.toInt() : 0);
        _myRating = myRating;
        _isLoadingRatings = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingRatings = false);
    }
  }

  Future<void> _setRating(int rating) async {
    if (!SupabaseService().isAuthenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You must be logged in to rate places")),
        );
      }
      return;
    }

    setState(() => _isSubmittingRating = true);
    try {
      await SupabaseService().setPlaceRating(placeId: widget.place.id, rating: rating);
      await _loadRatings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error rating place: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingRating = false);
      }
    }
  }

  Widget _buildStarRow({
    required double value,
    double size = 16,
    Color color = AppTheme.warningColor,
  }) {
    final full = value.floor().clamp(0, 5);
    final hasHalf = (value - full) >= 0.25 && (value - full) < 0.75;
    final empty = (5 - full - (hasHalf ? 1 : 0)).clamp(0, 5);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < full; i++)
          Icon(Icons.star, size: size, color: color),
        if (hasHalf) Icon(Icons.star_half, size: size, color: color),
        for (int i = 0; i < empty; i++)
          Icon(Icons.star_border, size: size, color: AppTheme.borderColor),
      ],
    );
  }

  Widget _buildRatingSection({required bool isAuthenticated}) {
    final displayAvg = _ratingsCount > 0 ? _avgRating.clamp(0.0, 5.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.borderColor.withOpacity(0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.star_outline,
                size: 18,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                "Rating",
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              if (_isLoadingRatings)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else ...[
                _buildStarRow(value: displayAvg, size: 16),
                const SizedBox(width: 8),
                Text(
                  _ratingsCount > 0 ? displayAvg.toStringAsFixed(1) : "—",
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  "($_ratingsCount)",
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (int i = 1; i <= 5; i++)
                InkWell(
                  onTap: (!isAuthenticated || _isSubmittingRating)
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          _setRating(i);
                        },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                    child: Icon(
                      (_myRating ?? 0) >= i ? Icons.star : Icons.star_border,
                      color: (_myRating ?? 0) >= i
                          ? AppTheme.warningColor
                          : AppTheme.borderColor,
                      size: 22,
                    ),
                  ),
                ),
              const Spacer(),
              if (!isAuthenticated)
                const Text(
                  "Log in to rate",
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else if (_isSubmittingRating)
                const Text(
                  "Saving...",
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else if (_myRating != null)
                Text(
                  "Your rating: $_myRating/5",
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                const Text(
                  "Tap to rate",
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

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

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    if (!SupabaseService().isAuthenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You must be logged in to comment")),
        );
      }
      return;
    }

    setState(() => _isSubmittingComment = true);
    try {
      await ref
          .read(placeCommentsProvider(widget.place.id).notifier)
          .addComment(text);
      _commentController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error posting comment: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingComment = false);
      }
    }
  }

  String _sanitizeStorageSegment(String raw) {
    final buffer = StringBuffer();
    for (final codeUnit in raw.codeUnits) {
      final ch = String.fromCharCode(codeUnit);
      final isAllowed = RegExp(r"[a-zA-Z0-9_-]").hasMatch(ch);
      buffer.write(isAllowed ? ch : "_");
    }
    final sanitized = buffer.toString();
    return sanitized.isEmpty ? "place" : sanitized;
  }

  Future<void> _addPhoto() async {
    final service = SupabaseService();
    if (!service.isAuthenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You must be logged in to add photos")),
        );
      }
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );

    if (picked == null) return;

    try {
      final placeSegment = _sanitizeStorageSegment(widget.place.id);
      final userId = service.currentUserId ?? "user";
      final fileName =
          "places/$placeSegment/${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg";

      String url;

      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        if (bytes.length > AppConstants.maxImageSizeBytes) {
          throw Exception(
            "Image too large (max ${AppConstants.maxImageSizeBytes ~/ (1024 * 1024)}MB)",
          );
        }
        url = await service.uploadImageBytes(bytes, fileName);
      } else {
        final file = File(picked.path);
        final bytes = await file.readAsBytes();
        if (bytes.length > AppConstants.maxImageSizeBytes) {
          throw Exception(
            "Image too large (max ${AppConstants.maxImageSizeBytes ~/ (1024 * 1024)}MB)",
          );
        }
        url = await service.uploadImage(file, fileName);
      }

      await service.createPlaceImage(placeId: widget.place.id, imageUrl: url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Photo submitted for review. It will appear once approved.",
            ),
            backgroundColor: AppTheme.successColor,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error uploading photo: ${e.toString()}"),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(placeCommentsProvider(widget.place.id));
    final isAuthenticated = SupabaseService().isAuthenticated;

    return AnimatedPadding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      duration: AppTheme.animationFast,
      curve: AppTheme.animationCurve,
      child: DraggableScrollableSheet(
        // * Keep the preview compact by default so the map remains usable.
        initialChildSize: 0.38,
        minChildSize: 0.22,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) {
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: AppTheme.maxContentWidth(context),
              ),
              child: Material(
                color: AppTheme.surfaceColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                clipBehavior: Clip.antiAlias,
                elevation: 8,
                child: Column(
                  children: [
                    // * Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.borderColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // * Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.place.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: widget.onClose,
                                ),
                              ],
                            ),
                            if (widget.place.category != null) ...[
                              const SizedBox(height: 6),
                              Chip(
                                label: Text(
                                  widget.place.category!.toUpperCase(),
                                ),
                                backgroundColor: AppTheme.primaryColor
                                    .withOpacity(0.12),
                              ),
                            ],
                            const SizedBox(height: 12),

                            if (widget.onGetDirections != null) ...[
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    HapticFeedback.mediumImpact();
                                    widget.onGetDirections?.call();
                                  },
                                  icon: const Icon(Icons.directions),
                                  label: const Text(
                                    "Get Directions",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: AppTheme.spacingMD,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusMD,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],

                            // * Photos
                            FutureBuilder<List<PlaceImage>>(
                              future: _approvedImagesFuture,
                              builder: (context, snapshot) {
                                final images = snapshot.data ?? [];
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const SizedBox(
                                    height: 180,
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }

                                if (images.isEmpty) {
                                  return Container(
                                    height: 180,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceVariant,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppTheme.borderColor.withOpacity(
                                          0.4,
                                        ),
                                      ),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.photo_library_outlined,
                                            size: 42,
                                            color: AppTheme.textSecondary
                                                .withOpacity(0.7),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            "No approved photos yet",
                                            style: TextStyle(
                                              color: AppTheme.textSecondary
                                                  .withOpacity(0.9),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "Be the first to add one (reviewed before posting)",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textTertiary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                return Column(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: SizedBox(
                                        height: 220,
                                        width: double.infinity,
                                        child: PageView.builder(
                                          itemCount: images.length,
                                          onPageChanged: (index) {
                                            setState(
                                              () => _activeImageIndex = index,
                                            );
                                          },
                                          itemBuilder: (context, index) {
                                            final image = images[index];
                                            return Image.network(
                                              image.imageUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (
                                                context,
                                                error,
                                                stackTrace,
                                              ) {
                                                return const Center(
                                                  child: Icon(
                                                    Icons.broken_image,
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: List.generate(images.length, (
                                        index,
                                      ) {
                                        final active =
                                            index == _activeImageIndex;
                                        return AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          width: active ? 18 : 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color:
                                                active
                                                    ? AppTheme.primaryColor
                                                    : AppTheme.borderColor,
                                            borderRadius: BorderRadius.circular(
                                              99,
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                  ],
                                );
                              },
                            ),

                            const SizedBox(height: 12),

                            // * Rating
                            _buildRatingSection(isAuthenticated: isAuthenticated),
                            const SizedBox(height: 12),

                            // * Likes + Add Photo
                            Row(
                              children: [
                                IconButton(
                                  onPressed:
                                      _isTogglingLike ? null : _toggleLike,
                                  icon: Icon(
                                    _hasLiked
                                        ? Icons.thumb_up
                                        : Icons.thumb_up_outlined,
                                    color:
                                        _hasLiked
                                            ? AppTheme.primaryColor
                                            : AppTheme.textSecondary,
                                  ),
                                  tooltip: _hasLiked ? "Unlike" : "Like",
                                ),
                                if (_isLoadingLikes)
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                else
                                  Text(
                                    "$_likesCount",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _addPhoto,
                                    icon: const Icon(Icons.add_a_photo),
                                    label: const Text("Add Photo"),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.warningColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMD,
                                ),
                                border: Border.all(
                                  color: AppTheme.warningColor.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.gpp_good,
                                    color: AppTheme.warningColor,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      "Photos are reviewed before posting. No nudity, no unrelated content, and only accurate place photos.",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // * Comments
                            const SizedBox(height: 18),
                            const Divider(),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(
                                  Icons.comment_outlined,
                                  size: 20,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Comments",
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                commentsAsync.when(
                                  data:
                                      (comments) => Text(
                                        "(${comments.length})",
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 14,
                                        ),
                                      ),
                                  loading: () => const SizedBox.shrink(),
                                  error: (_, __) => const SizedBox.shrink(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            commentsAsync.when(
                              data: (comments) {
                                if (comments.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 20,
                                    ),
                                    child: Center(
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.comment_outlined,
                                            size: 40,
                                            color: AppTheme.textSecondary
                                                .withOpacity(0.5),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            "No comments yet",
                                            style: TextStyle(
                                              color: AppTheme.textSecondary
                                                  .withOpacity(0.7),
                                              fontSize: 14,
                                            ),
                                          ),
                                          if (!isAuthenticated) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              "Sign in to add a comment",
                                              style: TextStyle(
                                                color: AppTheme.textTertiary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                return Column(
                                  children:
                                      comments.map((comment) {
                                        return Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: AppTheme.surfaceVariant,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 14,
                                                    backgroundColor: AppTheme
                                                        .primaryColor
                                                        .withOpacity(0.2),
                                                    backgroundImage:
                                                        comment.userPhotoUrl !=
                                                                null
                                                            ? NetworkImage(
                                                              comment
                                                                  .userPhotoUrl!,
                                                            )
                                                            : null,
                                                    child:
                                                        comment.userPhotoUrl ==
                                                                null
                                                            ? const Icon(
                                                              Icons.person,
                                                              size: 16,
                                                            )
                                                            : null,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      comment.userName ??
                                                          "Anonymous",
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                  Text(
                                                    _formatTimeAgo(
                                                      comment.createdAt,
                                                    ),
                                                    style: const TextStyle(
                                                      color:
                                                          AppTheme.textTertiary,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(comment.text),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                );
                              },
                              loading:
                                  () => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                              error:
                                  (error, _) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    child: Text(
                                      "Failed to load comments: ${error.toString()}",
                                      style: const TextStyle(
                                        color: AppTheme.errorColor,
                                      ),
                                    ),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // * Comment input
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        border: Border(
                          top: BorderSide(
                            color: AppTheme.borderColor.withOpacity(0.5),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              enabled: isAuthenticated && !_isSubmittingComment,
                              decoration: InputDecoration(
                                hintText:
                                    isAuthenticated
                                        ? "Add a comment..."
                                        : "Log in to comment",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: AppTheme.borderColor,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: AppTheme.borderColor,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _submitComment(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed:
                                _isSubmittingComment ? null : _submitComment,
                            icon:
                                _isSubmittingComment
                                    ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Icon(Icons.send),
                            color: AppTheme.primaryColor,
                            tooltip: "Send",
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
