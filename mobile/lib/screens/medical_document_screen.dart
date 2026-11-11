import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_texts.dart';
import '../services/api_service.dart';
import '../theme/medi_go_theme.dart';

class MedicalDocumentScreen extends StatefulWidget {
  const MedicalDocumentScreen({
    super.key,
    required this.title,
    required this.type,
    required this.date,
    required this.fileUrl,
  });

  final String title;
  final String type;
  final String date;
  final String fileUrl;

  @override
  State<MedicalDocumentScreen> createState() => _MedicalDocumentScreenState();
}

class _MedicalDocumentScreenState extends State<MedicalDocumentScreen> {
  String? _openError;
  String? _mimeType;
  String? _typeError;
  bool _checkingType = false;

  @override
  void initState() {
    super.initState();
    _detectDocumentType();
  }

  Uri? get _documentUri {
    try {
      return Uri.parse(ApiService.absoluteFileUrl(widget.fileUrl));
    } on FormatException {
      return null;
    }
  }

  String get _extension {
    final uri = _documentUri;
    if (uri == null) return '';
    final filename = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    final dot = filename.lastIndexOf('.');
    return dot < 0 ? '' : filename.substring(dot + 1).toLowerCase();
  }

  bool get _isImage =>
      const {'jpg', 'jpeg', 'png'}.contains(_extension) ||
      (_mimeType?.startsWith('image/') ?? false);
  bool get _isPdf =>
      _extension == 'pdf' || (_mimeType?.contains('pdf') ?? false);

  Future<void> _detectDocumentType() async {
    final uri = _documentUri;
    if (uri == null || _extension.isNotEmpty) return;
    setState(() => _checkingType = true);
    try {
      final response = await http
          .head(uri)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw FormatException('HTTP ${response.statusCode}');
      }
      if (!mounted) return;
      setState(() {
        _mimeType = response.headers['content-type']?.toLowerCase();
        _checkingType = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _typeError = error.toString();
        _checkingType = false;
      });
    }
  }

  Future<void> _openPdf(Uri uri) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        setState(
          () => _openError = AppTexts.of(context, 'document_open_failed'),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _openError =
              '${AppTexts.of(context, 'document_open_failed')}: $error',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uri = _documentUri;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Column(
          children: [
            Card(
              margin: const EdgeInsets.all(16),
              child: ListTile(
                leading: Icon(
                  _isImage ? Icons.image_outlined : Icons.description_outlined,
                  color: MediGoTheme.primaryBlue,
                ),
                title: Text(widget.title),
                subtitle: Text(
                  '${widget.type} · ${widget.date}',
                  softWrap: true,
                ),
              ),
            ),
            Expanded(
              child: uri == null
                  ? _message(
                      context,
                      Icons.broken_image_outlined,
                      AppTexts.of(context, 'document_url_invalid'),
                    )
                  : _isImage
                  ? Center(
                      child: InteractiveViewer(
                        child: Image.network(
                          uri.toString(),
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            final total = progress.expectedTotalBytes;
                            return Center(
                              child: CircularProgressIndicator(
                                value: total == null
                                    ? null
                                    : progress.cumulativeBytesLoaded / total,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => _message(
                            context,
                            Icons.broken_image_outlined,
                            '${AppTexts.of(context, 'document_load_failed')}: $error',
                          ),
                          fit: BoxFit.contain,
                        ),
                      ),
                    )
                  : _checkingType
                  ? const Center(child: CircularProgressIndicator())
                  : _typeError != null
                  ? _message(
                      context,
                      Icons.error_outline,
                      '${AppTexts.of(context, 'document_load_failed')}: $_typeError',
                    )
                  : _message(
                      context,
                      Icons.picture_as_pdf_outlined,
                      _isPdf
                          ? AppTexts.of(context, 'pdf_external_viewer')
                          : AppTexts.of(context, 'unsupported_document_type'),
                    ),
            ),
            if (uri != null && !_isImage)
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openPdf(uri),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(AppTexts.of(context, 'open_document')),
                  ),
                ),
              ),
            if (_openError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  _openError!,
                  style: const TextStyle(color: MediGoTheme.heartRed),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _message(BuildContext context, IconData icon, String message) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: MediGoTheme.secondaryGrey),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}
