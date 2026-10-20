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
        title:
            Text(isRevision ? 'Setujui Revisi Nota?' : 'Setujui Nota Digital?'),
        content: Text(
          isRevision
              ? 'Anda akan menyetujui perubahan biaya menjadi ${Formatters.formatCurrency(nota.totalAmount)}. '
                  'Nota ini akan menjadi Nota Sah baru yang mengikat.'
              : 'Anda akan menyetujui Nota senilai ${Formatters.formatCurrency(nota.totalAmount)}. '
                  'Setelah disetujui, Nota ini TERKUNCI (immutable) dan status beralih ke NOTA_APPROVED (BR-05).',
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
            content: Text(isRevision
                ? 'Revisi Nota berhasil disetujui'
                : 'Nota Sah terbentuk (Terkunci)'),
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
        title: Text(isRevision ? 'Tolak Revisi Nota?' : 'Tolak Nota Digital?'),
        content: Text(
          isRevision
              ? 'Jika Anda menolak revisi ini, Nota Sah sebelumnya (${Formatters.formatCurrency(nota.previousApprovedTotal ?? 0)}) tetap berlaku penuh.'
              : 'Nota akan ditolak. Anda dapat mendiskusikan kembali rincian pekerjaan atau biaya dengan tukang di ruang chat.',
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
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tolak Nota'),
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
            backgroundColor: AppColors.trustCobalt,
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
        title: const Text('Tarik Revisi Nota? (BR-08)'),
        content: const Text(
          'Revisi Nota yang masih menunggu jawaban user akan ditarik kembali. '
          'Nota Sah sebelumnya akan tetap berlaku sehingga Anda dapat melanjutkan pekerjaan.',
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
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tarik Revisi (BR-08)'),
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
            backgroundColor: AppColors.trustCobalt,
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
        appBar: AppBar(title: const Text('Ruang Chat')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_contextData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ruang Chat')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorMessage ?? 'Gagal memuat chat'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadContext,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final isTukang = _contextData!.isTukang;
    final isUser = _contextData!.isUser;
    final status = _contextData!.status;
    final otherName = _contextData!.otherUserName;
    final otherPhone = _contextData!.otherUserPhone;

    // Cek apakah tukang bisa buat Nota Awal atau Revisi
    final canCreateInitialNota = isTukang &&
        status == 'NEGOTIATING' &&
        _contextData!.pendingNota == null;
    final canCreateRevisionNota = isTukang &&
        (status == 'ARRIVED' || status == 'WORKING') &&
        _contextData!.pendingNota == null;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor:
                  isUser ? AppColors.tukangBadgeBg : AppColors.userBadgeBg,
              child: Icon(
                isUser ? Icons.handyman : Icons.person,
                size: 20,
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
                        fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _contextData!.areaLabel,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.8)),
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
              tooltip: 'Hubungi Telepon',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Nomor kontak: $otherPhone')),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Perbarui Status',
            onPressed: _loadContext,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Timer Banner (BR-70, BR-31)
            TimerBannerWidget(
              chatContext: _contextData!,
              onRefreshNeeded: _loadContext,
            ),

            // Kartu Keputusan Pembatalan (CANCEL_PENDING - BR-53, BR-55)
            if (_contextData?.jobStatus == JobStatus.cancelPending)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: CancelDecisionCard(
                  jobId: widget.jobId,
                  isTukang: _contextData!.isTukang,
                  cancellationService: _cancellationService,
                  onDecisionResolved: _loadContext,
                ),
              ),

            // 2. Chat Message Stream
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
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Belum ada pesan. Mulai diskusikan rincian pekerjaan di sini.',
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      return _buildMessageItem(msg);
                    },
                  );
                },
              ),
            ),

            // 3. Quick Action Button for Tukang (Create Nota / Create Revision)
            if (canCreateInitialNota || canCreateRevisionNota)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                color: Colors.white,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _handleOpenCreateNota(isRevision: canCreateRevisionNota),
                  icon: Icon(
                      canCreateRevisionNota
                          ? Icons.warning_amber_rounded
                          : Icons.receipt_long,
                      size: 18),
                  label: Text(canCreateRevisionNota
                      ? 'Ajukan Revisi Nota (BR-05)'
                      : 'Buat Nota Digital (BR-04)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canCreateRevisionNota
                        ? AppColors.warningAmber
                        : AppColors.trustCobalt,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),

            // Tombol Batalkan Tugas untuk Tukang saat NOTA_APPROVED (BR-50)
            if (_contextData?.jobStatus == JobStatus.notaApproved && _contextData!.isTukang)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                color: Colors.white,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Batalkan Tugas Sebelum Berangkat (BR-50)'),
                  onPressed: _openTukangCancelDialog,
                ),
              ),

            // 4. Input Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
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
                        hintText: 'Ketik pesan...',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        filled: true,
                        fillColor: AppColors.backgroundLight,
                      ),
                      onSubmitted: (_) => _handleSendMessage(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  CircleAvatar(
                    backgroundColor: AppColors.trustCobalt,
                    radius: 22,
                    child: IconButton(
                      icon: _isSending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.send,
                              color: Colors.white, size: 18),
                      onPressed: _isSending ? null : _handleSendMessage,
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
    // 1. Pesan System Event
    if (msg.isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            msg.content ?? '',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // 2. Pesan Nota Card / Nota Revision Alert
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

    // 3. Pesan Bubble Biasa (Text / Image)
    final isMe = _contextData!.isUser
        ? (msg.senderId == _contextData!.userId)
        : (msg.senderId == _contextData!.lockedTukangId);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppColors.trustCobalt : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
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
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 14,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              Formatters.formatDateTime(msg.createdAt),
              style: TextStyle(
                color: isMe
                    ? Colors.white.withValues(alpha: 0.7)
                    : Colors.grey.shade500,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
