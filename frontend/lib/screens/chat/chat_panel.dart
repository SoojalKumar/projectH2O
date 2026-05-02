import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';

/// Floating circular button positioned bottom-right above the bottom nav.
class ChatFab extends StatelessWidget {
  const ChatFab({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => showChatPanel(context),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.30),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const SizedBox(
            width: 50,
            height: 50,
            child: Icon(Icons.chat_bubble_outline_rounded,
                color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

void showChatPanel(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.40),
    builder: (_) => const _ChatSheet(),
  );
}

class _ChatSheet extends ConsumerStatefulWidget {
  const _ChatSheet();

  @override
  ConsumerState<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends ConsumerState<_ChatSheet> {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focus = FocusNode();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // After first frame, jump to the bottom so reopening lands on the latest
    // turn instead of scrolled to the top.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd(animate: false));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    final history = ref.read(chatHistoryProvider.notifier);
    history.add(ChatTurn('user', text));
    setState(() {
      _sending = true;
      _controller.clear();
    });
    _scrollToEnd();

    try {
      final api = ref.read(apiServiceProvider);
      final messages = ref.read(chatHistoryProvider);
      final reply = await api.chat(
        messages.map((m) => {'role': m.role, 'content': m.content}).toList(),
      );
      if (!mounted) return;
      history.add(ChatTurn(
        'assistant',
        reply.isEmpty ? "Sorry — empty response." : reply,
      ));
      setState(() => _sending = false);
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      history.add(ChatTurn('assistant', "Couldn't reach the model: $e"));
      setState(() => _sending = false);
      _scrollToEnd();
    }
  }

  void _scrollToEnd({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      final target = _scrollCtrl.position.maxScrollExtent;
      if (animate) {
        _scrollCtrl.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } else {
        _scrollCtrl.jumpTo(target);
      }
    });
  }

  void _suggest(String text) {
    _controller.text = text;
    _focus.requestFocus();
    _controller.selection =
        TextSelection.collapsed(offset: text.length);
  }

  void _clear() {
    ref.read(chatHistoryProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatHistoryProvider);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.82;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: viewInsets),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Handle(),
                _Header(
                  hasMessages: messages.isNotEmpty,
                  onClose: () => Navigator.of(context).pop(),
                  onClear: _clear,
                ),
                Expanded(
                  child: messages.isEmpty
                      ? _Empty(onPick: _suggest)
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                          itemCount: messages.length + (_sending ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i == messages.length) return const _Typing();
                            return _Bubble(turn: messages[i]);
                          },
                        ),
                ),
                _InputBar(
                  controller: _controller,
                  focus: _focus,
                  onSend: _send,
                  sending: _sending,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final bool hasMessages;
  final VoidCallback onClose;
  final VoidCallback onClear;
  const _Header({
    required this.hasMessages,
    required this.onClose,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Ask Hydra',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        letterSpacing: -0.2)),
                SizedBox(height: 2),
                Text('Grounded in California water-supply data',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 11.5)),
              ],
            ),
          ),
          if (hasMessages)
            TextButton(
              onPressed: onClear,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                textStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500),
              ),
              child: const Text('Clear'),
            ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded,
                color: AppColors.textSecondary),
            splashRadius: 18,
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final ValueChanged<String> onPick;
  const _Empty({required this.onPick});

  static const _suggestions = [
    'How are California reservoirs doing right now?',
    'What does the snowpack tell us about next year?',
    'Why does precipitation alone not predict supply?',
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      children: [
        const SizedBox(height: 4),
        const Text(
          "Ask anything about California's snowpack, precipitation, or reservoirs.",
          style: TextStyle(
              fontSize: 14,
              height: 1.55,
              color: AppColors.textPrimary,
              letterSpacing: -0.1),
        ),
        const SizedBox(height: 6),
        const Text(
          'Answers cite the current dataset and stay on topic.',
          style: TextStyle(
              fontSize: 12.5,
              height: 1.55,
              color: AppColors.textSecondary),
        ),
        const SizedBox(height: 22),
        const Text(
          'TRY ASKING',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 8),
        for (final s in _suggestions) _Suggestion(text: s, onTap: () => onPick(s)),
      ],
    );
  }
}

class _Suggestion extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _Suggestion({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.chip),
              border: cardBorder,
            ),
            child: Row(
              children: [
                Expanded(
                    child: Text(text,
                        style: const TextStyle(
                            fontSize: 13, height: 1.4))),
                const Icon(Icons.arrow_forward_rounded,
                    size: 14, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatTurn turn;
  const _Bubble({required this.turn});

  @override
  Widget build(BuildContext context) {
    final isUser = turn.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isUser ? 14 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 14),
                ),
                border: isUser ? null : cardBorder,
              ),
              child: Text(
                turn.content,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.55,
                  color: isUser ? Colors.white : AppColors.textPrimary,
                  letterSpacing: -0.05,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Typing extends StatefulWidget {
  const _Typing();
  @override
  State<_Typing> createState() => _TypingState();
}

class _TypingState extends State<_Typing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(14),
          ),
          border: cardBorder,
        ),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final phase = (_c.value + i * 0.18) % 1.0;
                final opacity = (0.35 + 0.65 * (1 - (phase * 2 - 1).abs()))
                    .clamp(0.25, 1.0);
                return Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: AppColors.textSecondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focus;
  final VoidCallback onSend;
  final bool sending;

  const _InputBar({
    required this.controller,
    required this.focus,
    required this.onSend,
    required this.sending,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              inputFormatters: [LengthLimitingTextInputFormatter(500)],
              decoration: InputDecoration(
                hintText: 'Ask about supply, snowpack, reservoirs…',
                hintStyle: const TextStyle(
                    color: AppColors.textTertiary, fontSize: 13),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  borderSide: const BorderSide(
                      color: AppColors.primary, width: 1.4),
                ),
              ),
              style: const TextStyle(fontSize: 13.5),
            ),
          ),
          const SizedBox(width: 10),
          _SendButton(onTap: sending ? null : onSend, sending: sending),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool sending;
  const _SendButton({required this.onTap, required this.sending});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: disabled ? AppColors.surfaceAlt : AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: sending
              ? const Padding(
                  padding: EdgeInsets.all(11),
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Icon(
                  Icons.arrow_upward_rounded,
                  color: disabled
                      ? AppColors.textTertiary
                      : Colors.white,
                  size: 18,
                ),
        ),
      ),
    );
  }
}
