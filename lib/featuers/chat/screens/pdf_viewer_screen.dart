import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/widgets/global.dart';

class PdfViewerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;

  const PdfViewerScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late PdfViewerController _pdfViewerController;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgColor.bgWhite,
      appBar: AppBar(
        title: Text(
          widget.fileName,
          style: AppTypography.h4(context).copyWith(
            color: AppColors.textColor.textBlackColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.bgColor.bgWhite,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: customeBackArrowBalck(context, isBackBlack: true),
        ),
        actions: [
          IconButton(
            onPressed: () {
              _pdfViewerController.zoomLevel = 1.0;
            },
            icon: Icon(
              Icons.zoom_out_map,
              color: AppColors.textColor.textBlackColor,
            ),
          ),
        ],
      ),
      body:
          File(widget.filePath).existsSync()
              ? SfPdfViewer.file(
                File(widget.filePath),
                controller: _pdfViewerController,
                enableDoubleTapZooming: true,
                enableTextSelection: true,
                canShowScrollHead: true,
                canShowScrollStatus: true,
                canShowPaginationDialog: true,
              )
              : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppColors.textColor.textErrorColor1,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'PDF file not found',
                      style: AppTypography.h4(
                        context,
                      ).copyWith(color: AppColors.textColor.textErrorColor1),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The PDF file could not be loaded',
                      style: AppTypography.buttonText(
                        context,
                      ).copyWith(color: AppColors.textColor.text3A3333),
                    ),
                  ],
                ),
              ),
    );
  }
}
