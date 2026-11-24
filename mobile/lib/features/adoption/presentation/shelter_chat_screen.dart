import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/media/image_picker_service.dart';
import '../../../core/widgets/pawmate_adaptive.dart';
import '../../../core/widgets/pawmate_page_scaffold.dart';
import '../../../core/widgets/pawmate_state_view.dart';
import '../../../core/widgets/pawmate_top_bar.dart';
import '../../auth/application/auth_session_coordinator.dart';
import '../../preferences/application/preference_providers.dart';
import '../../preferences/application/privacy_surface_policy.dart';
import '../application/adoption_chat_provider.dart';
import '../data/adoption_api.dart';
import '../data/adoption_request_chat_api.dart';
import '../domain/adoption_request_chat_models.dart';

class ShelterChatScreen extends ConsumerStatefulWidget {
  const ShelterChatScreen({super.key, required this.threadId});

  final String threadId;

  @override
  ConsumerState<ShelterChatScreen> createState() => _ShelterChatScreenState();
}

class _ShelterChatScreenState extends ConsumerState<ShelterChatScreen> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  final ScrollController _messageScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncController(ref.read(adoptionChatProvider(widget.threadId)));
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _messageScroll.dispose();
    super.dispose();
  }

  // D122-TB-P2-002: bring the just-sent bubble above the composer.
  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_messageScroll.hasClients) return;
      _messageScroll.animateTo(
        _messageScroll.position.maxScrollExtent,
        duration: AppMotion.standard,
        curve: AppMotion.standardCurve,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final usesExpandedTextLayout =
        MediaQuery.textScalerOf(context).scale(1) >
        AppControlSize.compactButtonMaxTextScale;
    final state = ref.watch(adoptionChatProvider(widget.threadId));
    _syncController(state);
    final notifier = ref.read(adoptionChatProvider(widget.threadId).notifier);
    final privacyState = ref.watch(privacyDefaultsProvider);
    final privacyDefaults =
        privacyState.value ??
        ref.read(privacyDefaultsProvider.notifier).lastSuccessful;
    final privacyPolicy = privacyDefaults == null
        ? PrivacySurfacePolicy.defaultSafe
        : PrivacySurfacePolicy.fromDefaults(privacyDefaults);

    return PawMatePageScaffold(
      layoutMode: PawMatePageLayoutMode.fullResponsive,
      key: const Key('adoption-chat-screen'),
      backgroundColor: AppColors.background,
      topBar: PawMateTopBar(
        title: usesExpandedTextLayout ? 'Hồ sơ' : 'Hồ sơ thú cưng',
        semanticTitle: 'Hồ sơ thú cưng',
        showBackButton: true,
        centerTitle: true,
        onBack: () => _back(context),
        actions: [
          IconButton(
            key: const Key('adoption-chat-share'),
            tooltip: 'Chia sẻ hồ sơ thú cưng',
            onPressed: state.context == null
                ? null
                : () => _shareContext(context, state.context!),
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: _buildBody(
        context,
        state,
        notifier,
        privacyPolicy,
        privacyDefaults == null,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AdoptionChatState state,
    AdoptionChatNotifier notifier,
    PrivacySurfacePolicy privacyPolicy,
    bool usingSafeFallback,
  ) {
    final isImeOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    if (state.isLoading && state.messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null && state.thread == null) {
      return PawMateStateView(
        key: const Key('adoption-chat-error'),
        type: state.errorMessage!.contains('kết nối')
            ? PawMateStateType.offline
            : PawMateStateType.error,
        title: 'Chưa mở được cuộc trò chuyện',
        message: state.errorMessage!,
        primaryActionLabel: 'Thử lại',
        onPrimaryAction: notifier.load,
        secondaryActionLabel: 'Quay lại',
        onSecondaryAction: () => _back(context),
      );
    }

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            key: const Key('adoption-chat-refresh'),
            onRefresh: () => notifier.load(refresh: true),
            child: _MessageList(
              scrollController: _messageScroll,
              state: state,
              onLoadOlder: notifier.loadOlder,
              header: [
                if (state.context != null)
                  _ContextCard(
                    contextData: state.context!,
                    isClosed: state.thread?.isClosed == true,
                    latestMessageAt: state.messages.isEmpty
                        ? null
                        : state.messages.last.createdAt,
                  ),
                if (state.context == null && state.thread?.isClosed == true)
                  const _InlineNotice(
                    icon: Icons.lock_outline,
                    message: 'Đã kết thúc trao đổi',
                    color: AppColors.brown,
                  ),
                _PrivacyNote(
                  policy: privacyPolicy,
                  isFallback: usingSafeFallback,
                ),
                if (state.readWarning != null)
                  _InlineNotice(
                    key: const Key('adoption-chat-read-warning'),
                    icon: Icons.mark_chat_unread_outlined,
                    message: state.readWarning!,
                    color: AppColors.brown,
                  ),
                if (state.errorMessage != null)
                  _InlineNotice(
                    key: const Key('adoption-chat-error-inline'),
                    icon: Icons.error_outline,
                    message: state.errorMessage!,
                  ),
              ],
            ),
          ),
        ),
        // Quick replies are optional shortcuts. Let the composer keep the
        // constrained viewport when an IME is open; the shortcuts return as
        // soon as the user dismisses it.
        if (state.thread?.isClosed != true && !isImeOpen)
          _QuickReplies(
            onSelected: (reply) {
              _controller.value = TextEditingValue(
                text: reply,
                selection: TextSelection.collapsed(offset: reply.length),
              );
              notifier.setDraftBody(reply);
              _focusNode.requestFocus();
            },
          ),
        _Composer(
          controller: _controller,
          focusNode: _focusNode,
          state: state,
          isImeOpen: isImeOpen,
          onPickMedia: () => _showMediaPicker(context, notifier),
          onRetryMedia: notifier.retryMedia,
          onRemoveMedia: notifier.removeMedia,
          onChanged: notifier.setDraftBody,
          onSend: () async {
            if (await _sendWithPrivacyGuard(
                  state: state,
                  policy: privacyPolicy,
                  notifier: notifier,
                ) &&
                mounted) {
              _controller.clear();
              _focusNode.requestFocus();
              _scrollToLatest();
            }
          },
        ),
      ],
    );
  }

  Future<bool> _sendWithPrivacyGuard({
    required AdoptionChatState state,
    required PrivacySurfacePolicy policy,
    required AdoptionChatNotifier notifier,
  }) async {
    final phoneConsent = policy.requiresPhoneConsent(state.draft.body);
    final mediaReview = policy.requiresMediaReview(state.draft.media);
    if (!phoneConsent && !mediaReview) return notifier.send();

    final confirmed = await showPawMateAdaptiveDialog<bool>(
      context: context,
      dialogKey: const Key('adoption-chat-privacy-confirmation'),
      title: 'Kiểm tra trước khi gửi',
      message: [
        if (phoneConsent)
          'Tin nhắn có thể chứa số điện thoại. Chỉ gửi nếu bạn đồng ý chia sẻ với người nhận.',
        if (mediaReview)
          'Hãy chắc chắn ảnh/video không chứa địa chỉ hoặc vị trí riêng tư.',
      ].join('\n\n'),
      actions: const [
        PawMateAdaptiveAction<bool>(label: 'Xem lại'),
        PawMateAdaptiveAction<bool>(
          key: Key('adoption-chat-privacy-confirm-send'),
          label: 'Tôi hiểu, gửi',
          value: true,
          isDefaultAction: true,
        ),
      ],
    );
    if (confirmed != true || !mounted) return false;
    return notifier.send();
  }

  Future<void> _shareContext(
    BuildContext context,
    AdoptionChatContext chatContext,
  ) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? const Rect.fromLTWH(0, 0, 1, 1)
        : box.localToGlobal(Offset.zero) & box.size;
    await SharePlus.instance.share(
      ShareParams(
        title: 'Hồ sơ thú cưng ${chatContext.petName}',
        subject: 'Cùng xem hồ sơ của ${chatContext.petName} trên PawMate',
        text:
            'PawMate · ${chatContext.petName}\n'
            'Mã hồ sơ: ${chatContext.listingId}',
        sharePositionOrigin: origin,
      ),
    );
  }

  Future<void> _showMediaPicker(
    BuildContext context,
    AdoptionChatNotifier notifier,
  ) async {
    final choice = await showModalBottomSheet<_MediaChoice>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('adoption-chat-pick-image'),
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn ảnh'),
              subtitle: const Text('JPG, PNG hoặc WebP · tối đa 10 MB'),
              onTap: () => Navigator.pop(context, _MediaChoice.image),
            ),
            ListTile(
              key: const Key('adoption-chat-pick-video'),
              leading: const Icon(Icons.video_library_outlined),
              title: const Text('Chọn video'),
              subtitle: const Text('MP4 · tối đa 50 MB'),
              onTap: () => Navigator.pop(context, _MediaChoice.video),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    final picker = ref.read(imagePickerProvider);
    final file = choice == _MediaChoice.image
        ? await picker.pickImage(source: ImageSource.gallery)
        : await picker.pickVideo(source: ImageSource.gallery);
    if (!context.mounted || file == null) return;
    final mimeType = _mimeFor(file.path, choice);
    await notifier.addMedia(
      path: file.path,
      mimeType: mimeType,
      sizeBytes: await file.length(),
    );
  }

  void _syncController(AdoptionChatState state) {
    if (_controller.text == state.draft.body || _focusNode.hasFocus) return;
    _controller.value = TextEditingValue(
      text: state.draft.body,
      selection: TextSelection.collapsed(offset: state.draft.body.length),
    );
  }

  static String _mimeFor(String path, _MediaChoice choice) {
    final extension = path.split('.').last.toLowerCase();
    if (choice == _MediaChoice.video) return 'video/mp4';
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }

  static void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/adoption');
    }
  }
}

