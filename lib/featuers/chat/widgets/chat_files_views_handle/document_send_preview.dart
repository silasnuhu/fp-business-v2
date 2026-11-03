import 'dart:io';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';

/// Full-screen preview of a picked document before it is sent. PDFs are
/// rendered inline; other types show a file card. Pops `true` when the user
/// taps send; closing or going back pops `false`/null.
class DocumentSendPreviewScreen extends StatefulWidget {
  final File document;

  const DocumentSendPreviewScreen({super.key, required this.document});

  static Future<bool> show(BuildContext context, File document) async {
    final confirmed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => DocumentSendPreviewScreen(document: document),
      ),
    );
    return confirmed == true;
  }

  @override
  State<DocumentSendPreviewScreen> createState() =>
      _DocumentSendPreviewScreenState();
}

class _DocumentSendPreviewScreenState extends State<DocumentSendPreviewScreen> {
  final PdfViewerController _pdfController = PdfViewerController();
  bool _pdfFailed = false;
  int? _sizeBytes;

  String get _fileName =>
      widget.document.path.split(Platform.pathSeparator).last;

  String get _extension {
    final dot = _fileName.lastIndexOf('.');
    return dot == -1 ? '' : _fileName.substring(dot + 1).toLowerCase();
  }

  bool get _isPdf => _extension == 'pdf';

  @override
  void initState() {
    super.initState();
    widget.document.length().then((size) {
      if (mounted) setState(() => _sizeBytes = size);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData get _icon {
    switch (_extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'txt':
        return Icons.article;
      default:
        return Icons.insert_drive_file;
    }
  }

  Widget _buildFileCard(BuildContext context) {
    final primary = AppColors.appPriSecColor.primaryColor;
    final details = [
      if (_extension.isNotEmpty) _extension.toUpperCase(),
      if (_sizeBytes != null) _formatSize(_sizeBytes!),
    ].join(' • ');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(_icon, size: 72, color: primary),
            ),
            const SizedBox(height: 16),
            Text(
              _fileName,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.mediumText(context).copyWith(
                fontWeight: FontWeight.w600,
                color: AppThemeManage.appTheme.textColor,
              ),
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                details,
                style: AppTypography.captionText(
                  context,
                ).copyWith(color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.appPriSecColor.primaryColor;

    return Scaffold(
      backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
      appBar: AppBar(
        backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: AppThemeManage.appTheme.textColor),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: Text(
          _fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.h4(context).copyWith(
            fontWeight: FontWeight.w600,
            color: AppThemeManage.appTheme.textColor,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child:
                  _isPdf && !_pdfFailed
                      ? SfPdfViewer.file(
                        widget.document,
                        controller: _pdfController,
                        canShowScrollHead: true,
                        canShowScrollStatus: true,
                        // Unreadable/protected PDF: fall back to the card.
                        onDocumentLoadFailed: (_) {
                          if (mounted) setState(() => _pdfFailed = true);
                        },
                      )
                      : _buildFileCard(context),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  if (_isPdf && !_pdfFailed)
                    Expanded(
                      child: Text(
                        _sizeBytes != null ? _formatSize(_sizeBytes!) : '',
                        style: AppTypography.captionText(
                          context,
                        ).copyWith(color: Colors.grey[600]),
                      ),
                    )
                  else
                    const Spacer(),
                  FloatingActionButton(
                    heroTag: 'document_send_preview_fab',
                    tooltip: AppString.send,
                    backgroundColor: primary,
                    shape: const CircleBorder(),
                    onPressed: () => Navigator.pop(context, true),
                    child: Icon(
                      Icons.send,
                      color: ThemeColorPalette.getTextColor(primary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
