import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import '../../models/nota.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/formatters.dart';
import '../../services/chat_service.dart';
import '../../services/nota_service.dart';
import '../../services/cancellation_service.dart';
import '../cancellation/cancel_decision_card.dart';
import '../cancellation/tukang_cancel_flow_dialog.dart';
import 'timer_banner_widget.dart';
import 'nota_card_widget.dart';
import 'create_nota_dialog.dart';

class ChatScreen extends StatefulWidget {
  final String jobId;

  const ChatScreen({
    super.key,
    required this.jobId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final NotaService _notaService = NotaService();
  final CancellationService _cancellationService = CancellationService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  JobChatContext? _contextData;
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadContext() async {
    try {
      final contextData = await _chatService.getChatContext(widget.jobId);
      if (mounted) {
        setState(() {
          _contextData = contextData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _handleSendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    _messageController.clear();
    setState(() => _isSending = true);

    try {
      await _chatService.sendMessage(
        jobId: widget.jobId,
        content: text,
        messageType: ChatMessageType.text,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim pesan: $e'),
            backgroundColor: AppColors.dangerCrimson,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _handleOpenCreateNota({required bool isRevision}) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => CreateNotaDialog(
        jobId: widget.jobId,
        isRevision: isRevision,
        currentApprovedTotal: _contextData?.activeNota?.totalAmount,
        onSubmit: ({
          required List<NotaItem> items,
          required int totalAmount,
          required PaymentMethod paymentMethod,
          String? note,
        }) async {
          await _notaService.createNota(
            jobId: widget.jobId,
            items: items,
            totalAmount: totalAmount,
            paymentMethod: paymentMethod,
            note: note,
          );
        },
      ),
    );

    if (created == true) {
      _loadContext();
      _scrollToBottom();
    }
  }

  void _openTukangCancelDialog() {
    TukangCancelFlowDialog.show(
      context,
      jobId: widget.jobId,
      cancellationService: _cancellationService,
      onSuccess: _loadContext,
    );
  }

  Future<void> _handleApproveNota(Nota nota) async {
    final isRevision = nota.version > 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isRevision ? 'Setujui Revisi Nota?' : 'Setujui Nota Digital?',
          style: AppTypography.headingSmall,
        ),
        content: Text(
          isRevision
              ? 'Anda akan menyetujui perubahan biaya menjadi ${Formatters.formatCurrency(nota.totalAmount)}. Nota ini akan menjadi Nota Sah baru yang berlaku.'
              : 'Anda akan menyetujui Nota senilai ${Formatters.formatCurrency(nota.totalAmount)}. Setelah disetujui, harga terkunci dan mitra tukang dapat segera berangkat.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.successGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size(110, 42),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Setujui'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _notaService.respondNota(notaId: nota.id, approve: true);
      _loadContext();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isRevision
                  ? 'Revisi Nota berhasil disetujui'
                  : 'Nota Digital telah disetujui',
            ),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyetujui nota: $e'),
            backgroundColor: AppColors.dangerCrimson,
          ),
        );
      }
    }
  }

  Future<void> _handleRejectNota(Nota nota) async {
    final isRevision = nota.version > 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isRevision ? 'Tolak Revisi Nota?' : 'Tolak Nota Digital?',
          style: AppTypography.headingSmall,
        ),
        content: Text(
          isRevision
              ? 'Jika Anda menolak revisi ini, Nota Sah sebelumnya (${Formatters.formatCurrency(nota.previousApprovedTotal ?? 0)}) tetap berlaku.'
              : 'Nota akan ditolak. Anda dapat mendiskusikan kembali rincian pekerjaan dan biaya bersama mitra tukang.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerCrimson,
              foregroundColor: Colors.white,
              minimumSize: const Size(110, 42),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _notaService.respondNota(notaId: nota.id, approve: false);
      _loadContext();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nota telah ditolak'),
            backgroundColor: AppColors.primaryNavy,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menolak nota: $e'),
            backgroundColor: AppColors.dangerCrimson,
          ),
        );
      }
    }
  }

  Future<void> _handleCancelRevision(Nota nota) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Tarik Revisi Nota?',
          style: AppTypography.headingSmall,
        ),
        content: const Text(
          'Revisi Nota yang belum dijawab pelanggan akan dibatalkan, dan Nota Sah sebelumnya tetap berlaku.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Kembali'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerCrimson,
              foregroundColor: Colors.white,
              minimumSize: const Size(120, 42),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tarik Revisi'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _notaService.cancelRevision(notaId: nota.id);
      _loadContext();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Revisi Nota berhasil ditarik kembali.'),
            backgroundColor: AppColors.primaryNavy,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menarik revisi: $e'),
            backgroundColor: AppColors.dangerCrimson,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ruang Diskusi')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_contextData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ruang Diskusi')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 40,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage ?? 'Gagal memuat percakapan',
                  style: AppTypography.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadContext,
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isTukang = _contextData!.isTukang;
    final isUser = _contextData!.isUser;
    final status = _contextData!.status;
    final otherName = _contextData!.otherUserName;
    final otherPhone = _contextData!.otherUserPhone;

    final canCreateInitialNota = isTukang &&
        status == 'NEGOTIATING' &&
        _contextData!.pendingNota == null;
    final canCreateRevisionNota = isTukang &&
        (status == 'ARRIVED' || status == 'WORKING') &&
        _contextData!.pendingNota == null;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor:
                  isUser ? AppColors.tukangBadgeBg : AppColors.userBadgeBg,
              child: Icon(
                isUser ? Icons.handyman_outlined : Icons.person_outline_rounded,
                size: 18,
                color: isUser
                    ? AppColors.tukangBadgeText
                    : AppColors.userBadgeText,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    otherName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _contextData!.areaLabel,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (otherPhone != null && otherPhone.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.phone_outlined),
              tooltip: 'Kontak Telepon',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Kontak: $otherPhone')),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan',
            onPressed: _loadContext,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            TimerBannerWidget(
              chatContext: _contextData!,
              onRefreshNeeded: _loadContext,
            ),
            if (_contextData?.status == 'CANCEL_PENDING')
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: CancelDecisionCard(
                  jobId: widget.jobId,
                  isTukang: _contextData!.isTukang,
                  cancellationService: _cancellationService,
                  onDecisionResolved: _loadContext,
                ),
              ),
            Expanded(
              child: StreamBuilder<List<ChatMessage>>(
                stream: _chatService.streamMessages(widget.jobId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final messages = snapshot.data ?? [];

                  if (messages.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceWhite,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.borderLight,
                                ),
                              ),
                              child: const Icon(
                                Icons.forum_outlined,
                                size: 28,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Mulai Diskusi Pekerjaan',
                              style: AppTypography.headingSmall,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Diskusikan keluhan, jadwal pengerjaan, dan rincian biaya Nota Digital di ruang ini.',
                              style: AppTypography.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      return _buildMessageItem(msg);
                    },
                  );
                },
              ),
            ),
            if (canCreateInitialNota || canCreateRevisionNota)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceWhite,
                  border: Border(
                    top: BorderSide(color: AppColors.borderLight),
                  ),
                ),
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _handleOpenCreateNota(isRevision: canCreateRevisionNota),
                  icon: Icon(
                    canCreateRevisionNota
                        ? Icons.edit_note_rounded
                        : Icons.receipt_long_outlined,
                    size: 18,
                  ),
                  label: Text(
                    canCreateRevisionNota
                        ? 'Ajukan Revisi Nota'
                        : 'Buat Nota Digital',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canCreateRevisionNota
                        ? AppColors.warningAmber
                        : AppColors.trustCobalt,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
              ),
            if (_contextData?.status == 'NOTA_APPROVED' &&
                _contextData!.isTukang)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                color: AppColors.surfaceWhite,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.dangerCrimson,
                    side: BorderSide(
                      color: AppColors.dangerCrimson.withValues(alpha: 0.4),
                    ),
                    minimumSize: const Size.fromHeight(42),
                  ),
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Ajukan Pembatalan Tugas'),
                  onPressed: _openTukangCancelDialog,
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                color: AppColors.surfaceWhite,
                border: Border(
                  top: BorderSide(color: AppColors.borderLight),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 4,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Tulis pesan...',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: AppColors.borderLight,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: AppColors.borderLight,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: AppColors.trustCobalt,
                            width: 1.5,
                          ),
                        ),
                        filled: true,
                        fillColor: AppColors.backgroundLight,
                      ),
                      onSubmitted: (_) => _handleSendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: AppColors.trustCobalt,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _isSending ? null : _handleSendMessage,
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: _isSending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                        ),
                      ),
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

  Widget _buildMessageItem(ChatMessage msg) {
    if (msg.isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Text(
            msg.content ?? '',
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (msg.isNotaCard || msg.isNotaRevisionAlert) {
      final nota = _contextData?.pendingNota?.id == msg.notaId
          ? _contextData?.pendingNota
          : _contextData?.activeNota;

      if (nota != null) {
        return NotaCardWidget(
          nota: nota,
          isUser: _contextData!.isUser,
          onApprove: _handleApproveNota,
          onReject: _handleRejectNota,
          onCancelRevision: _handleCancelRevision,
        );
      }
    }

    final isMe = _contextData!.isUser
        ? (msg.senderId == _contextData!.userId)
        : (msg.senderId == _contextData!.lockedTukangId);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.76,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primaryNavy : AppColors.surfaceWhite,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: isMe ? null : Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (msg.content != null && msg.content!.isNotEmpty)
              Text(
                msg.content!,
                style: TextStyle(
                  color: isMe ? Colors.white : AppColors.textPrimary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              Formatters.formatDateTime(msg.createdAt),
              style: TextStyle(
                color: isMe
                    ? Colors.white.withValues(alpha: 0.65)
                    : AppColors.textMuted,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