enum _MediaChoice { image, video }

class _ContextCard extends StatelessWidget {
  const _ContextCard({
    required this.contextData,
    required this.isClosed,
    required this.latestMessageAt,
  });

  final AdoptionChatContext contextData;
  final bool isClosed;
  final DateTime? latestMessageAt;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 44, 28, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 120,
              height: 120,
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: contextData.heroMediaUrl == null
                    ? Image.asset(
                        'assets/images/pets/home_adoption_golden.png',
                        fit: BoxFit.cover,
                        semanticLabel:
                            'Ảnh đại diện của ${contextData.petName}',
                      )
                    : Image.network(
                        contextData.heroMediaUrl.toString(),
                        fit: BoxFit.cover,
                        semanticLabel:
                            'Ảnh đại diện của ${contextData.petName}',
                        errorBuilder: (_, _, _) => Image.asset(
                          'assets/images/pets/home_adoption_golden.png',
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
            ),
            Positioned(
              right: -6,
              bottom: -6,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary700,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
                child: const Icon(
                  Icons.pets_rounded,
                  size: 22,
                  color: AppColors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          '${contextData.petName} & PawMate',
          textAlign: TextAlign.start,
          style: AppTextStyles.h2(),
        ),
        const SizedBox(height: 2),
        Text(
          'Trung tâm cứu hộ',
          textAlign: TextAlign.start,
          style: AppTextStyles.bodyStrong(),
        ),
        const SizedBox(height: AppSpacing.s24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
            vertical: AppSpacing.s16,
          ),
          decoration: BoxDecoration(
            color: AppColors.mint,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Row(
            children: [
              const Icon(Icons.circle, size: 8, color: AppColors.primary700),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isClosed ? 'Đã kết thúc trao đổi' : 'Đang chờ phản hồi',
                      style: AppTextStyles.label(color: AppColors.primary700),
                    ),
                    Text(
                      latestMessageAt == null
                          ? 'Chưa có tin nhắn'
                          : 'Cập nhật ${_timeLabel(latestMessageAt!)}',
                      style: AppTextStyles.caption(color: AppColors.primary700),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.pending_actions_outlined,
                color: AppColors.brown,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  static String _timeLabel(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote({required this.policy, required this.isFallback});

  final PrivacySurfacePolicy policy;
  final bool isFallback;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(28, AppSpacing.s32, 28, 0),
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.s12,
      AppSpacing.s12,
      AppSpacing.s12,
      AppSpacing.s12,
    ),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: AppColors.brown,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.info_outline, size: 18, color: Colors.white),
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: Text(
            'Lưu ý: ${policy.hidePhoneByDefault ? 'Không chia sẻ thông tin thanh toán hoặc số điện thoại khi chưa xác nhận.' : 'Chỉ chia sẻ thông tin liên hệ khi cần.'} '
            '${policy.reviewMediaBeforePublish ? 'Hãy kiểm tra ảnh/video trước khi gửi. ' : ''}'
            'Đừng gửi địa chỉ hoặc vị trí chính xác.'
            '${isFallback ? ' Mức bảo vệ an toàn đang bật.' : ''}',
            style: AppTextStyles.caption(color: AppColors.textSecondary),
          ),
        ),
      ],
    ),
  );
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.scrollController,
    required this.state,
    required this.onLoadOlder,
    required this.header,
  });

  final ScrollController scrollController;
  final AdoptionChatState state;
  final Future<void> Function() onLoadOlder;
  final List<Widget> header;

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('adoption-chat-message-list'),
    controller: scrollController,
    physics: const AlwaysScrollableScrollPhysics(),
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    padding: EdgeInsets.zero,
    children: [
      ...header,
      Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, AppSpacing.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.hasMore)
              Align(
                alignment: Alignment.center,
                child: TextButton.icon(
                  key: const Key('adoption-chat-load-older'),
                  onPressed: state.isLoadingOlder ? null : onLoadOlder,
                  icon: state.isLoadingOlder
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.history),
                  label: const Text('Xem tin cũ hơn'),
                ),
              ),
            if (state.messages.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.s32),
                child: Text(
                  'Chưa có tin nhắn. Hãy bắt đầu trao đổi nhé.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              for (final message in state.messages)
                _MessageBubble(
                  message: message,
                  isMine: message.senderUserId == state.currentUserId,
                ),
          ],
        ),
      ),
    ],
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final AdoptionChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) => Align(
    alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: BoxConstraints(maxWidth: isMine ? 320 : 284),
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: isMine ? AppSpacing.s8 : AppSpacing.s16,
      ),
      decoration: BoxDecoration(
        color: isMine ? AppColors.deepGreen : AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(AppRadius.lg),
          topRight: const Radius.circular(AppRadius.lg),
          bottomLeft: Radius.circular(isMine ? AppRadius.lg : AppRadius.sm),
          bottomRight: Radius.circular(isMine ? AppRadius.sm : AppRadius.lg),
        ),
        border: isMine ? null : Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (message.body.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                message.body,
                style: AppTextStyles.body(
                  color: isMine ? AppColors.white : AppColors.textPrimary,
                ),
              ),
            ),
          for (final media in message.media)
            _RemoteMedia(
              media: media,
              threadId: message.threadId,
              isMine: isMine,
            ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            _timeLabel(message.createdAt),
            style: AppTextStyles.caption(
              color: isMine
                  ? AppColors.white.withValues(alpha: .76)
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );

  static String _timeLabel(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    super.key,
    required this.icon,
    required this.message,
    this.color = AppColors.error,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(
      AppSpacing.s16,
      AppSpacing.s8,
      AppSpacing.s16,
      0,
    ),
    padding: const EdgeInsets.all(AppSpacing.s8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: Text(
            message,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption(color: color),
          ),
        ),
      ],
    ),
  );
}

