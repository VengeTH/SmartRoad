import "package:flutter/material.dart";
import "../models/sticker.dart";

/// * Custom marker widget for HOA gates
class HOAGateMarker extends StatelessWidget {
  final HOA hoa;
  
  const HOAGateMarker({
    super.key,
    required this.hoa,
  });
  
  /// * Get color based on access type
  /// * Red for residents_only, Green for public_shortcut
  Color _getColorForAccessType() {
    switch (hoa.accessType) {
      case HOAAccessType.residentsOnly:
        return Colors.red; // * Red gate icon for strict (Residents/Guests Only)
      case HOAAccessType.publicShortcut:
        return Colors.green; // * Green gate icon for open (Pay-to-Pass available)
    }
  }
  
  /// * Get tooltip text based on access type
  String _getTooltipText() {
    switch (hoa.accessType) {
      case HOAAccessType.residentsOnly:
        return "${hoa.name}\nResidents/Guests Only";
      case HOAAccessType.publicShortcut:
        return "${hoa.name}\nPay-to-Pass Available";
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final color = _getColorForAccessType();
    
    return Tooltip(
      message: _getTooltipText(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 8,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.home_work, // * Gate/community icon
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

