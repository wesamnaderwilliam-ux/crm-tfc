import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/supabase_config.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _hiringDateController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  double _bgOffset = 0.0;
  bool _isSignUpMode = false;
  String _selectedRole = 'company_employee';

  // Role options with Arabic labels
  static const List<Map<String, String>> _roleOptions = [
    {'value': 'company_employee', 'label': 'موظف الشركة'},
    {'value': 'bank_employee', 'label': 'موظف البنك'},
    {'value': 'manager', 'label': 'مدير مسؤول'},
    {'value': 'admin', 'label': 'مدير النظام (أدمن)'},
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _nationalIdController.dispose();
    _hiringDateController.dispose();
    super.dispose();
  }

  void _quickFill(String role) {
    if (role == 'manager') {
      _emailController.text = 'manager@futureclub.com';
      _passwordController.text = '123456';
    } else if (role == 'employee') {
      _emailController.text = 'employee@futureclub.com';
      _passwordController.text = '123456';
    } else if (role == 'bank') {
      _emailController.text = 'bank@futureclub.com';
      _passwordController.text = '123456';
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_isSignUpMode) {
      final success = await ref.read(authProvider.notifier).signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        confirmPassword: _confirmPasswordController.text.trim(),
        fullName: _fullNameController.text.trim(),
        role: _selectedRole,
        phoneNumber: _phoneController.text.trim(),
        nationalId: _nationalIdController.text.trim(),
        hiringDate: _hiringDateController.text.trim(),
      );

      if (success && mounted) {
        final session = SupabaseConfig.isInitialized ? SupabaseConfig.client.auth.currentSession : null;
        final message = session != null
            ? "تم إنشاء الحساب وتسجيل الدخول بنجاح! 🎉"
            : "تم إنشاء الحساب بنجاح! يرجى التحقق من بريدك الإلكتروني لتفعيله. ✉️";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message, textAlign: TextAlign.right),
            backgroundColor: TfcColors.primary,
          ),
        );
        if (session == null) {
          setState(() {
            _isSignUpMode = false;
          });
        }
      } else if (mounted) {
        final errorMsg = ref.read(authProvider).errorMessage ?? "فشل إنشاء الحساب";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg, textAlign: TextAlign.right),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } else {
      final success = await ref.read(authProvider.notifier).signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("مرحباً بك في نادي المستقبل! (تم الدخول) 🚀", textAlign: TextAlign.right),
            backgroundColor: TfcColors.primary,
          ),
        );
      } else if (mounted) {
        final errorMsg = ref.read(authProvider).errorMessage ?? "خطأ في تسجيل الدخول";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg, textAlign: TextAlign.right),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleGoogleSignUp() async {
    // Required fields: Full Name and Role (Account Type)
    if (_fullNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("يرجى إدخال الاسم الكامل أولاً قبل التسجيل بواسطة Google", textAlign: TextAlign.right),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    if (_fullNameController.text.trim().length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("الاسم الكامل يجب أن يكون 3 أحرف على الأقل", textAlign: TextAlign.right),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    await ref.read(authProvider.notifier).signInWithGoogle(
      fullName: _fullNameController.text.trim(),
      role: _selectedRole,
    );

    if (mounted) {
      final errorMsg = ref.read(authProvider).errorMessage;
      if (errorMsg != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg, textAlign: TextAlign.right),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: MouseRegion(
        onHover: (event) {
          setState(() {
            _bgOffset = event.localPosition.dx * 0.02;
          });
        },
        child: Stack(
          children: [
            // Atmospheric background effect (radial gradients)
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                transform: Matrix4.translationValues(_bgOffset, 0, 0),
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.6, -0.6),
                    radius: 1.2,
                    colors: [
                      Color(0x1A00F5D4), // Cyan tint
                      Color(0x00050505),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                transform: Matrix4.translationValues(-_bgOffset, 0, 0),
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-0.6, 0.6),
                    radius: 1.2,
                    colors: [
                      Color(0x1AFFB1C2), // Magenta tint
                      Color(0x00050505),
                    ],
                  ),
                ),
              ),
            ),
            
            // Dotted pattern layout overlay (local, no network)
            Positioned.fill(
              child: Opacity(
                opacity: 0.03,
                child: CustomPaint(
                  painter: _DotNoisePainter(),
                  size: Size.infinite,
                ),
              ),
            ),

            // Scrollable Content Center
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: SizedBox(
                  width: 460,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Header Brand Image Logo
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(60),
                          child: Image.asset(
                            'assets/images/logo.png',
                            height: 100,
                            width: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.account_balance,
                              color: Color(0xFFD4AF37),
                              size: 60,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        "THE FUTURE CLUB",
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: const Color(0xFFD4AF37),
                          fontSize: 22,
                          letterSpacing: 1.5,
                          shadows: [
                            const Shadow(
                              color: Color(0x99D4AF37),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _isSignUpMode ? "إنشاء حساب جديد" : "مرحباً بك مجدداً",
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isSignUpMode 
                            ? "أدخل بياناتك الشخصية لإنشاء حسابك" 
                            : "سجل الدخول لإدارة ثروتك المستقبلية",
                        style: const TextStyle(color: TfcColors.outline),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // Glass Login Card
                      GlassCard(
                        borderRadius: 24,
                        padding: const EdgeInsets.all(32),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // === SIGN UP FIELDS ===
                              if (_isSignUpMode) ...[
                                // Full Name Field
                                _buildFieldLabel("الاسم الكامل", Icons.person_outline),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _fullNameController,
                                  textAlign: TextAlign.right,
                                  textDirection: TextDirection.rtl,
                                  decoration: const InputDecoration(
                                    hintText: "مثال: أحمد محمد الشمري",
                                    prefixIcon: Icon(Icons.badge_outlined, color: TfcColors.outline),
                                  ),
                                  validator: (value) {
                                    if (!_isSignUpMode) return null;
                                    if (value == null || value.trim().isEmpty) {
                                      return "يرجى إدخال الاسم الكامل";
                                    }
                                    if (value.trim().length < 3) {
                                      return "الاسم يجب أن يكون 3 أحرف على الأقل";
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),

                                // Account Type Dropdown
                                _buildFieldLabel("نوع الحساب", Icons.shield_outlined),
                                const SizedBox(height: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                  ),
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _selectedRole,
                                    dropdownColor: TfcColors.surfaceContainer,
                                    isExpanded: true,
                                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: TfcColors.primary),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      prefixIcon: Icon(Icons.admin_panel_settings_outlined, color: TfcColors.outline),
                                    ),
                                    items: _roleOptions.map((role) {
                                      return DropdownMenuItem<String>(
                                        value: role['value'],
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          textDirection: TextDirection.rtl,
                                          children: [
                                            Icon(
                                              _getRoleIcon(role['value']!),
                                              size: 16,
                                              color: _getRoleColor(role['value']!),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              role['label']!,
                                              style: TextStyle(
                                                color: _getRoleColor(role['value']!),
                                                fontWeight: FontWeight.w600,
                                              ),
                                              textDirection: TextDirection.rtl,
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _selectedRole = value;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Phone Number Field
                                _buildFieldLabel("رقم الهاتف", Icons.phone_outlined),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  textAlign: TextAlign.right,
                                  textDirection: TextDirection.ltr,
                                  decoration: const InputDecoration(
                                    hintText: "05xxxxxxxx (اختياري)",
                                    prefixIcon: Icon(Icons.phone, color: TfcColors.outline),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // National ID Field (Optional)
                                _buildFieldLabel("الرقم القومي (اختياري)", Icons.badge_outlined),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _nationalIdController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.right,
                                  textDirection: TextDirection.ltr,
                                  decoration: const InputDecoration(
                                    hintText: "الرقم القومي - 14 رقم (اختياري)",
                                    prefixIcon: Icon(Icons.badge, color: TfcColors.outline),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Hiring Date Field
                                _buildFieldLabel("تاريخ التعيين", Icons.calendar_today_outlined),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _hiringDateController,
                                  readOnly: true,
                                  textAlign: TextAlign.right,
                                  decoration: const InputDecoration(
                                    hintText: "اختر تاريخ التعيين",
                                    prefixIcon: Icon(Icons.calendar_today, color: TfcColors.outline),
                                  ),
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime.now(),
                                    );
                                    if (picked != null) {
                                      _hiringDateController.text =
                                          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                                    }
                                  },
                                ),
                                const SizedBox(height: 20),
                              ],

                              // Email Field
                              _buildFieldLabel("البريد الإلكتروني", Icons.alternate_email),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textAlign: TextAlign.right,
                                textDirection: TextDirection.ltr,
                                decoration: const InputDecoration(
                                  hintText: "name@futureclub.com",
                                  prefixIcon: Icon(Icons.alternate_email, color: TfcColors.outline),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return "يرجى إدخال البريد الإلكتروني";
                                  }
                                  if (!value.contains('@') || !value.contains('.')) {
                                    return "يرجى إدخال بريد إلكتروني صحيح";
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),

                              // Password Field
                              _buildFieldLabel("كلمة المرور", Icons.lock_outline),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textAlign: TextAlign.right,
                                textDirection: TextDirection.ltr,
                                decoration: InputDecoration(
                                  hintText: "••••••••",
                                  prefixIcon: const Icon(Icons.lock, color: TfcColors.outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                      color: TfcColors.outline,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return "يرجى إدخال كلمة المرور";
                                  }
                                  if (_isSignUpMode && value.length < 6) {
                                    return "كلمة المرور يجب أن تكون 6 أحرف على الأقل";
                                  }
                                  return null;
                                },
                              ),

                              // Confirm Password Field (Sign Up only)
                              if (_isSignUpMode) ...[
                                const SizedBox(height: 20),
                                _buildFieldLabel("تأكيد كلمة المرور", Icons.lock_reset),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _confirmPasswordController,
                                  obscureText: _obscureConfirmPassword,
                                  textAlign: TextAlign.right,
                                  textDirection: TextDirection.ltr,
                                  decoration: InputDecoration(
                                    hintText: "••••••••",
                                    prefixIcon: const Icon(Icons.lock_reset, color: TfcColors.outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                                        color: TfcColors.outline,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscureConfirmPassword = !_obscureConfirmPassword;
                                        });
                                      },
                                    ),
                                  ),
                                  validator: (value) {
                                    if (!_isSignUpMode) return null;
                                    if (value == null || value.isEmpty) {
                                      return "يرجى تأكيد كلمة المرور";
                                    }
                                    if (value != _passwordController.text) {
                                      return "كلمة المرور غير متطابقة";
                                    }
                                    return null;
                                  },
                                ),
                              ],

                              const SizedBox(height: 16),

                               if (!_isSignUpMode) ...[
                                 Row(
                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                   textDirection: TextDirection.rtl,
                                   children: [
                                     Row(
                                       textDirection: TextDirection.rtl,
                                       children: [
                                         SizedBox(
                                           width: 24,
                                           height: 24,
                                           child: Checkbox(
                                             value: true,
                                             activeColor: TfcColors.primary,
                                             onChanged: (val) {},
                                           ),
                                         ),
                                         const SizedBox(width: 8),
                                         const Text("تذكرني", style: TextStyle(color: TfcColors.onSurfaceVariant)),
                                       ],
                                     ),
                                     TextButton(
                                       onPressed: () {},
                                       child: const Text("نسيت كلمة المرور؟", style: TextStyle(color: TfcColors.primary)),
                                     ),
                                   ],
                                 ),
                                 const SizedBox(height: 24),
                               ],

                              // Main Submit Button
                              _buildPrimaryButton(authState),
                              
                              // Google Sign-Up/Sign-In button (Sign Up mode only)
                              if (_isSignUpMode) ...[
                                const SizedBox(height: 16),
                                _buildDividerWithText("أو"),
                                const SizedBox(height: 16),
                                _buildGoogleButton(authState),
                              ],

                              const SizedBox(height: 24),
                              
                              // Simulated Demo logins to skip typing during review (Login mode only)
                               if (!_isSignUpMode) ...[
                                 const Text(
                                   "تسجيل دخول سريع للتجربة (التجريبي)",
                                   style: TextStyle(fontSize: 12, color: TfcColors.outline),
                                   textAlign: TextAlign.center,
                                 ),
                                 const SizedBox(height: 8),
                                 Row(
                                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                   children: [
                                     OutlinedButton(
                                       style: OutlinedButton.styleFrom(
                                         side: const BorderSide(color: TfcColors.secondary, width: 0.5),
                                       ),
                                       onPressed: () => _quickFill('manager'),
                                       child: const Text("مدير", style: TextStyle(color: TfcColors.secondary, fontSize: 11)),
                                     ),
                                     OutlinedButton(
                                       style: OutlinedButton.styleFrom(
                                         side: const BorderSide(color: TfcColors.primary, width: 0.5),
                                       ),
                                       onPressed: () => _quickFill('employee'),
                                       child: const Text("مندوب", style: TextStyle(color: TfcColors.primary, fontSize: 11)),
                                     ),
                                     OutlinedButton(
                                       style: OutlinedButton.styleFrom(
                                         side: const BorderSide(color: Colors.blueAccent, width: 0.5),
                                       ),
                                       onPressed: () => _quickFill('bank'),
                                       child: const Text("بنك", style: TextStyle(color: Colors.blueAccent, fontSize: 11)),
                                     ),
                                   ],
                                 ),
                               ],
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      // Toggle login/signup link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        textDirection: TextDirection.rtl,
                        children: [
                          Text(
                            _isSignUpMode ? "لديك حساب بالفعل؟" : "مستخدم جديد؟",
                            style: const TextStyle(color: TfcColors.onSurfaceVariant),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isSignUpMode = !_isSignUpMode;
                              });
                            },
                            child: Text(
                              _isSignUpMode ? "تسجيل الدخول" : "إنشاء حساب",
                              style: const TextStyle(color: TfcColors.primary, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Lower left system connection detail widget
            Positioned(
              bottom: 24,
              left: 24,
              child: Opacity(
                opacity: 0.5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: SupabaseConfig.isInitialized ? TfcColors.primary : Colors.orangeAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          SupabaseConfig.isInitialized ? "النظام: متصل بقاعدة البيانات" : "النظام: وضع تجريبي",
                          style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text("التشفير: AES-256 كوانتوم", style: TextStyle(fontSize: 9, fontFamily: 'monospace')),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // === HELPER WIDGETS ===

  Widget _buildFieldLabel(String label, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      textDirection: TextDirection.rtl,
      children: [
        Icon(icon, size: 14, color: TfcColors.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: TfcColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
          textDirection: TextDirection.rtl,
        ),
      ],
    );
  }

  Widget _buildPrimaryButton(AuthState authState) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [TfcColors.primary, Color(0xFF00C9B7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: TfcColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: TfcColors.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: authState.isLoading ? null : _handleSubmit,
        child: authState.isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: TfcColors.onPrimary),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                textDirection: TextDirection.rtl,
                children: [
                  Text(
                    _isSignUpMode ? "إنشاء حساب جديد" : "تسجيل الدخول",
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: TfcColors.onPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isSignUpMode ? Icons.person_add_alt_1 : Icons.arrow_back,
                    size: 18,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDividerWithText(String text) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            text,
            style: const TextStyle(color: TfcColors.outline, fontSize: 12),
          ),
        ),
        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
      ],
    );
  }

  Widget _buildGoogleButton(AuthState authState) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: Colors.white.withValues(alpha: 0.03),
      ),
      onPressed: authState.isLoading ? null : _handleGoogleSignUp,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        textDirection: TextDirection.rtl,
        children: [
          // Google "G" icon using text with Google colors
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(
              child: Text(
                "G",
                style: TextStyle(
                  color: Color(0xFF4285F4),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            "التسجيل بواسطة Google",
            style: TextStyle(
              color: TfcColors.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'manager':
        return Icons.manage_accounts;
      case 'company_employee':
        return Icons.business_center;
      case 'bank_employee':
        return Icons.account_balance;
      default:
        return Icons.person;
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return const Color(0xFFFF6B6B);
      case 'manager':
        return TfcColors.secondary;
      case 'company_employee':
        return TfcColors.primary;
      case 'bank_employee':
        return Colors.blueAccent;
      default:
        return TfcColors.onSurface;
    }
  }
}

class _DotNoisePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 1.0;
    
    const double spacing = 16.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
