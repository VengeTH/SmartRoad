import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:latlong2/latlong.dart";
import "../core/theme/app_theme.dart";

/// * Widget for drawing routes on the map
class RouteDrawingWidget extends StatefulWidget {
  final MapController mapController;
  final Function(List<LatLng>) onRouteDrawn;
  final LatLng? startPoint;
  final LatLng? endPoint;
  
  const RouteDrawingWidget({
    super.key,
    required this.mapController,
    required this.onRouteDrawn,
    this.startPoint,
    this.endPoint,
  });
  
  @override
  State<RouteDrawingWidget> createState() => _RouteDrawingWidgetState();
}

class _RouteDrawingWidgetState extends State<RouteDrawingWidget> {
  List<LatLng> _drawnPoints = [];
  bool _isDrawing = false;
  
  @override
  void initState() {
    super.initState();
    if (widget.startPoint != null) {
      _drawnPoints.add(widget.startPoint!);
    }
  }
  
  // * Map interaction handlers will be connected via MapController callbacks
  // * These methods are kept for future implementation
  // void _onMapTap(TapPosition tapPosition, LatLng point) {
  //   if (!_isDrawing) return;
  //   setState(() {
  //     _drawnPoints.add(point);
  //   });
  // }
  
  // void _onMapLongPress(TapPosition tapPosition, LatLng point) {
  //   if (_drawnPoints.length >= 2) {
  //     _finishDrawing();
  //   }
  // }
  
  void _startDrawing() {
    setState(() {
      _isDrawing = true;
      _drawnPoints = widget.startPoint != null ? [widget.startPoint!] : [];
    });
  }
  
  void _finishDrawing() {
    if (_drawnPoints.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please draw at least 2 points")),
      );
      return;
    }
    
    if (widget.endPoint != null && !_drawnPoints.contains(widget.endPoint!)) {
      _drawnPoints.add(widget.endPoint!);
    }
    
    setState(() {
      _isDrawing = false;
    });
    
    widget.onRouteDrawn(_drawnPoints);
  }
  
  void _clearDrawing() {
    setState(() {
      _drawnPoints = widget.startPoint != null ? [widget.startPoint!] : [];
    });
  }
  
  void _undoLastPoint() {
    if (_drawnPoints.length > (widget.startPoint != null ? 1 : 0)) {
      setState(() {
        _drawnPoints.removeLast();
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // * Map interaction layer
        GestureDetector(
          onTap: () {
            // * Handle tap through to map
          },
          child: Container(color: Colors.transparent),
        ),
        // * Drawing controls
        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isDrawing
                      ? "Tap on map to add points. Long press to finish."
                      : "Tap 'Start Drawing' to begin",
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (!_isDrawing)
                      ElevatedButton.icon(
                        onPressed: _startDrawing,
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text("Start Drawing"),
                      )
                    else ...[
                      IconButton(
                        onPressed: _undoLastPoint,
                        icon: const Icon(Icons.undo),
                        tooltip: "Undo Last Point",
                      ),
                      IconButton(
                        onPressed: _clearDrawing,
                        icon: const Icon(Icons.clear),
                        tooltip: "Clear All",
                      ),
                      ElevatedButton.icon(
                        onPressed: _finishDrawing,
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text("Finish"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successColor,
                        ),
                      ),
                    ],
                  ],
                ),
                if (_drawnPoints.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      "${_drawnPoints.length} point${_drawnPoints.length != 1 ? 's' : ''}",
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  /// * Get polyline for drawn route
  Polyline getDrawnPolyline() {
    if (_drawnPoints.length < 2) {
      return Polyline(
        points: [],
        strokeWidth: 0,
        color: Colors.transparent,
      );
    }
    
    return Polyline(
      points: _drawnPoints,
      strokeWidth: 4.0,
      color: AppTheme.primaryColor,
      borderStrokeWidth: 2.0,
      borderColor: Colors.white,
    );
  }
  
  List<LatLng> getDrawnPoints() => List.from(_drawnPoints);
}
