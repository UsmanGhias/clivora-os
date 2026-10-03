import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_service.dart';
import '../../core/utils/contract_content_helper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/services/chat_attachment_service.dart';
import '../../core/services/chat_block_service.dart';
import '../../core/services/vault_service.dart';
import '../../core/cloud/cloud_message_repository.dart';
import '../../core/cloud/supabase_auth_helper.dart';
import '../../core/cloud/supabase_sync_service.dart';
import '../../core/theme/clivora_colors.dart';
import '../../data/providers/app_providers.dart';

/// Simple two-way chat between client and freelancer (Supabase realtime).
class SimpleChatScreen extends ConsumerStatefulWidget {
  const SimpleChatScreen({super.key, required this.isClient});

  final bool isClient;

  @override
  ConsumerState<SimpleChatScreen> createState() => _SimpleChatScreenState();
}

class _SimpleChatScreenState extends ConsumerState<SimpleChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  String? _peerEmail;
  int _lastMessageCount = 0;
  bool _sending = false;

  void _scrollToBottom({bool animate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(max, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      } else {
        _scrollController.jumpTo(max);
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendImage() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    var toEmail = _peerEmail;
    if (toEmail == null || toEmail.isEmpty) {
      toEmail = await _pickPeerEmail(context);
      if (toEmail == null || toEmail.isEmpty) return;
      setState(() => _peerEmail = toEmail);
    }

    final allowed = await ref.read(linkedPeerEmailsProvider(widget.isClient).future);
    if (!allowed.contains(toEmail.trim().toLowerCase())) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You can only message linked contacts on shared projects.')),
        );
      }
      return;
    }

    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 82);
    if (picked == null) return;

    final uid = SupabaseAuthHelper.currentUid;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign in with Google or email to share images.')),
        );
      }
      return;
    }

    try {
      final bytes = await File(picked.path).readAsBytes();
      final url = await ChatAttachmentService.uploadImage(bytes: bytes, uid: uid);

      final plan = await ref.read(planLimitServiceProvider).currentPlan();
      final vaultResult = await VaultService.archiveChatImageBytes(bytes: bytes, plan: plan);
      if (vaultResult.isQuota && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'File vault full (${VaultService.formatSize(vaultResult.used ?? 0)} / ${VaultService.formatSize(vaultResult.limit ?? VaultService.freeLimitBytes)}). Upgrade to Pro for 5 GB.',
            ),
          ),
        );
      }

      await ref.read(cloudMessageRepositoryProvider).sendHybrid(
            fromUser: user,
            toEmail: toEmail,
            subject: '',
            body: ChatAttachmentService.imageBody(url),
          );

      ref.invalidate(chatThreadProvider(ChatThreadKey(peerEmail: toEmail, isClient: widget.isClient)));
      ref.invalidate(unreadBadgeCountProvider);
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('403')
            ? 'Image upload blocked. Update the app or contact support (storage policy).'
            : 'Could not send image: $e';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  Future<void> _send() async {
    if (_sending) return;
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    _sending = true;
    try {

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    var toEmail = _peerEmail;
    if (toEmail == null || toEmail.isEmpty) {
      toEmail = await _pickPeerEmail(context);
      if (toEmail == null || toEmail.isEmpty) return;
      setState(() => _peerEmail = toEmail);
    }

    final allowed = await ref.read(linkedPeerEmailsProvider(widget.isClient).future);
    if (!allowed.contains(toEmail.trim().toLowerCase())) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You can only message linked contacts on shared projects.')),
        );
      }
      return;
    }

    await ref.read(cloudMessageRepositoryProvider).sendHybrid(
          fromUser: user,
          toEmail: toEmail,
          subject: '',
          body: text,
        );

    _inputController.clear();
    ref.invalidate(chatThreadProvider(ChatThreadKey(peerEmail: toEmail, isClient: widget.isClient)));
    ref.invalidate(unreadBadgeCountProvider);
    _scrollToBottom(animate: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<String?> _pickPeerEmail(BuildContext context) async {
    final linked = await ref.read(linkedPeerEmailsProvider(widget.isClient).future);
    if (linked.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isClient
                  ? 'Link your freelancer first (Add your freelancer on the portal).'
                  : 'Add a client or share a project before chatting.',
            ),
          ),
        );
      }
      return null;
    }
    if (linked.length == 1) return linked.first;

    if (!context.mounted) return null;
    return showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(widget.isClient ? 'Choose freelancer' : 'Choose client'),
        children: linked
            .map(
              (email) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, email),
                child: Text(email),
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final accent = widget.isClient ? ClivoraColors.clientAccent : ClivoraColors.primary;

    if (_peerEmail == null && user != null) {
      ref.watch(linkedPeerEmailProvider(widget.isClient)).whenData((email) {
        if (email != null && _peerEmail == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _peerEmail = email);
          });
        }
      });
    }

    final threadKey = ChatThreadKey(peerEmail: _peerEmail ?? '', isClient: widget.isClient);
    final threadAsync = _peerEmail != null && _peerEmail!.isNotEmpty
        ? ref.watch(chatThreadProvider(threadKey))
        : const AsyncValue<List<ChatBubble>>.data([]);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(context).brightness == Brightness.light
                ? ClivoraColors.chipBackground
                : ClivoraColors.darkBorder,
          ),
        ),
        title: Column(
          children: [
            Text(
              widget.isClient ? 'Chat' : 'Client Chat',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            if (_peerEmail != null && _peerEmail!.isNotEmpty)
              Text(
                _peerEmail!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ClivoraColors.textSecondary,
                      fontSize: 12,
                    ),
              ),
          ],
        ),
        actions: [
          if (_peerEmail != null)
            IconButton(
              icon: const Icon(Icons.sync_alt_rounded, size: 20),
              tooltip: 'Switch contact',
              onPressed: () async {
                final email = await _pickPeerEmail(context);
                if (email != null && email.isNotEmpty) {
                  setState(() => _peerEmail = email);
                }
              },
            ),
          if (_peerEmail != null && _peerEmail!.isNotEmpty)
            IconButton(
              tooltip: 'Block contact',
              icon: const Icon(Icons.block, size: 20),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Block contact?'),
                    content: Text('Stop messages with $_peerEmail. You can unblock later from this menu.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Block')),
                    ],
                  ),
                );
                if (ok != true) return;
                final myUid = SupabaseAuthHelper.currentUid;
                if (myUid == null) return;
                final peerUid = await ref.read(supabaseSyncServiceProvider).uidForEmail(_peerEmail!);
                if (peerUid == null || peerUid.isEmpty) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not resolve contact to block')),
                    );
                  }
                  return;
                }
                await ref.read(chatBlockServiceProvider).block(blockerUid: myUid, blockedUid: peerUid);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contact blocked')),
                  );
                  setState(() => _peerEmail = null);
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: threadAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (messages) {
                if (_peerEmail == null || _peerEmail!.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 56, color: accent.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          const Text('Start a conversation', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Text(
                            widget.isClient
                                ? 'Add your freelancer\'s email to discuss projects in real time.'
                                : 'Pick a client email to chat.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 20),
                          OutlinedButton(
                            onPressed: () async {
                              final email = await _pickPeerEmail(context);
                              if (email != null && email.isNotEmpty) {
                                setState(() => _peerEmail = email);
                              }
                            },
                            child: const Text('Choose contact'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet. Say hello!',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }
                if (messages.length != _lastMessageCount) {
                  _lastMessageCount = messages.length;
                  _scrollToBottom();
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) => _Bubble(message: messages[index], accent: accent),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? ClivoraColors.darkBorder
                        : ClivoraColors.borderLight,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Material(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? ClivoraColors.darkBorder
                        : ClivoraColors.chipBackground,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: _sendImage,
                      borderRadius: BorderRadius.circular(12),
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(Icons.image_outlined, color: ClivoraColors.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: Theme.of(context).brightness == Brightness.dark
                            ? ClivoraColors.darkBorder
                            : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: ClivoraColors.borderLight),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: ClivoraColors.borderLight),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: accent, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      maxLines: 3,
                      minLines: 1,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material(
                    color: accent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: _sending ? null : _send,
                      customBorder: const CircleBorder(),
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(Icons.send_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.accent});

  final ChatBubble message;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final align = message.isMine ? Alignment.centerRight : Alignment.centerLeft;
    final bg = message.isMine ? accent : Theme.of(context).cardColor;
    final fg = message.isMine ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final time = DateFormat('h:mm a').format(message.createdAt.toLocal());

    final contractParsed = ContractContentHelper.decode(message.text);
    final displayText = contractParsed.body != message.text || contractParsed.clientSignature != null
        ? contractParsed.body
        : message.text;
    final isContract = contractParsed.clientSignature != null ||
        message.text.contains(ContractContentHelper.metaStart);

    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isMine ? 16 : 4),
            bottomRight: Radius.circular(message.isMine ? 4 : 16),
          ),
          border: message.isMine
              ? null
              : Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? ClivoraColors.darkBorder
                      : ClivoraColors.borderLight,
                ),
          boxShadow: message.isMine
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (ChatAttachmentService.isImageBody(message.text))
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: ChatAttachmentService.imageUrlFromBody(message.text),
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (_, _, _) => Text('Image unavailable', style: TextStyle(color: fg)),
                ),
              )
            else if (isContract) ...[
              Row(
                children: [
                  Icon(Icons.description_outlined, size: 18, color: fg),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      contractParsed.clientSignature != null
                          ? 'Contract signed by ${contractParsed.clientSignature}'
                          : 'Contract agreement',
                      style: TextStyle(color: fg, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              if (displayText.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(displayText, style: TextStyle(color: fg, height: 1.35)),
              ],
            ] else
              Text(displayText, style: TextStyle(color: fg, height: 1.35)),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(time, style: TextStyle(fontSize: 10, color: fg.withValues(alpha: 0.75))),
                if (message.isMine) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.done_all, size: 14, color: fg.withValues(alpha: 0.9)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
