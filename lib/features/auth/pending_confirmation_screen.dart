import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

/// Screen displayed to authenticated users whose account has NOT yet been
/// confirmed by an Admin. They cannot interact with any CRM data until the
/// Admin toggles their `is_confirmed` flag to true.
class PendingConfirmationScreen extends ConsumerWidget {
  const PendingConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: Stack(
        children: [
          // Atmospheric background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, -0.4),
                  radius: 1.4,
                  colors: [
                    Color(0x1A00F5D4),
                    Color(0x00050505),
                  ],
                ),
              ),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: SizedBox(
                width: 480,
                child: GlassCard(
                  borderRadius: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animated hourglass icon
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 1200),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: child,
                          );
                        },
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00F5D4), Color(0xFFFFB1C2)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: TfcColors.primary.withValues(alpha: 0.3),
                                blurRadius: 32,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.hourglass_top_rounded,
                            color: TfcColors.onPrimary,
                            size: 48,
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Title
                      Text(
                        'في انتظار موافقة الإدارة',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: TfcColors.primary,
                        ),
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                      ),

                      const SizedBox(height: 16),

                      // Subtitle
                      Text(
                        'تم إنشاء حسابك بنجاح! يجب أن يوافق مدير النظام (الأدمن) على حسابك قبل أن تتمكن من الوصول إلى لوحة التحكم.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: TfcColors.onSurfaceVariant,
                          height: 1.7,
                        ),
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                      ),

                      const SizedBox(height: 24),

                      // User info chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          textDirection: TextDirection.rtl,
                          children: [
                            const Icon(Icons.person_outline, color: TfcColors.outline, size: 18),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                authState.fullName,
                                style: const TextStyle(
                                  color: TfcColors.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orangeAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'غير مؤكد',
                                style: TextStyle(
                                  color: Colors.orangeAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Refresh button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          side: BorderSide(color: TfcColors.primary.withValues(alpha: 0.4)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          // Re-fetch profile to check if admin has confirmed
                          ref.read(authProvider.notifier).refreshProfile();
                        },
                        icon: const Icon(Icons.refresh_rounded, color: TfcColors.primary),
                        label: const Text(
                          'تحقق من حالة الحساب',
                          style: TextStyle(color: TfcColors.primary, fontWeight: FontWeight.w600),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Logout button
                      TextButton.icon(
                        onPressed: () => ref.read(authProvider.notifier).signOut(),
                        icon: const Icon(Icons.logout, color: Colors.redAccent, size: 18),
                        label: const Text(
                          'تسجيل الخروج',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
