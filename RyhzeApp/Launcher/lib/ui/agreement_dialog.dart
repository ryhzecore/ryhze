import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'design.dart';

/// One agreement, read to the end, then agreed to or declined.
///
/// The same control serves the Ryhze tester agreement after sign-in and the
/// RACE licence before an engine install. Reaching the end of the text only
/// enables the unchecked checkbox; it never ticks it, and the confirm button
/// stays disabled until the person ticks it themselves. Keyboard scrolling
/// (arrows, Page Up/Down, Home/End) is an equal path to the bottom. The
/// dialog cannot be dismissed by tapping outside; the caller decides what
/// declining means.
class AgreementDialog extends StatefulWidget {
  final String title, text, checkboxLabel, confirmLabel, cancelLabel;
  final String? intro, blockedMessage;
  final Key? scrollKey;

  /// Rebuilds the dialog when access changes underneath it, so a person whose
  /// account was paused mid-read cannot confirm.
  final Listenable? authorization;
  final bool Function()? canConfirm;
  const AgreementDialog({
    super.key,
    required this.title,
    required this.text,
    this.intro,
    this.checkboxLabel = 'I have read and agree to this agreement.',
    this.confirmLabel = 'Agree',
    this.cancelLabel = 'Cancel',
    this.blockedMessage,
    this.scrollKey,
    this.authorization,
    this.canConfirm,
  });

  @override
  State<AgreementDialog> createState() => _AgreementDialogState();
}

class _AgreementDialogState extends State<AgreementDialog> {
  final scroll = ScrollController();
  final focus = FocusNode(debugLabel: 'Agreement text');
  bool reachedBottom = false, agreed = false, focused = false;

  bool get allowed => widget.canConfirm?.call() ?? true;

  @override
  void initState() {
    super.initState();
    scroll.addListener(checkBottom);
    WidgetsBinding.instance.addPostFrameCallback((_) => checkBottom());
  }

  void checkBottom() {
    if (!mounted ||
        !scroll.hasClients ||
        !scroll.position.hasContentDimensions) {
      return;
    }
    if (!reachedBottom && scroll.position.extentAfter <= 1) {
      setState(() => reachedBottom = true);
    }
  }

  @override
  void didUpdateWidget(covariant AgreementDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different text is a different agreement: start reading again.
    if (oldWidget.text != widget.text ||
        oldWidget.authorization != widget.authorization) {
      reachedBottom = agreed = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (scroll.hasClients) scroll.jumpTo(0);
        checkBottom();
      });
    }
  }

  void move(double delta) {
    if (scroll.hasClients) {
      scroll.jumpTo(
        (scroll.offset + delta).clamp(0, scroll.position.maxScrollExtent),
      );
    }
  }

  @override
  void dispose() {
    scroll.dispose();
    focus.dispose();
    super.dispose();
  }

  Widget body(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 640,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.intro != null) ...[
            Text(widget.intro!),
            const SizedBox(height: 16),
          ],
          SizedBox(
            height: (MediaQuery.sizeOf(context).height * .4).clamp(100, 360),
            child: Focus(
              focusNode: focus,
              onFocusChange: (value) => setState(() => focused = value),
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                      move(40),
                  const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                      move(-40),
                  const SingleActivator(LogicalKeyboardKey.pageDown): () =>
                      move(
                        scroll.hasClients
                            ? scroll.position.viewportDimension
                            : 200,
                      ),
                  const SingleActivator(LogicalKeyboardKey.pageUp): () => move(
                    scroll.hasClients
                        ? -scroll.position.viewportDimension
                        : -200,
                  ),
                  const SingleActivator(LogicalKeyboardKey.home): () =>
                      move(-double.maxFinite),
                  const SingleActivator(LogicalKeyboardKey.end): () =>
                      move(double.maxFinite),
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(surfaceRadius),
                    border: Border.all(
                      color: focused ? violet : muted.withValues(alpha: .35),
                      width: focused ? 2 : 1,
                    ),
                  ),
                  child: NotificationListener<ScrollMetricsNotification>(
                    onNotification: (_) {
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => checkBottom(),
                      );
                      return false;
                    },
                    child: Scrollbar(
                      controller: scroll,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        key: widget.scrollKey ?? const ValueKey('agreement-scroll'),
                        controller: scroll,
                        padding: const EdgeInsets.all(20),
                        child: Text(widget.text),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!reachedBottom)
            const Text(
              'Scroll to the end to enable agreement.',
              style: TextStyle(color: muted),
            ),
          CheckboxListTile(
            key: const ValueKey('agreement-checkbox'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(widget.checkboxLabel),
            value: agreed,
            onChanged: reachedBottom && allowed
                ? (value) => setState(() => agreed = value == true)
                : null,
          ),
          if (!allowed && widget.blockedMessage != null)
            Text(widget.blockedMessage!),
        ],
      ),
    ),
    actions: [
      Pill(
        widget.cancelLabel,
        key: const ValueKey('agreement-cancel'),
        onPressed: () => Navigator.pop(context, false),
      ),
      Pill(
        widget.confirmLabel,
        key: const ValueKey('agreement-confirm'),
        primary: true,
        onPressed: reachedBottom && agreed && allowed
            ? () => Navigator.pop(context, true)
            : null,
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final authorization = widget.authorization;
    return PopScope(
      canPop: false,
      child: authorization == null
          ? body(context)
          : AnimatedBuilder(
              animation: authorization,
              builder: (context, _) => body(context),
            ),
    );
  }
}
