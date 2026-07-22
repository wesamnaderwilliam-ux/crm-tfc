import 'package:flutter/material.dart';

class ToggleableFilterPanel extends StatefulWidget {
  final String title;
  final Widget filterContent;
  final VoidCallback? onApplyFilter;
  final VoidCallback? onResetFilter;
  final int activeFilterCount;

  const ToggleableFilterPanel({
    super.key,
    this.title = "خيارات التصفية والبحث 🔍",
    required this.filterContent,
    this.onApplyFilter,
    this.onResetFilter,
    this.activeFilterCount = 0,
  });

  @override
  State<ToggleableFilterPanel> createState() => _ToggleableFilterPanelState();
}

class _ToggleableFilterPanelState extends State<ToggleableFilterPanel> {
  bool _isExpanded = false;

  void _togglePanel() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  void _handleApply() {
    if (widget.onApplyFilter != null) {
      widget.onApplyFilter!();
    }
    setState(() {
      _isExpanded = false; // Auto hide after filtering
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E38).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isExpanded
              ? const Color(0xFF6C5CE7).withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.1),
          width: _isExpanded ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Trigger Button
          InkWell(
            onTap: _togglePanel,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.filter_alt_rounded,
                      color: Color(0xFFA29BFE),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.activeFilterCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00CEC9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "${widget.activeFilterCount}",
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white70,
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Collapsible Panel
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(color: Colors.white12, height: 24),
                  widget.filterContent,
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (widget.onResetFilter != null)
                        TextButton.icon(
                          onPressed: widget.onResetFilter,
                          icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.white70),
                          label: const Text("إعادة تصفية", style: TextStyle(color: Colors.white70)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                        ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _handleApply,
                        icon: const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                        label: const Text(
                          "تطبيق والتصفية 🔍",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C5CE7),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }
}
