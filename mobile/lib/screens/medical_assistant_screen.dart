import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_texts.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/medi_go_theme.dart';

class MedicalAssistantScreen extends StatefulWidget {
  const MedicalAssistantScreen({super.key});

  @override
  State<MedicalAssistantScreen> createState() => _MedicalAssistantScreenState();
}

class _MedicalAssistantScreenState extends State<MedicalAssistantScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _messages = [];
  int? _conversationId;
  String? _error;
  bool _loadingHistory = true;
  bool _loadingMessages = false;
  bool _startingConversation = false;
  bool _sending = false;
  bool _emergency = false;

  String get _language {
    final languageCode = Localizations.localeOf(context).languageCode;
    return switch (languageCode) {
      'ar' => 'ar',
      'en' => 'en',
      _ => 'fr',
    };
  }

  String _text(String key) => AppTexts.of(context, key);

  String _apiError(ApiException error) {
    final key = switch (error.code) {
      'medical_ai_key_missing' => 'assistant_ai_key_missing',
      'medical_ai_provider_unsupported' => 'assistant_ai_provider_unsupported',
      'medical_ai_model_missing' => 'assistant_ai_model_missing',
      'medical_ai_model_unsupported' ||
      'medical_ai_model_unavailable' => 'assistant_model_error',
      'medical_chat_key_missing' => 'assistant_encryption_missing',
      'medical_chat_key_invalid' => 'assistant_encryption_invalid',
      'medical_ai_credentials_rejected' => 'assistant_provider_auth_error',
      'medical_ai_network_error' ||
      'medical_ai_timeout' ||
      'medical_ai_endpoint_invalid' ||
      'medical_ai_endpoint_insecure' => 'assistant_provider_network_error',
      'medical_ai_rate_limited' => 'assistant_provider_busy',
      'medical_ai_provider_error' ||
      'medical_ai_invalid_response' ||
      'medical_assistant_error' => 'assistant_server_error',
      _ when error.statusCode == 401 || error.statusCode == 403 =>
        'assistant_auth_error',
      _ when error.statusCode >= 500 => 'assistant_server_error',
      _ => 'assistant_error',
    };
    return _text(key);
  }

  @override
  void initState() {
    super.initState();
    if (context.read<AuthProvider>().role == 'patient') {
      _loadHistory();
    } else {
      _loadingHistory = false;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory({bool openLatest = true}) async {
    if (openLatest) {
      setState(() {
        _loadingHistory = true;
        _error = null;
      });
    }
    try {
      final response = await ApiService.get('/medical-assistant/conversations');
      final conversations = List<Map<String, dynamic>>.from(
        response['conversations'] ?? const [],
      );
      if (!mounted) return;
      setState(() => _conversations = conversations);
      if (openLatest && conversations.isNotEmpty) {
        await _openConversation(
          int.parse(conversations.first['id'].toString()),
        );
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = _apiError(error));
    } finally {
      if (mounted && openLatest) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _startConversation() async {
    setState(() {
      _startingConversation = true;
      _error = null;
      _messages = [];
      _conversationId = null;
      _emergency = false;
    });
    try {
      final response = await ApiService.post(
        '/medical-assistant/conversations',
        {'language': _language},
        timeout: const Duration(seconds: 45),
      );
      final conversation = Map<String, dynamic>.from(
        response['conversation'] as Map,
      );
      final message = Map<String, dynamic>.from(response['message'] as Map);
      if (!mounted) return;
      setState(() {
        _conversationId = int.parse(conversation['id'].toString());
        _messages = [message];
      });
      await _loadHistory(openLatest: false);
      _scrollToLatest();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = _apiError(error));
    } catch (_) {
      if (mounted) setState(() => _error = _text('assistant_error'));
    } finally {
      if (mounted) setState(() => _startingConversation = false);
    }
  }

  Future<void> _openConversation(int id) async {
    setState(() {
      _conversationId = id;
      _loadingMessages = true;
      _error = null;
    });
    try {
      final response = await ApiService.get(
        '/medical-assistant/conversations/$id/messages',
      );
      if (!mounted) return;
      setState(
        () => _messages = List<Map<String, dynamic>>.from(
          response['messages'] ?? const [],
        ),
      );
      _scrollToLatest();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = _apiError(error));
    } finally {
      if (mounted) setState(() => _loadingMessages = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final conversationId = _conversationId;
    if (text.isEmpty || conversationId == null || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final response = await ApiService.post(
        '/medical-assistant/conversations/$conversationId/messages',
        {'message': text, 'language': _language},
        timeout: const Duration(seconds: 45),
      );
      final message = Map<String, dynamic>.from(response['message'] as Map);
      if (!mounted) return;
      setState(() {
        _messages = [
          ..._messages,
          {
            'role': 'user',
            'content': text,
            'created_at': DateTime.now().toIso8601String(),
          },
          message,
        ];
        _emergency = response['emergency'] == true;
      });
      _messageController.clear();
      await _loadHistory(openLatest: false);
      _scrollToLatest();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = _apiError(error));
    } catch (_) {
      if (mounted) setState(() => _error = _text('assistant_error'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _showHistory() async {
    final selectedId = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.65,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _text('assistant_history'),
                        style: Theme.of(sheetContext).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: _text('assistant_new_chat'),
                      onPressed: () => Navigator.pop(sheetContext, -1),
                      icon: const Icon(Icons.add_comment_outlined),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _conversations.isEmpty
                    ? Center(child: Text(_text('assistant_no_history')))
                    : ListView.builder(
                        itemCount: _conversations.length,
                        itemBuilder: (context, index) {
                          final conversation = _conversations[index];
                          final id = int.tryParse(
                            conversation['id'].toString(),
                          );
                          return ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.chat_bubble_outline),
                            ),
                            title: Text(
                              conversation['preview']?.toString().isNotEmpty ==
                                      true
                                  ? conversation['preview'].toString()
                                  : _text('medical_assistant'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              _formatTimestamp(conversation['updated_at']),
                            ),
                            onTap: id == null
                                ? null
                                : () => Navigator.pop(sheetContext, id),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || selectedId == null) return;
    if (selectedId == -1) {
      await _startConversation();
    } else {
      await _openConversation(selectedId);
    }
  }

  Future<void> _requestConsultation() async {
    final conversationId = _conversationId;
    if (conversationId == null) return;
    try {
      final response = await ApiService.get('/medical-assistant/doctors');
      final doctors = List<Map<String, dynamic>>.from(
        response['doctors'] ?? const [],
      );
      if (!mounted) return;
      if (doctors.isEmpty) {
        _showMessage(_text('assistant_no_doctors'));
        return;
      }
      final selection = await showDialog<_ConsultationSelection>(
        context: context,
        builder: (_) => _ConsultationRequestDialog(
          doctors: doctors,
          text: _text,
          initialSummary: _messages
              .where((message) => message['role'] == 'user')
              .map((message) => message['content']?.toString() ?? '')
              .where((message) => message.isNotEmpty)
              .join('\n'),
        ),
      );
      if (selection == null || !mounted) return;
      await ApiService.post(
        '/medical-assistant/conversations/$conversationId/consultation-requests',
        {
          'doctor_id': selection.doctorId,
          'share_summary': selection.shareSummary,
          if (selection.shareSummary) 'symptom_summary': selection.summary,
        },
      );
      if (mounted) _showMessage(_text('assistant_request_sent'));
    } on ApiException catch (error) {
      if (mounted) _showMessage(_apiError(error), isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? MediGoTheme.heartRed
            : MediGoTheme.successGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (context.watch<AuthProvider>().role != 'patient') {
      return Scaffold(
        appBar: AppBar(title: Text(_text('medical_assistant'))),
        body: Center(child: Text(_text('assistant_patient_only'))),
      );
    }
    return Scaffold(
      backgroundColor: MediGoTheme.backgroundStart,
      appBar: AppBar(
        backgroundColor: MediGoTheme.cardSurface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _text('medical_assistant'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            Text(
              _text('medical_assistant_subtitle'),
              style: const TextStyle(
                fontSize: 11,
                color: MediGoTheme.secondaryGrey,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _text('assistant_history'),
            onPressed: _loadingHistory || _sending || _startingConversation
                ? null
                : _showHistory,
            icon: const Icon(Icons.history_rounded),
          ),
          IconButton(
            tooltip: _text('assistant_new_chat'),
            onPressed: _startingConversation || _sending
                ? null
                : _startConversation,
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          _safetyNotice(),
          Expanded(child: _buildMessages()),
          if (_error != null) _errorMessage(),
          if (_conversationId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  onPressed: _sending || _startingConversation
                      ? null
                      : _requestConsultation,
                  icon: const Icon(Icons.medical_services_outlined, size: 18),
                  label: Text(_text('assistant_request_doctor')),
                ),
              ),
            ),
          _composer(),
        ],
      ),
    );
  }

  Widget _safetyNotice() => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _emergency ? const Color(0xFFFFECEC) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: _emergency ? MediGoTheme.heartRed : MediGoTheme.cardBorder,
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          _emergency ? Icons.warning_amber_rounded : Icons.shield_outlined,
          color: _emergency ? MediGoTheme.heartRed : MediGoTheme.primaryBlue,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _text('assistant_privacy_notice'),
                style: const TextStyle(
                  color: MediGoTheme.darkNavy,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _text('assistant_medical_disclaimer'),
                style: const TextStyle(
                  color: MediGoTheme.secondaryGrey,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _text('assistant_emergency_notice'),
                style: TextStyle(
                  color: _emergency
                      ? MediGoTheme.heartRed
                      : MediGoTheme.secondaryGrey,
                  fontSize: 11,
                  height: 1.4,
                  fontWeight: _emergency ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildMessages() {
    if (_loadingHistory || _loadingMessages || _startingConversation) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(_text('assistant_loading')),
          ],
        ),
      );
    }
    if (_conversationId == null || _messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.support_agent_rounded,
                color: MediGoTheme.primaryBlue,
                size: 54,
              ),
              const SizedBox(height: 16),
              Text(
                _text('assistant_welcome'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: MediGoTheme.darkNavy,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _startConversation,
                icon: const Icon(Icons.chat_outlined),
                label: Text(_text('assistant_new_chat')),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      itemCount: _messages.length + (_sending ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) return _typingIndicator();
        return _messageBubble(_messages[index]);
      },
    );
  }

  Widget _messageBubble(Map<String, dynamic> message) {
    final isUser = message['role'] == 'user';
    final content = message['content']?.toString() ?? '';
    final direction = RegExp(r'[\u0600-\u06FF]').hasMatch(content)
        ? TextDirection.rtl
        : TextDirection.ltr;
    return Align(
      alignment: isUser
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isUser ? MediGoTheme.primaryBlue : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isUser ? 16 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 16),
            ),
            border: isUser ? null : Border.all(color: MediGoTheme.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Directionality(
                textDirection: direction,
                child: SelectableText(
                  content,
                  style: TextStyle(
                    color: isUser ? Colors.white : MediGoTheme.darkNavy,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  _formatTimestamp(message['created_at']),
                  style: TextStyle(
                    color: isUser ? Colors.white70 : MediGoTheme.secondaryGrey,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typingIndicator() => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MediGoTheme.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 9),
          Text(_text('assistant_typing')),
        ],
      ),
    ),
  );

  Widget _errorMessage() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            _error!,
            style: const TextStyle(color: MediGoTheme.heartRed),
          ),
        ),
        TextButton(
          onPressed: _conversationId == null
              ? _startConversation
              : _messageController.text.trim().isNotEmpty
              ? _sendMessage
              : () => _openConversation(_conversationId!),
          child: Text(_text('assistant_retry')),
        ),
      ],
    ),
  );

  Widget _composer() => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      color: Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              minLines: 1,
              maxLines: 5,
              maxLength: 4000,
              textDirection: _language == 'ar'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: _text('assistant_input_hint'),
                counterText: '',
                filled: true,
                fillColor: MediGoTheme.backgroundStart,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: _text('assistant_send'),
            onPressed: _sending || _conversationId == null
                ? null
                : _sendMessage,
            icon: _sending
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded),
          ),
        ],
      ),
    ),
  );

  String _formatTimestamp(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday =
        date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
    final time =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    if (isToday) return '${_text('assistant_today')} $time';
    if (isYesterday) return '${_text('assistant_yesterday')} $time';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} $time';
  }
}

