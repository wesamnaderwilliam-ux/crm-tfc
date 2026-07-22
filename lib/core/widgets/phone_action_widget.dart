import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';

/// A reusable widget that displays a phone number with interactive
/// call and WhatsApp action buttons on hover/tap.
class PhoneActionWidget extends StatefulWidget {
  final String label;
  final String phoneNumber;

  const PhoneActionWidget({
    super.key,
    required this.label,
    required this.phoneNumber,
  });

  @override
  State<PhoneActionWidget> createState() => _PhoneActionWidgetState();
}

class _PhoneActionWidgetState extends State<PhoneActionWidget> {
  bool _isHovered = false;

  String _normalizePhone(String phone) {
    // Remove spaces, dashes, parentheses
    String cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    // If starts with 0 and looks like Egyptian number, add +2
    if (cleaned.startsWith('0') && cleaned.length >= 10) {
      cleaned = '+2$cleaned';
    }
    // If doesn't start with +, add +
    if (!cleaned.startsWith('+')) {
      cleaned = '+$cleaned';
    }
    return cleaned;
  }

  Future<void> _makePhoneCall() async {
    final normalized = _normalizePhone(widget.phoneNumber);
    final uri = Uri.parse('tel:$normalized');
    try {
      await launchUrl(uri);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن إجراء المكالمة من هذا الجهاز', textAlign: TextAlign.right),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _openWhatsApp() async {
    final normalized = _normalizePhone(widget.phoneNumber);
    // Remove the + for WhatsApp API
    final waNumber = normalized.replaceFirst('+', '');
    final uri = Uri.parse('https://wa.me/$waNumber');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن فتح واتساب', textAlign: TextAlign.right),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        decoration: _isHovered
            ? BoxDecoration(
                color: const Color(0xFF25D366).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF25D366).withValues(alpha: 0.25),
                ),
              )
            : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          textDirection: TextDirection.rtl,
          children: [
            // Label (if provided)
            if (widget.label.isNotEmpty)
              Text(
                widget.label,
                style: const TextStyle(
                  color: TfcColors.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),

            // Phone number + Action buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Phone Number Text (tappable for popup on mobile)
                GestureDetector(
                  onTap: () => _showActionsPopup(context),
                  child: Text(
                    widget.phoneNumber,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: _isHovered ? const Color(0xFF25D366) : Colors.white,
                      decoration: _isHovered ? TextDecoration.underline : null,
                      decorationColor: const Color(0xFF25D366),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Always Visible Action Buttons (Call & WhatsApp)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Call Button
                    _ActionIconButton(
                      icon: Icons.phone_in_talk_rounded,
                      color: Colors.cyan,
                      tooltip: 'إجراء مكالمة',
                      onTap: _makePhoneCall,
                    ),
                    const SizedBox(width: 6),
                    // WhatsApp Button
                    _ActionIconButton(
                      icon: Icons.chat_rounded,
                      color: const Color(0xFF25D366),
                      tooltip: 'محادثة واتساب',
                      onTap: _openWhatsApp,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Shows a popup with call and WhatsApp actions (useful for mobile/touch)
  void _showActionsPopup(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                // Phone number display
                Text(
                  widget.phoneNumber,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.label,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 24),
                // Action Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Call
                    _buildActionColumn(
                      icon: Icons.phone,
                      label: 'اتصال',
                      color: Colors.cyan,
                      onTap: () {
                        Navigator.pop(ctx);
                        _makePhoneCall();
                      },
                    ),
                    // WhatsApp
                    _buildActionColumn(
                      icon: Icons.chat,
                      label: 'واتساب',
                      color: const Color(0xFF25D366),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openWhatsApp();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionColumn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.4)),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small icon button for inline phone actions
class _ActionIconButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_ActionIconButton> createState() => _ActionIconButtonState();
}

class _ActionIconButtonState extends State<_ActionIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        child: Tooltip(
          message: widget.tooltip,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: _hovered
                  ? widget.color.withValues(alpha: 0.3)
                  : widget.color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.color.withValues(alpha: _hovered ? 0.6 : 0.35),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: _hovered ? 0.35 : 0.15),
                  blurRadius: _hovered ? 8 : 4,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: Icon(widget.icon, color: widget.color, size: 17),
          ),
        ),
      ),
    );
  }
}