class _RemoteMedia extends ConsumerStatefulWidget {
  const _RemoteMedia({
    required this.media,
    required this.threadId,
    required this.isMine,
  });

  final AdoptionChatMedia media;
  final String threadId;
  final bool isMine;

  @override
  ConsumerState<_RemoteMedia> createState() => _RemoteMediaState();
}

class _RemoteMediaState extends ConsumerState<_RemoteMedia> {
  Future<Uint8List>? _download;
  Uint8List? _loadedBytes;
  String? _activeToken;
  String? _activePath;
  int _generation = 0;

  void _evictLoadedImage() {
    final bytes = _loadedBytes;
    _loadedBytes = null;
    if (bytes != null) unawaited(MemoryImage(bytes).evict());
  }

  Future<Uint8List> _load(String token) async {
    final generation = ++_generation;
    final bytes = await ref
        .read(adoptionChatMediaSourceProvider)
        .downloadChatMedia(
          accessToken: token,
          threadId: widget.threadId,
          media: widget.media,
        );
    if (mounted && generation == _generation) _loadedBytes = bytes;
    return bytes;
  }

  @override
  void dispose() {
    _generation++;
    _evictLoadedImage();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    final foreground = widget.isMine
        ? AppColors.white
        : AppColors.textSecondary;
    if (media.downloadPath == null) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.s8),
        child: Text(
          'Tệp đính kèm không còn khả dụng',
          style: AppTextStyles.caption(color: foreground),
        ),
      );
    }
    if (!media.mimeType.startsWith('image/')) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.s8),
        child: Text(
          'Video đính kèm',
          style: AppTextStyles.caption(color: foreground),
        ),
      );
    }
    final token = ref
        .watch(authSessionSnapshotProvider)
        .value
        ?.accessToken
        .trim();
    if (token == null || token.isEmpty) {
      _generation++;
      _evictLoadedImage();
      _download = null;
      _activeToken = null;
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.s8),
        child: Text(
          'Đăng nhập để xem ảnh đính kèm',
          style: AppTextStyles.caption(color: foreground),
        ),
      );
    }
    if (_download == null ||
        _activeToken != token ||
        _activePath != media.downloadPath) {
      _evictLoadedImage();
      _activeToken = token;
      _activePath = media.downloadPath;
      _download = _load(token);
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: FutureBuilder<Uint8List>(
          future: _download,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              final error = snapshot.error;
              if (error is AdoptionApiException && error.isAuthRequired) {
                return SizedBox(
                  width: 180,
                  child: TextButton(
                    key: Key('adoption-chat-media-login-${media.mediaId}'),
                    onPressed: () => context.go(
                      Uri(
                        path: '/auth/login',
                        queryParameters: {
                          'returnTo':
                              '/adoption/chat/${Uri.encodeComponent(widget.threadId)}',
                        },
                      ).toString(),
                    ),
                    child: const Text('Đăng nhập lại để xem ảnh'),
                  ),
                );
              }
              if (error is AdoptionApiException &&
                  (error.statusCode == 403 || error.isUnavailable)) {
                return SizedBox(
                  width: 180,
                  child: Text(
                    'Bạn không còn quyền xem ảnh này',
                    key: Key('adoption-chat-media-forbidden-${media.mediaId}'),
                    style: AppTextStyles.caption(color: foreground),
                  ),
                );
              }
              return SizedBox(
                width: 180,
                height: 80,
                child: TextButton.icon(
                  key: Key('adoption-chat-media-retry-${media.mediaId}'),
                  onPressed: () => setState(() {
                    _evictLoadedImage();
                    _download = _load(token);
                  }),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử tải ảnh lại'),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const SizedBox(
                width: 180,
                height: 132,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return Image.memory(
              snapshot.requireData,
              key: Key('adoption-chat-private-media-${media.mediaId}'),
              width: 180,
              height: 132,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(
                width: 180,
                height: 60,
                child: Center(child: Icon(Icons.broken_image_outlined)),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _QuickReplies extends StatelessWidget {
  const _QuickReplies({required this.onSelected});

  final ValueChanged<String> onSelected;

  static const replies = <String>[
    'Đặt lịch hẹn',
    'Hỏi về tính cách',
    'Thủ tục nhận nuôi',
  ];

  @override
  Widget build(BuildContext context) => SizedBox(
    height: math.max(56, MediaQuery.textScalerOf(context).scale(20) + 32),
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
      scrollDirection: Axis.horizontal,
      itemCount: replies.length,
      separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s8),
      itemBuilder: (context, index) {
        final reply = replies[index];
        return Center(
          child: Semantics(
            button: true,
            label: 'Soạn nhanh: $reply',
            child: Material(
              key: Key('adoption-chat-quick-reply-$index'),
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onSelected(reply),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppControlSize.minTouchTarget,
                  ),
                  child: Center(
                    // Grows with large text so diacritics are not clipped.
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 36),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: AppColors.mint),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        reply,
                        style: AppTextStyles.label(color: AppColors.primary700),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.state,
    required this.isImeOpen,
    required this.onPickMedia,
    required this.onRetryMedia,
    required this.onRemoveMedia,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final AdoptionChatState state;
  final bool isImeOpen;
  final VoidCallback onPickMedia;
  final ValueChanged<String> onRetryMedia;
  final ValueChanged<String> onRemoveMedia;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final disabled = state.thread?.isClosed == true || state.isSending;
    return Material(
      color: AppColors.background,
      elevation: AppElevation.none,
      child: SafeArea(
        top: false,
        // Scaffold has already resized this footer above the keyboard. Keeping
        // its normal 32dp safe-bottom spacer as well would consume the last
        // available composer space at accessibility text sizes.
        minimum: isImeOpen
            ? EdgeInsets.zero
            : const EdgeInsets.only(bottom: AppSpacing.s32),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s16,
            AppSpacing.s4,
            AppSpacing.s16,
            AppSpacing.s12,
          ),
          child: Column(
            children: [
              if (state.draft.media.isNotEmpty)
                SizedBox(
                  height: 64,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: state.draft.media.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppSpacing.s8),
                    itemBuilder: (context, index) {
                      final media = state.draft.media[index];
                      return _DraftMediaTile(
                        media: media,
                        onRetry: () => onRetryMedia(media.localId),
                        onRemove: () => onRemoveMedia(media.localId),
                      );
                    },
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    key: const Key('adoption-chat-attach'),
                    tooltip: 'Đính kèm ảnh hoặc video',
                    onPressed: disabled ? null : onPickMedia,
                    icon: const Icon(Icons.add_circle, color: AppColors.brown),
                  ),
                  Expanded(
                    child: TextField(
                      key: const Key('adoption-chat-composer'),
                      controller: controller,
                      focusNode: focusNode,
                      enabled: !disabled,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 1000,
                      textInputAction: TextInputAction.newline,
                      onChanged: state.isSending ? null : onChanged,
                      decoration: const InputDecoration(
                        hintText: 'Viết tin nhắn…',
                        counterText: '',
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.s8,
                          vertical: AppSpacing.s12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s4),
                  IconButton.filled(
                    key: const Key('adoption-chat-send'),
                    // D123-IOS-UI-013: Figma keeps the button filled.
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.deepTeal,
                      foregroundColor: AppColors.white,
                      disabledBackgroundColor: AppColors.deepTeal.withValues(
                        alpha: 0.6,
                      ),
                      disabledForegroundColor: AppColors.white,
                    ),
                    tooltip: state.errorMessage != null && state.canSend
                        ? 'Gửi lại tin nhắn'
                        : 'Gửi tin nhắn',
                    onPressed: state.canSend ? onSend : null,
                    icon: state.isSending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DraftMediaTile extends StatelessWidget {
  const _DraftMediaTile({
    required this.media,
    required this.onRetry,
    required this.onRemove,
  });

  final AdoptionChatDraftMedia media;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isImage = media.mimeType.startsWith('image/');
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: isImage
              ? Image.file(
                  File(media.path),
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _fallback(),
                )
              : Container(
                  width: 64,
                  height: 64,
                  color: AppColors.surfaceContainer,
                  child: const Icon(Icons.videocam_outlined),
                ),
        ),
        if (media.status == AdoptionChatUploadStatus.uploading ||
            media.status == AdoptionChatUploadStatus.pending)
          const Positioned.fill(
            child: ColoredBox(
              color: AppColors.scrimMedia,
              child: Center(
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
        if (media.status == AdoptionChatUploadStatus.failed)
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onRetry,
                child: const ColoredBox(
                  color: AppColors.cocoaOverlay,
                  child: Center(
                    child: Icon(Icons.refresh, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          top: -8,
          right: -8,
          child: IconButton(
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(
              minWidth: AppControlSize.minTouchTarget,
              minHeight: AppControlSize.minTouchTarget,
            ),
            tooltip: 'Xóa tệp',
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 16),
          ),
        ),
      ],
    );
  }

  Widget _fallback() => const SizedBox(
    width: 64,
    height: 64,
    child: ColoredBox(
      color: AppColors.surfaceContainer,
      child: Icon(Icons.broken_image_outlined),
    ),
  );
}
