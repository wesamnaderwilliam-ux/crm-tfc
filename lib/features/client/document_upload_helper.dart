import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../core/supabase_config.dart';
import '../../core/utils/web_helper.dart';

class DocumentUploadHelper {
  /// Upload binary file to Supabase Storage bucket 'client-documents' and return public URL
  static Future<String> uploadToSupabaseStorage({
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (!SupabaseConfig.isInitialized) {
      final mime = _getMimeTypeStatic(fileName);
      return kIsWeb ? createBlobUrl(bytes, mime) : 'data:$mime;base64,${base64Encode(bytes)}';
    }

    try {
      final cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final path = 'docs/${DateTime.now().millisecondsSinceEpoch}_$cleanName';
      final contentType = _getMimeTypeStatic(fileName);

      await SupabaseConfig.client.storage
          .from('client-documents')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );

      final publicUrl = SupabaseConfig.client.storage
          .from('client-documents')
          .getPublicUrl(path);

      return publicUrl;
    } catch (e) {
      debugPrint("Supabase Storage upload fallback: $e");
      final mime = _getMimeTypeStatic(fileName);
      return kIsWeb ? createBlobUrl(bytes, mime) : 'data:$mime;base64,${base64Encode(bytes)}';
    }
  }

  static String _getMimeTypeStatic(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf': return 'application/pdf';
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      case 'gif': return 'image/gif';
      case 'webp': return 'image/webp';
      default: return 'application/octet-stream';
    }
  }

  /// Open a premium glassmorphic dialog to upload documents via Device or Camera
  static Future<void> showUploadDialog(
    BuildContext context, {
    String? initialName,
    required Function(String name, String url) onUploadComplete,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return _UploadDialogWidget(
          initialName: initialName,
          onUploadComplete: onUploadComplete,
        );
      },
    );
  }
}

class _UploadDialogWidget extends StatefulWidget {
  final String? initialName;
  final Function(String name, String url) onUploadComplete;

  const _UploadDialogWidget({
    this.initialName,
    required this.onUploadComplete,
  });

  @override
  State<_UploadDialogWidget> createState() => _UploadDialogWidgetState();
}