class _ConsultationSelection {
  const _ConsultationSelection({
    required this.doctorId,
    required this.shareSummary,
    required this.summary,
  });

  final int doctorId;
  final bool shareSummary;
  final String summary;
}

class _ConsultationRequestDialog extends StatefulWidget {
  const _ConsultationRequestDialog({
    required this.doctors,
    required this.text,
    required this.initialSummary,
  });

  final List<Map<String, dynamic>> doctors;
  final String Function(String key) text;
  final String initialSummary;

  @override
  State<_ConsultationRequestDialog> createState() =>
      _ConsultationRequestDialogState();
}

class _ConsultationRequestDialogState
    extends State<_ConsultationRequestDialog> {
  int? _doctorId;
  bool _shareSummary = false;
  late final TextEditingController _summaryController = TextEditingController(
    text: widget.initialSummary,
  );

  @override
  void dispose() {
    _summaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.text('assistant_request_doctor')),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.text('assistant_request_intro')),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _doctorId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: widget.text('assistant_select_doctor'),
            ),
            items: widget.doctors.map((doctor) {
              final id = int.tryParse(doctor['id'].toString());
              return DropdownMenuItem<int>(
                value: id,
                child: Text(
                  doctor['name']?.toString() ??
                      widget.text('assistant_select_doctor'),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (id) => setState(() => _doctorId = id),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _shareSummary,
            onChanged: (value) =>
                setState(() => _shareSummary = value ?? false),
            title: Text(widget.text('assistant_share_summary')),
            subtitle: Text(widget.text('assistant_share_summary_notice')),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (_shareSummary) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _summaryController,
              minLines: 3,
              maxLines: 6,
              maxLength: 4000,
              textDirection: Directionality.of(context),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: widget.text('assistant_share_summary'),
                hintText: widget.text('assistant_summary_hint'),
              ),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(widget.text('cancel')),
      ),
      FilledButton(
        onPressed:
            _doctorId == null ||
                (_shareSummary && _summaryController.text.trim().isEmpty)
            ? null
            : () => Navigator.pop(
                context,
                _ConsultationSelection(
                  doctorId: _doctorId!,
                  shareSummary: _shareSummary,
                  summary: _summaryController.text.trim(),
                ),
              ),
        child: Text(widget.text('assistant_request_submit')),
      ),
    ],
  );
}
