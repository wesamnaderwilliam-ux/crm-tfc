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
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E38).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _isExpanded
              ? const Color(0xFF6C5CE7).withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.08),
          width: _isExpanded ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Trigger Button (Compact Height)
          InkWell(
            onTap: _togglePanel,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: Color(0xFFA29BFE),
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.activeFilterCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00CEC9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "${widget.activeFilterCount} نشط",
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white70,
                      size: 20,
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
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(color: Colors.white12, height: 14),
                  widget.filterContent,
                  const SizedBox(height: 10),
                  Row(
                    textDirection: TextDirection.rtl,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _handleApply,
                        icon: const Icon(Icons.check_circle_rounded, size: 14, color: Colors.white),
                        label: const Text(
                          "تطبيق التصفية",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C5CE7),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (widget.onResetFilter != null)
                        TextButton.icon(
                          onPressed: widget.onResetFilter,
                          icon: const Icon(Icons.refresh_rounded, size: 14, color: Colors.white70),
                          label: const Text("إعادة ضبط", style: TextStyle(color: Colors.white70, fontSize: 12)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}
