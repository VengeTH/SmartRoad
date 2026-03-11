import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_map/flutter_map.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:latlong2/latlong.dart";

import "../../core/theme/app_theme.dart";
import "../../models/commute_guide_data.dart";
import "../../models/commute_state.dart";
import "../../providers/commute_provider.dart";
import "../../providers/location_provider.dart";
import "../../services/app_preferences_service.dart";
import "../../services/location_search_service.dart";
import "../../services/planner_local.dart";
import "../../widgets/commute/countdown_ring_widget.dart";
import "../../widgets/commute/commute_empty_state.dart";
import "../../widgets/commute/lagpas_alert_overlay.dart";
import "../../widgets/commute/safety_alert_overlay.dart";
import "../../widgets/commute/safety_settings_sheet.dart";
import "../../widgets/commute/arrival_celebration.dart";

/// * Commute Mode Screen
/// * A simple, beautiful UI for commuters with destination alarm
class CommuteModeScreen extends ConsumerStatefulWidget {
  const CommuteModeScreen({super.key});

  @override
  ConsumerState<CommuteModeScreen> createState() => _CommuteModeScreenState();
}

class _CommuteModeScreenState extends ConsumerState<CommuteModeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _destinationFocusNode = FocusNode();
  final AppPreferencesService _preferences = AppPreferencesService();
  final LocationSearchService _locationSearchService = LocationSearchService();
  
  // * Persisted recent commute destinations.
  final List<Map<String, dynamic>> _recentDestinations = [];
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  bool _showLagpasAlert = false;
  bool _showSafetyAlert = false;
  bool _showArrivalCelebration = false;
  bool _isInlineSearching = false;
  String _detectedCountryCode = "ph";
  Timer? _searchDebounce;
  final List<LocationSearchResult> _inlineSearchResults = [];

  /// * Expandable "Commute guide" card in active view (collapsed by default for scroll-free layout).
  bool _commuteGuideExpanded = false;

  /// * Prefilled destination from "Commute to this location" (route arguments).
  String? _prefilledDestinationName;
  double? _prefilledLat;
  double? _prefilledLon;
  bool _hasReadRouteArgs = false;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    unawaited(_loadRecentDestinations());
    unawaited(_detectSearchCountryCode());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _destinationController.dispose();
    _destinationFocusNode.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  /// * Read route arguments once (destinationName, lat, lon) for "Commute to this location".
  void _readRouteArguments() {
    if (_hasReadRouteArgs || !mounted) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map<String, dynamic>) return;
    final name = args["destinationName"]?.toString().trim();
    final latRaw = args["lat"];
    final lonRaw = args["lon"];
    final lat = latRaw is num ? latRaw.toDouble() : double.tryParse(latRaw?.toString() ?? "");
    final lon = lonRaw is num ? lonRaw.toDouble() : double.tryParse(lonRaw?.toString() ?? "");
    if (name != null && name.isNotEmpty && lat != null && lon != null &&
        !lat.isNaN && !lon.isNaN) {
      _hasReadRouteArgs = true;
      setState(() {
        _prefilledDestinationName = name;
        _prefilledLat = lat;
        _prefilledLon = lon;
      });
    }
  }

  Future<void> _loadRecentDestinations() async {
    final items = await _preferences.loadRecentCommuteDestinations();
    if (!mounted) return;
    setState(() {
      _recentDestinations
        ..clear()
        ..addAll(items);
    });
  }

  Future<void> _rememberRecentDestination({
    required String name,
    required double lat,
    required double lng,
  }) async {
    final updated = await _preferences.addRecentCommuteDestination(
      name: name,
      latitude: lat,
      longitude: lng,
    );
    if (!mounted) return;
    setState(() {
      _recentDestinations
        ..clear()
        ..addAll(updated);
    });
  }

  Future<void> _detectSearchCountryCode() async {
    if (_detectedCountryCode.isNotEmpty && _detectedCountryCode != "ph") {
      return;
    }
    try {
      final position = await ref
          .read(currentLocationProvider.future)
          .timeout(const Duration(seconds: 2));
      if (position == null) return;
      final countryCode = await _locationSearchService
          .getCountryCodeFromCoordinates(position.latitude, position.longitude)
          .timeout(const Duration(seconds: 2));
      if (!mounted || countryCode == null || countryCode.isEmpty) return;
      setState(() {
        _detectedCountryCode = countryCode;
      });
    } catch (_) {
      // * Keep search usable even if country detection fails.
    }
  }

  void _onDestinationTextChanged(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();

    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isInlineSearching = false;
        _inlineSearchResults.clear();
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      unawaited(_runInlineSearch(query));
    });
  }

  Future<void> _runInlineSearch(String query) async {
    if (!mounted) return;
    setState(() {
      _isInlineSearching = true;
    });

    await _detectSearchCountryCode();

    final results = await _locationSearchService.searchLocationRespectCountry(
      query,
      preferredCountryCode: _detectedCountryCode,
      allowOutsideWhenNoLocal: false,
    );

    if (!mounted || _destinationController.text.trim() != query.trim()) return;
    setState(() {
      _isInlineSearching = false;
      _inlineSearchResults
        ..clear()
        ..addAll(results.take(4));
    });
  }

  @override
  Widget build(BuildContext context) {
    _readRouteArguments();
    final commuteState = ref.watch(commuteProvider);

    // * Show lagpas alert overlay when user passes destination
    if (commuteState.status == CommuteStatus.passed && !_showLagpasAlert) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _showLagpasAlert = true);
      });
    }
    
    // * Show safety alert overlay when off-route detected
    if (commuteState.status == CommuteStatus.danger && !_showSafetyAlert) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _showSafetyAlert = true);
      });
    }
    
    // * Show arrival celebration
    if (commuteState.status == CommuteStatus.arrived && !_showArrivalCelebration) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _showArrivalCelebration = true);
      });
    }
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: "Back",
        ),
      ),
      body: Stack(
        children: [
          // * Main content
          SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: commuteState.isActive
                  ? _buildActiveCommuteView(commuteState)
                  : _buildIdleView(commuteState),
            ),
          ),
          
          // * Lagpas alert overlay
          if (_showLagpasAlert)
            LagpasAlertOverlay(
              destinationName: commuteState.destinationName ?? "your stop",
              onDismiss: () {
                setState(() => _showLagpasAlert = false);
                ref.read(commuteProvider.notifier).dismissAlarm();
                ref.read(commuteProvider.notifier).stopCommute();
              },
            ),
          
          // * Safety alert overlay
          if (_showSafetyAlert)
            SafetyAlertOverlay(
              destinationName: commuteState.destinationName ?? "Unknown",
              offRouteDistance: commuteState.offRouteDistanceKm ?? 0.0,
              onImSafe: () {
                setState(() => _showSafetyAlert = false);
                ref.read(commuteProvider.notifier).dismissSafetyAlert();
              },
              onSendAlert: () {
                setState(() => _showSafetyAlert = false);
                ref.read(commuteProvider.notifier).sendSafetyAlert();
              },
            ),
          
          // * Arrival celebration
          if (_showArrivalCelebration)
            ArrivalCelebration(
              destinationName: commuteState.destinationName ?? "your destination",
              onDismiss: () {
                setState(() => _showArrivalCelebration = false);
                ref.read(commuteProvider.notifier).stopCommute();
              },
            ),
        ],
      ),
    );
  }
  
  /// * Card shown when opened via "Commute to this location" with a prefilled destination.
  Widget _buildPrefilledDestinationCard() {
    final name = _prefilledDestinationName ?? "";
    final lat = _prefilledLat!;
    final lon = _prefilledLon!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await _startCommuteWithDestination(<String, dynamic>{
            "name": name,
            "lat": lat,
            "lng": lon,
          });
          if (mounted) {
            setState(() {
              _prefilledDestinationName = null;
              _prefilledLat = null;
              _prefilledLon = null;
            });
          }
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.4),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingSM),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: const Icon(
                  Icons.directions_bus,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Commute to $name",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Tap to start commute",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMD,
                  vertical: AppTheme.spacingSM,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: const Text(
                  "GO",
                  style: TextStyle(
                    color: AppTheme.successColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// * Build idle state view (set destination)
  Widget _buildIdleView(CommuteState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppTheme.spacingMD),
          
          // * Header
          _buildHeader(),

          const SizedBox(height: AppTheme.spacingXL),

          // * Prefilled "Commute to this location" card
          if (_prefilledDestinationName != null &&
              _prefilledLat != null &&
              _prefilledLon != null) ...[
            _buildPrefilledDestinationCard(),
            const SizedBox(height: AppTheme.spacingXL),
          ],

          // * Destination input
          _buildDestinationInput(),

          const SizedBox(height: AppTheme.spacingXL),

          // * Typeahead suggestions when typing
          if (_destinationController.text.trim().isNotEmpty) ...[
            _buildInlineSearchSection(),
          ] else if (_recentDestinations.isNotEmpty) ...[
            // * Recent destinations when search box is idle
            _buildSectionHeader("Recent Destinations", Icons.history),
            const SizedBox(height: AppTheme.spacingMD),
            ..._recentDestinations.map((dest) => _buildRecentDestinationTile(dest)),
          ] else
            CommuteEmptyState(
              onSearchTap: () {
                _destinationFocusNode.requestFocus();
              },
            ),

          const SizedBox(height: AppTheme.spacingXL),

          // * Settings section
          _buildSettingsSection(state),
          
          const SizedBox(height: AppTheme.spacingMD),
          
          // * Safety settings
          _buildSafetySettingsCard(state),

          const SizedBox(height: AppTheme.spacingXXL),
        ],
      ),
    );
  }

  /// * Build header
  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor,
                AppTheme.secondaryColor,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.directions_bus_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: AppTheme.spacingMD),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Commute Mode",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                "Never miss your stop again",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  /// * Build destination input
  Widget _buildDestinationInput() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: AppTheme.borderColor,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _destinationController,
        focusNode: _destinationFocusNode,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 16,
        ),
        onChanged: _onDestinationTextChanged,
        onSubmitted: (value) {
          final query = value.trim();
          if (query.isNotEmpty) {
            _runDestinationSearch(query);
          }
        },
        decoration: InputDecoration(
          hintText: "Where are you going?",
          hintStyle: TextStyle(
            color: AppTheme.textSecondary.withOpacity(0.6),
          ),
          prefixIcon: const Icon(
            Icons.place_rounded,
            color: AppTheme.primaryColor,
          ),
          suffixIcon: IconButton(
            icon: const Icon(Icons.search_rounded, color: AppTheme.secondaryColor),
            onPressed: () {
              HapticFeedback.lightImpact();
              final query = _destinationController.text.trim();
              if (query.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Enter a place name to search")),
                );
                return;
              }
              _runDestinationSearch(query);
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(AppTheme.spacingLG),
        ),
      ),
    );
  }

  /// * Run location search and show results in a bottom sheet; on tap start commute to selected place.
  Future<void> _runDestinationSearch(String query) async {
    if (query.trim().isEmpty) return;

    await _detectSearchCountryCode();

    List<LocationSearchResult> results = _inlineSearchResults;
    if (results.isEmpty) {
      results = await _locationSearchService.searchLocationRespectCountry(
        query.trim(),
        preferredCountryCode: _detectedCountryCode,
        allowOutsideWhenNoLocal: false,
      );
    }

    if (results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No results found. Try a different search.")),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLG)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              child: Text(
                "Select destination",
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: results.length,
                itemBuilder: (ctx, index) {
                  final result = results[index];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _startCommuteWithDestination(<String, dynamic>{
                          "name": result.displayName,
                          "lat": result.latitude,
                          "lng": result.longitude,
                        });
                        _destinationController.text = result.displayName;
                      },
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      child: Container(
                        padding: const EdgeInsets.all(AppTheme.spacingMD),
                        margin: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingMD,
                          vertical: AppTheme.spacingXS,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                          border: Border.all(
                            color: AppTheme.borderColor.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppTheme.spacingSM),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                              ),
                              child: const Icon(
                                Icons.place_rounded,
                                color: AppTheme.primaryColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingMD),
                            Expanded(
                              child: Text(
                                result.displayName,
                                style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                                  color: AppTheme.textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded,
                                size: 14, color: AppTheme.textSecondary),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// * Build section header
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const SizedBox(width: AppTheme.spacingSM),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  /// * Inline search suggestions that appear while typing.
  Widget _buildInlineSearchSection() {
    if (_isInlineSearching) {
      return Container(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(color: AppTheme.borderColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppTheme.spacingSM),
            Text(
              "Searching...",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (_inlineSearchResults.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(color: AppTheme.borderColor.withOpacity(0.3)),
        ),
        child: Text(
          "No nearby matches yet. Add a country name to search outside your country.",
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Suggestions", Icons.place),
        const SizedBox(height: AppTheme.spacingMD),
        ..._inlineSearchResults.map(
          (result) => _buildRecentDestinationTile(<String, dynamic>{
            "name": result.displayName,
            "lat": result.latitude,
            "lng": result.longitude,
          }),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            "Press Enter to expand all results",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
  
  /// * Build recent destination tile
  Widget _buildRecentDestinationTile(Map<String, dynamic> destination) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _startCommuteWithDestination(destination),
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              border: Border.all(
                color: AppTheme.borderColor.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingSM),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  ),
                  child: const Icon(
                    Icons.place_rounded,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMD),
                Expanded(
                  child: Text(
                    destination["name"] as String,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingSM,
                    vertical: AppTheme.spacingXS,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  ),
                  child: const Text(
                    "GO",
                    style: TextStyle(
                      color: AppTheme.successColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  /// * Build settings section
  Widget _buildSettingsSection(CommuteState state) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingXS),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: AppTheme.primaryColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppTheme.spacingSM),
              Text(
                "Alarm Settings",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: AppTheme.spacingLG),
          
          // * Alarm distance slider
          _buildSettingItem(
            icon: Icons.straighten_rounded,
            title: "Distance Alarm",
            description: "Alert when this close to destination",
            trailing: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMD,
                vertical: AppTheme.spacingSM,
              ),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              ),
              child: Text(
                _formatDistance(state.settings.alarmDistanceMeters),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          
          Slider(
            value: state.settings.alarmDistanceMeters.toDouble(),
            min: 200,
            max: 1000,
            divisions: 8,
            activeColor: AppTheme.primaryColor,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              ref.read(commuteProvider.notifier).setAlarmDistance(value.round());
            },
          ),
          
          const Divider(color: AppTheme.borderColor, height: AppTheme.spacingLG),
          
          // * Time backup toggle
          _buildSettingItem(
            icon: Icons.timer_rounded,
            title: "Time Backup Alarm",
            description: "Also alert ${state.settings.backupAlarmMinutes} min before arrival (ETA based)",
            trailing: Switch.adaptive(
              value: state.settings.useTimeBackupAlarm,
              onChanged: (value) {
                HapticFeedback.lightImpact();
                ref.read(commuteProvider.notifier).setUseTimeBackupAlarm(value);
              },
              activeColor: AppTheme.primaryColor,
            ),
          ),
          
          // * Time backup slider (if enabled)
          if (state.settings.useTimeBackupAlarm) ...[
            const SizedBox(height: AppTheme.spacingSM),
            Row(
              children: [
                Text(
                  "1 min",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: state.settings.backupAlarmMinutes.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (value) {
                      HapticFeedback.selectionClick();
                      ref.read(commuteProvider.notifier).setBackupAlarmMinutes(value.round());
                    },
                  ),
                ),
                Text(
                  "10 min",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
          
          const Divider(color: AppTheme.borderColor, height: AppTheme.spacingLG),
          
          // * Vibration toggle
          _buildSettingItem(
            icon: Icons.vibration_rounded,
            title: "Vibration",
            description: "Vibrate when alarm triggers",
            trailing: Switch.adaptive(
              value: state.settings.vibrateOnAlarm,
              onChanged: (value) {
                HapticFeedback.lightImpact();
                ref.read(commuteProvider.notifier).setVibrateOnAlarm(value);
              },
              activeColor: AppTheme.primaryColor,
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingSM),
          
          // * Sound toggle
          _buildSettingItem(
            icon: Icons.volume_up_rounded,
            title: "Sound",
            description: "Play alarm sound",
            trailing: Switch.adaptive(
              value: state.settings.playSoundOnAlarm,
              onChanged: (value) {
                HapticFeedback.lightImpact();
                ref.read(commuteProvider.notifier).setPlaySoundOnAlarm(value);
              },
              activeColor: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
  
  /// * Build safety settings card
  Widget _buildSafetySettingsCard(CommuteState state) {
    final safetyEnabled = state.settings.safetySettings.enabled;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openSafetySettings(state),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacingLG),
          decoration: BoxDecoration(
            color: safetyEnabled 
                ? Colors.orange.withOpacity(0.1) 
                : AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            border: Border.all(
              color: safetyEnabled 
                  ? Colors.orange.withOpacity(0.3) 
                  : AppTheme.borderColor.withOpacity(0.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingSM),
                decoration: BoxDecoration(
                  color: safetyEnabled 
                      ? Colors.orange.withOpacity(0.2) 
                      : AppTheme.textSecondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Icon(
                  safetyEnabled ? Icons.shield : Icons.shield_outlined,
                  color: safetyEnabled ? Colors.orange : AppTheme.textSecondary,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "Safety Alert",
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        if (safetyEnabled) ...[
                          const SizedBox(width: AppTheme.spacingSM),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacingSM,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                            ),
                            child: const Text(
                              "ON",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      safetyEnabled
                          ? "Alert contacts if you go off-route"
                          : "Tap to set up emergency contacts",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// * Build setting item
  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String description,
    required Widget trailing,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 20),
        const SizedBox(width: AppTheme.spacingMD),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        trailing,
      ],
    );
  }
  
  /// * Format distance with proper units
  String _formatDistance(int meters) {
    if (meters < 1000) {
      return "$meters m";
    } else {
      return "${(meters / 1000).toStringAsFixed(1)} km";
    }
  }
  
  /// * Open safety settings sheet
  void _openSafetySettings(CommuteState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => SafetySettingsSheet(
          settings: state.settings.safetySettings,
          onSave: (newSettings) {
            ref.read(commuteProvider.notifier).updateSafetySettings(newSettings);
          },
        ),
      ),
    );
  }
  
  /// * Compact map showing current position and destination during commute.
  static const double _commuteMapHeight = 160.0;

  Widget _buildCommuteMap(LatLng current, LatLng destination) {
    final midLat = (current.latitude + destination.latitude) / 2.0;
    final midLng = (current.longitude + destination.longitude) / 2.0;
    final center = LatLng(midLat, midLng);
    const zoom = 12.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      child: SizedBox(
        height: _commuteMapHeight,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: zoom,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
              userAgentPackageName: "com.smartroad.app",
              maxZoom: 19,
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: current,
                  width: 36,
                  height: 36,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.my_location, color: Colors.white, size: 20),
                  ),
                ),
                Marker(
                  point: destination,
                  width: 36,
                  height: 36,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.place, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// * Build active commute view (scroll-free: expandable "Commute guide" card).
  Widget _buildActiveCommuteView(CommuteState state) {
    final isApproaching = state.status == CommuteStatus.approaching;
    final isDanger = state.status == CommuteStatus.danger;
    final current = state.currentPosition ?? state.startPosition;
    final destination = state.destination;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppTheme.spacingSM),
            if (current != null && destination != null) _buildCommuteMap(current, destination),
          if (current != null && destination != null) const SizedBox(height: AppTheme.spacingSM),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingLG,
              vertical: AppTheme.spacingSM,
            ),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              border: Border.all(color: AppTheme.borderColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.place_rounded, color: AppTheme.primaryColor, size: 18),
                const SizedBox(width: AppTheme.spacingSM),
                Flexible(
                  child: Text(
                    state.destinationName ?? "Unknown",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingSM),
          ScaleTransition(
            scale: isApproaching || isDanger
                ? _pulseAnimation
                : const AlwaysStoppedAnimation(1.0),
            child: CountdownRingWidget(
              progress: state.progressPercentage,
              status: state.status,
              distance: state.formattedDistance,
              eta: state.formattedEta,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSM),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingLG,
              vertical: AppTheme.spacingSM,
            ),
            decoration: BoxDecoration(
              color: _getStatusColor(state.status).withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              border: Border.all(
                color: _getStatusColor(state.status).withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getStatusIcon(state.status), size: 18, color: _getStatusColor(state.status)),
                const SizedBox(width: AppTheme.spacingSM),
                Text(
                  state.statusText,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: _getStatusColor(state.status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingMD),
          _buildTransitItineraryOrFailSafe(state),
          const SizedBox(height: AppTheme.spacingMD),
          _buildExpandableCommuteGuide(state),
          const SizedBox(height: AppTheme.spacingMD),
          Row(
            children: [
              if (isApproaching && !state.alarmDismissed)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      ref.read(commuteProvider.notifier).dismissAlarm();
                    },
                    icon: const Icon(Icons.notifications_off_rounded),
                    label: const Text("Dismiss"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.warningColor,
                      side: BorderSide(color: AppTheme.warningColor.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMD),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      ),
                    ),
                  ),
                ),
              if (isApproaching && !state.alarmDismissed) const SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _stopCommute(),
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text("Stop commute"),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.errorColor,
                    padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMD),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
        ],
        ),
      ),
    );
  }

  /// * Transit itinerary list from state, or fail-safe when no GTFS data.
  Widget _buildTransitItineraryOrFailSafe(CommuteState state) {
    final itinerary = state.transitItinerary is PlannerItinerary
        ? state.transitItinerary as PlannerItinerary
        : null;
    final transitMessage = state.transitItinerary is String
        ? state.transitItinerary as String
        : null;

    if (itinerary != null) {
      return _buildItineraryCard(itinerary);
    }
    if (transitMessage != null && transitMessage.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(color: AppTheme.borderColor.withOpacity(0.3)),
        ),
        child: Text(
          transitMessage,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildItineraryCard(PlannerItinerary itinerary) {
    final legLines = <Widget>[];
    for (final leg in itinerary.legs) {
      if (leg.mode == "walk") {
        final dist = leg.distanceM.round();
        legLines.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacingXS),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Walk ${dist}m → ",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                Expanded(
                  child: Text(
                    leg.endName == "Destination" ? "Destination" : "Stop: ${leg.endName}",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (leg.mode == "transit") {
        legLines.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacingXS),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Ride ${leg.vehicle ?? "Transit"} → ",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.primaryColor,
                  ),
                ),
                Expanded(
                  child: Text(
                    "Direction: ${leg.endName}",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        legLines.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacingXS),
            child: Text(
              "Alight → ${leg.endName}",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        );
      }
    }
    final confidenceStr = itinerary.legs
        .where((l) => l.mode == "transit")
        .map((l) => l.confidence)
        .fold<TransitConfidence>(TransitConfidence.low, (a, b) {
      if (a == TransitConfidence.high || b == TransitConfidence.high) return TransitConfidence.high;
      if (a == TransitConfidence.medium || b == TransitConfidence.medium) return TransitConfidence.medium;
      return TransitConfidence.low;
    });
    final confidenceLabel = confidenceStr == TransitConfidence.high
        ? "High"
        : confidenceStr == TransitConfidence.medium
            ? "Medium"
            : "Low";

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ...legLines,
          const Divider(height: AppTheme.spacingLG),
          Text(
            "Total Time: ${itinerary.totalTimeMin} minutes",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Transfers: ${itinerary.transfers}",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Estimated Fare: ₱${itinerary.fareEstimatePhp.toStringAsFixed(0)}",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Confidence: $confidenceLabel",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// * Section label + content for the expanded Commute guide.
  Widget _buildGuideSection(String title, Widget content) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        content,
      ],
    );
  }

  /// * Renders the expanded guide sections from [CommuteGuideData].
  Widget _buildGuideContentFromData(CommuteGuideData guide) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGuideSection(
          "Where to board (Sasakay)",
          Text(
            guide.whereToBoard,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacingSM),
        _buildGuideSection(
          "What to take",
          Text(
            guide.whatToTake,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacingSM),
        _buildGuideSection(
          "Estimated fare",
          Text(
            guide.estimatedFareText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacingSM),
        _buildGuideSection(
          "Distance and time",
          Text(
            guide.distanceAndTime,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacingSM),
        _buildGuideSection(
          "Notes",
          Text(
            guide.notes,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  /// * Renders guide content from memoized provider (keyed by destination, vehicle, itinerary) to avoid rebuild on every state tick.
  Widget _buildMemoizedGuideContent() {
    final guideAsync = ref.watch(commuteGuideProvider);
    return guideAsync.when(
      data: (CommuteGuideData? guide) {
        if (guide == null) {
          return _buildGuideSection(
            "Unavailable",
            Text(
              "Could not load guide. Check your connection.",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          );
        }
        return _buildGuideContentFromData(guide);
      },
      loading: () => _buildGuideSection(
        "Loading…",
        Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: AppTheme.spacingSM),
            Text(
              "Checking transit options…",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
      error: (Object err, StackTrace _) => _buildGuideSection(
        "Unavailable",
        Text(
          "Could not load guide. Check your connection.",
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  /// * Expandable card: guide from CommuteGuideService (GTFS or heuristic).
  Widget _buildExpandableCommuteGuide(CommuteState state) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _commuteGuideExpanded = !_commuteGuideExpanded);
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMD,
            vertical: AppTheme.spacingSM,
          ),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            border: Border.all(color: AppTheme.borderColor.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.primaryColor),
                  const SizedBox(width: AppTheme.spacingSM),
                  Text(
                    "Commute guide",
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _commuteGuideExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.textSecondary,
                    size: 24,
                  ),
                ],
              ),
              if (_commuteGuideExpanded) ...[
                const SizedBox(height: AppTheme.spacingMD),
                _buildMemoizedGuideContent(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // * Get status color
  Color _getStatusColor(CommuteStatus status) {
    switch (status) {
      case CommuteStatus.idle:
        return AppTheme.textSecondary;
      case CommuteStatus.active:
        return AppTheme.primaryColor;
      case CommuteStatus.approaching:
        return AppTheme.warningColor;
      case CommuteStatus.arrived:
        return AppTheme.successColor;
      case CommuteStatus.passed:
        return AppTheme.errorColor;
      case CommuteStatus.danger:
        return AppTheme.errorColor;
    }
  }

  // * Get status icon
  IconData _getStatusIcon(CommuteStatus status) {
    switch (status) {
      case CommuteStatus.idle:
        return Icons.place_outlined;
      case CommuteStatus.active:
        return Icons.directions_bus_rounded;
      case CommuteStatus.approaching:
        return Icons.notifications_active_rounded;
      case CommuteStatus.arrived:
        return Icons.check_circle_rounded;
      case CommuteStatus.passed:
        return Icons.warning_rounded;
      case CommuteStatus.danger:
        return Icons.emergency_rounded;
    }
  }
  
  /// * Start commute with selected destination
  Future<void> _startCommuteWithDestination(Map<String, dynamic> destination) async {
    HapticFeedback.mediumImpact();

    final name = destination["name"] as String;
    final lat = (destination["lat"] as num).toDouble();
    final lng = (destination["lng"] as num).toDouble();

    // * Show loading overlay so the user sees that the tap was registered
    if (mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    bool success = false;
    try {
      success = await ref.read(commuteProvider.notifier).startCommute(
        destination: LatLng(lat, lng),
        destinationName: name,
      );
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Could not start commute. Enable location and wait for GPS lock, then try again."),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    await _rememberRecentDestination(name: name, lat: lat, lng: lng);
  }
  
  /// * Stop commute
  Future<void> _stopCommute() async {
    HapticFeedback.mediumImpact();
    await ref.read(commuteProvider.notifier).stopCommute();
  }
}

