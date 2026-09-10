import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/state.dart';
import 'design.dart';
import 'preview.dart';
import 'artwork_hero.dart';

class RyhzeTitleCard extends StatefulWidget {
  final RyhzeTitle title;
  final RyhzeState state;
  final VoidCallback onOpen, onSave;
  final bool previewAllowed;
  final double? progress;
  final Widget? artwork, trailingAction;
  const RyhzeTitleCard({
    super.key,
    required this.title,
    required this.state,
    required this.onOpen,
    required this.onSave,
    this.previewAllowed = true,
    this.progress,
    this.artwork,
    this.trailingAction,
  });
  @override
  State<RyhzeTitleCard> createState() => _RyhzeTitleCardState();
}

class _RyhzeTitleCardState extends State<RyhzeTitleCard> {
  bool hovered = false, focused = false, cardHovered = false;
  final focusNode = FocusNode(debugLabel: 'Title artwork');
  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width <= 700;
    final reduced = widget.state.reduced || MotionSettings.of(context);
    final active = (hovered || focused) && widget.previewAllowed;
    final title = widget.title;
    final radius = BorderRadius.circular(surfaceRadius);
    return MouseRegion(
      onEnter: (_) => setState(() => cardHovered = true),
      onExit: (_) => setState(() => cardHovered = false),
      child: AnimatedContainer(
        key: ValueKey('card-lift-${title.id}'),
        duration: Duration(milliseconds: reduced ? 0 : 300),
        curve: ryhzeEase,
        transform: Matrix4.translationValues(
          0,
          cardHovered && !reduced ? -3 : 0,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => hovered = true),
              onExit: (_) => setState(() => hovered = false),
              child: AnimatedScale(
                key: ValueKey('card-scale-${title.id}'),
                scale: active && !reduced ? 1.025 : 1,
                duration: Duration(milliseconds: reduced ? 0 : 600),
                curve: ryhzeEase,
                child: AnimatedContainer(
                  duration: Duration(milliseconds: reduced ? 0 : 600),
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    boxShadow: active
                        ? const [
                            BoxShadow(
                              color: Color(0x44000000),
                              offset: Offset(0, 16),
                              blurRadius: 35,
                            ),
                          ]
                        : const [],
                  ),
                  child: Semantics(
                    label: 'Explore ${title.title}',
                    button: true,
                    child: InkWell(
                      key: ValueKey('card-open-${title.id}'),
                      focusNode: focusNode,
                      onFocusChange: (v) => setState(() => focused = v),
                      onTap: widget.onOpen,
                      borderRadius: radius,
                      splashColor: Colors.transparent,
                      hoverColor: Colors.transparent,
                      focusColor: Colors.transparent,
                      child: ArtworkHero(
                        tag: 'card-${title.id}',
                        image: title.image,
                        state: widget.state,
                        artwork: widget.artwork,
                        child: Container(
                          decoration: ShapeDecoration(
                            shape: RoundedSuperellipseBorder(
                              borderRadius: radius,
                              side: BorderSide(
                                color: focused
                                    ? Colors.white
                                    : const Color(0x1affffff),
                                width: focused ? 2 : 1,
                              ),
                            ),
                          ),
                          child: ClipRSuperellipse(
                            borderRadius: radius,
                            child: AspectRatio(
                              aspectRatio: width <= 480 ? 1.6 : 1.5,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  AnimatedScale(
                                    scale: active && !reduced ? 1.035 : 1,
                                    duration: Duration(
                                      milliseconds: reduced ? 0 : 1200,
                                    ),
                                    curve: ryhzeEase,
                                    child:
                                        widget.artwork ??
                                        ArtworkPreview(
                                          title: title,
                                          state: widget.state,
                                          active: active && !reduced,
                                        ),
                                  ),
                                  const IgnorePointer(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [
                                            Color(0xee09090c),
                                            Colors.transparent,
                                          ],
                                          stops: [0, .8],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: mobile ? 15 : 20,
                                    left: mobile ? 16 : 22,
                                    right: 16,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0x55000000),
                                          border: Border.all(
                                            color: const Color(0x30ffffff),
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          (title.internal
                                                  ? 'Internal test'
                                                  : title.label)
                                              .toUpperCase(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: mobile ? 7 : 8,
                                            height: 1.3,
                                            letterSpacing: 1.12,
                                            color: const Color(0xfff8f7fa),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: mobile ? 18 : 22,
                                    left: mobile ? 18 : 22,
                                    right: 50,
                                    child: Align(
                                      alignment: Alignment.bottomLeft,
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 260,
                                        ),
                                        child: Text(
                                          title.title,
                                          style: heading(
                                            width <= 350
                                                ? 29
                                                : width <= 480
                                                ? 32
                                                : mobile
                                                ? 25
                                                : (width * .022).clamp(22, 34),
                                          ).copyWith(height: 1.1),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: mobile ? 15 : 20,
                                    bottom: mobile ? 16 : 22,
                                    child: const Icon(
                                      Icons.arrow_forward,
                                      size: 20,
                                      color: Color(0xffe1d9ee),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.status,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            color: Color(0xffe0dce7),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          title.categories.take(2).join(' · ').isEmpty
                              ? 'Private preview'
                              : title.categories.take(2).join(' · '),
                          style: const TextStyle(
                            fontSize: 10,
                            height: 1.3,
                            color: Color(0xff8e8798),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  widget.trailingAction ??
                      Pill(
                        widget.state.saved.contains(title.id)
                            ? 'Remove from My List'
                            : 'Add to My List',
                        iconOnly: true,
                        quiet: true,
                        height: 44,
                        icon: widget.state.saved.contains(title.id)
                            ? Icons.check
                            : Icons.add,
                        onPressed: widget.onSave,
                      ),
                ],
              ),
            ),
            if (widget.progress != null)
              LinearProgressIndicator(value: widget.progress, minHeight: 2),
          ],
        ),
      ),
    );
  }
}