class _UploadDialogWidgetState extends State<_UploadDialogWidget> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  
  String? _selectedFileName;
  String? _selectedFileUrl;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  bool _showCamera = false;
  
  // Camera Simulation Animation
  late AnimationController _cameraAnimationController;
  bool _cameraCaptured = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _cameraAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cameraAnimationController.dispose();
    super.dispose();
  }

  Future<String> _processFileAndUpload(PlatformFile file) async {
    if (file.bytes != null) {
      return await DocumentUploadHelper.uploadToSupabaseStorage(
        fileName: file.name,
        bytes: file.bytes!,
      );
    }
    return file.path ?? "storage/${file.name}";
  }

  String _getFileUrl(PlatformFile file) {
    if (kIsWeb && file.bytes != null) {
      final mime = _getMimeType(file.name);
      return createBlobUrl(file.bytes!, mime);
    }
    if (file.bytes != null) {
      final base64Data = base64Encode(file.bytes!);
      final mime = _getMimeType(file.name);
      return 'data:$mime;base64,$base64Data';
    }
    return file.path ?? "mock_storage/${file.name}";
  }

  String _getMimeType(String fileName) {
    return DocumentUploadHelper._getMimeTypeStatic(fileName);
  }

  Future<void> _simulateDeviceSelection() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        if (result.files.length == 1) {
          final file = result.files.first;
          setState(() {
            _selectedFileName = file.name;
            _isUploading = true;
            _uploadProgress = 0.3;
          });

          final uploadedUrl = await _processFileAndUpload(file);

          if (mounted) {
            setState(() {
              _selectedFileUrl = uploadedUrl;
              _uploadProgress = 1.0;
              _isUploading = false;
              if (_nameController.text.isEmpty) {
                _nameController.text = file.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '').replaceAll('_', ' ');
              }
            });
          }
        } else {
          // If multiple files selected, upload them all to Supabase Storage and return immediately
          setState(() {
            _isUploading = true;
            _uploadProgress = 0.5;
          });
          
          for (var file in result.files) {
            final fileName = file.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '').replaceAll('_', ' ');
            final uploadedUrl = await _processFileAndUpload(file);
            widget.onUploadComplete(fileName, uploadedUrl);
          }
          if (mounted) {
            Navigator.pop(context);
          }
        }
      }
    } catch (e) {
      debugPrint("File picker error: $e");
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Widget _buildCameraSim() {
    return Column(
      children: [
        // Camera Viewfinder Box
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _cameraCaptured ? TfcColors.success : TfcColors.primary.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Stack(
            children: [
              if (!_cameraCaptured) ...[
                // Simulated scanning background
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.3,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          colors: [Color(0x3300F5D4), Colors.transparent],
                          radius: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
                // Scanning Line Animation
                AnimatedBuilder(
                  animation: _cameraAnimationController,
                  builder: (context, child) {
                    return Positioned(
                      top: 15 + (_cameraAnimationController.value * 180),
                      left: 15,
                      right: 15,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          color: TfcColors.primary,
                          boxShadow: [
                            BoxShadow(
                              color: TfcColors.primary.withValues(alpha: 0.8),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                // Viewfinder Corners
                Positioned(
                  top: 20, left: 20,
                  child: Container(width: 16, height: 16, decoration: const BoxDecoration(border: Border(top: BorderSide(color: TfcColors.primary, width: 2), left: BorderSide(color: TfcColors.primary, width: 2)))),
                ),
                Positioned(
                  top: 20, right: 20,
                  child: Container(width: 16, height: 16, decoration: const BoxDecoration(border: Border(top: BorderSide(color: TfcColors.primary, width: 2), right: BorderSide(color: TfcColors.primary, width: 2)))),
                ),
                Positioned(
                  bottom: 20, left: 20,
                  child: Container(width: 16, height: 16, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: TfcColors.primary, width: 2), left: BorderSide(color: TfcColors.primary, width: 2)))),
                ),
                Positioned(
                  bottom: 20, right: 20,
                  child: Container(width: 16, height: 16, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: TfcColors.primary, width: 2), right: BorderSide(color: TfcColors.primary, width: 2)))),
                ),
                // Red blinking record dot
                Positioned(
                  top: 20,
                  left: 20,
                  child: Row(
                    children: [
                      const SizedBox(width: 24),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        "SCANNING",
                        style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ],
                  ),
                ),
                // Scanner status label
                const Align(
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_scanner, color: TfcColors.primary, size: 36),
                      SizedBox(height: 12),
                      Text(
                        "ضع المستند داخل الإطار للمسح",
                        style: TextStyle(color: TfcColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Captured state preview
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF13171E),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: TfcColors.success.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_circle, color: TfcColors.success, size: 40),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "تم التقاط الصورة ومسحها بنجاح!",
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "document_scan_captured.jpg (720 KB)",
                            style: TextStyle(color: TfcColors.outline, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Action buttons inside camera section
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_cameraCaptured)
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _cameraCaptured = true;
                    _selectedFileName = "لقطة_كاميرا_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}.jpg";
                    _selectedFileUrl = "camera_captured_${DateTime.now().millisecondsSinceEpoch}.jpg";
                    if (_nameController.text.isEmpty) {
                      _nameController.text = "مستند كاميرا";
                    }
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: TfcColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.camera_alt),
                label: const Text("التقاط الصورة", style: TextStyle(fontWeight: FontWeight.bold)),
              )
            else
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _cameraCaptured = false;
                    _selectedFileName = null;
                    _selectedFileUrl = null;
                  });
                },
                icon: const Icon(Icons.refresh, color: TfcColors.secondary),
                label: const Text("إعادة المحاولة", style: TextStyle(color: TfcColors.secondary)),
              ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: () {
                setState(() {
                  _showCamera = false;
                  _cameraCaptured = false;
                });
              },
              child: const Text("رجوع للخيارات", style: TextStyle(color: Colors.white60)),
            ),
          ],
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: SingleChildScrollView(
          child: SizedBox(
            width: 480,
            child: GlassCard(
              padding: const EdgeInsets.all(24),
              borderColor: TfcColors.primary.withValues(alpha: 0.15),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      textDirection: TextDirection.rtl,
                      children: [
                        Text(
                          widget.initialName != null ? "تعديل المستند" : "رفع مستند جديد",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: TfcColors.primary),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12, height: 24),

                    // Document Name Input
                    const Text(
                      "اسم المستند",
                      style: TextStyle(fontSize: 12, color: TfcColors.onSurfaceVariant),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        hintText: "مثال: الهوية الوطنية، كشف حساب بنكي...",
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "الرجاء إدخال اسم المستند";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // File picker options or camera simulator
                    if (!_showCamera) ...[
                      const Text(
                        "طريقة الرفع",
                        style: TextStyle(fontSize: 12, color: TfcColors.onSurfaceVariant),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // Device Option
                          Expanded(
                            child: InkWell(
                              onTap: _simulateDeviceSelection,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                height: 90,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.02),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.computer, color: TfcColors.secondary, size: 28),
                                    SizedBox(height: 8),
                                    Text("من الجهاز", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Camera Option
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _showCamera = true;
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                height: 90,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.02),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.camera_alt, color: TfcColors.primary, size: 28),
                                    SizedBox(height: 8),
                                    Text("من الكاميرا", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      _buildCameraSim(),
                    ],

                    // Selected File info & Progress Indicator
                    if (_selectedFileName != null && !_showCamera) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: TfcColors.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: TfcColors.primary.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          textDirection: TextDirection.rtl,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _selectedFileName!,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                    textDirection: TextDirection.rtl,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _isUploading ? "جاري رفع الملف..." : "تم الرفع بنجاح",
                                    style: TextStyle(color: _isUploading ? TfcColors.secondary : TfcColors.primary, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              _isUploading ? Icons.cloud_upload : Icons.cloud_done,
                              color: _isUploading ? TfcColors.secondary : TfcColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_isUploading) ...[
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _uploadProgress,
                              backgroundColor: Colors.white10,
                              color: TfcColors.primary,
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "${(_uploadProgress * 100).toInt()}%",
                            style: const TextStyle(fontSize: 10, color: TfcColors.primary, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("إلغاء", style: TextStyle(color: Colors.white60)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: (_selectedFileName == null || _isUploading)
                              ? null
                              : () {
                                  if (_formKey.currentState!.validate()) {
                                    widget.onUploadComplete(
                                      _nameController.text,
                                      _selectedFileUrl ?? "",
                                    );
                                    Navigator.pop(context);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TfcColors.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text("حفظ المستند", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
