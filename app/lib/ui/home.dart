import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'design.dart';

class BrandHome extends StatelessWidget {
  final ValueChanged<String> navigate;
  final VoidCallback? onUpdates;
  const BrandHome({super.key, required this.navigate, this.onUpdates});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final mobile = c.maxWidth < 1000;
      final gutter = mobile ? 22.0 : (c.maxWidth * .065).clamp(30.0, 88.0);
      final identity = SizedBox(
        height: mobile ? 290 : 430,
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (final size in [
                mobile ? 260.0 : 400.0,
                mobile ? 205.0 : 310.0,
              ])
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0x40bf70ff)),
                  ),
                ),
              Container(
                width: mobile ? 155 : 205,
                height: mobile ? 155 : 205,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0x07ffffff), Color(0x185500ff)],
                  ),
                ),
                padding: const EdgeInsets.all(30),
                child: Image.asset('assets/brand/symbol.png'),
              ),
            ],
          ),
        ),
      );
      final intro = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('One identity. Many worlds.'),
          const SizedBox(height: 24),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Entertainment\nhas no '),
                const TextSpan(
                  text: 'limits.',
                  style: TextStyle(color: Color(0xffbf70ff)),
                ),
              ],
            ),
            style: heading(mobile ? 48 : 72),
          ),
          const SizedBox(height: 24),
          const Text(
            'Stories to get lost in. Worlds to make your own. Ryhze brings films, series and games into one experience, wherever you choose to explore.',
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              Pill(
                'Explore Ryhze',
                primary: true,
                icon: Icons.arrow_forward,
                onPressed: () => navigate('games'),
              ),
              Pill('Explore films', onPressed: () => navigate('films')),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'A world beyond the ordinary.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ],
      );
      final worlds = [
        (
          '01 / RYHZE STUDIO',
          Icons.movie_outlined,
          'Stories that stay.',
          'Meet the film side of Ryhze and discover the stories taking shape behind the screen.',
          'Explore films',
          'films',
        ),
        (
          '02 / RYHZE TELEVISION',
          Icons.play_circle_outline,
          'Another chapter.',
          'A place for series and longer stories. Different voices, with room to keep unfolding.',
          'Explore series',
          'films',
        ),
        (
          '03 / RYHZE GAMES',
          Icons.sports_esports_outlined,
          'Find your own way.',
          'Explore our game worlds, follow their development and discover what comes next.',
          'Explore games',
          'games',
        ),
      ];
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 48),
            if (mobile) ...[
              intro,
              identity,
            ] else
              Row(
                children: [
                  Expanded(child: intro),
                  Expanded(child: identity),
                ],
              ),
            const SizedBox(height: 48),
            const Eyebrow('This is Ryhze'),
            const SizedBox(height: 18),
            Text(
              'Different ways in.\nOne unmistakable feeling.',
              style: heading(mobile ? 34 : 48),
            ),
            const SizedBox(height: 20),
            const Text(
              'We create stories and build worlds. Across our studio, television and games, curiosity connects everything we make.',
            ),
            const SizedBox(height: 30),
            Wrap(
              spacing: 20,
              runSpacing: 20,
              children: [
                for (final world in worlds)
                  SizedBox(
                    width: c.maxWidth < 1000
                        ? c.maxWidth - gutter * 2
                        : (c.maxWidth - gutter * 2 - 40) / 3,
                    child: _WorldLink(
                      onTap: () => navigate(world.$6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Eyebrow(world.$1),
                          const SizedBox(height: 28),
                          Icon(world.$2, size: 32),
                          const SizedBox(height: 26),
                          Text(world.$3, style: heading(27)),
                          const SizedBox(height: 16),
                          Text(world.$4),
                          const SizedBox(height: 22),
                          Wrap(
                            spacing: 16,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(world.$5),
                              const Icon(Icons.arrow_forward, size: 18),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => navigate('about'),
              child: const Text('More about Ryhze →'),
            ),
            const SizedBox(height: 60),
            const Eyebrow('Your screen. Your choice.'),
            const SizedBox(height: 18),
            Text('Make room\nfor Ryhze.', style: heading(mobile ? 40 : 56)),
            const SizedBox(height: 22),
            const Text(
              'Find your next world. Keep favourites close. Use your existing approved Ryhze account.',
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                if (onUpdates != null)
                  Pill(
                    'App updates',
                    primary: true,
                    icon: Icons.system_update_alt,
                    onPressed: onUpdates,
                  ),
                Pill(
                  'Get Ryhze on another device',
                  onPressed: () => launchUrl(
                    Uri.parse('https://ryhze.com/#install'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 60),
            const Eyebrow('Every world starts with curiosity.'),
            const SizedBox(height: 20),
            Text(
              'See where yours takes you.',
              style: heading(mobile ? 34 : 48),
            ),
            const SizedBox(height: 24),
            Pill(
              'Step into Ryhze',
              icon: Icons.arrow_forward,
              onPressed: () => navigate('games'),
            ),
            const SizedBox(height: 60),
          ],
        ),
      );
    },
  );
}

class _WorldLink extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _WorldLink({required this.child, required this.onTap});
  @override
  State<_WorldLink> createState() => _WorldLinkState();
}

class _WorldLinkState extends State<_WorldLink> {
  bool hovered = false, focused = false;
  @override
  Widget build(BuildContext context) {
    final active = hovered || focused;
    final reduced = MotionSettings.of(context);
    return AnimatedContainer(
      duration: Duration(milliseconds: reduced ? 0 : 550),
      curve: ryhzeEase,
      transform: Matrix4.translationValues(0, active && !reduced ? -6 : 0, 0),
      decoration: ShapeDecoration(
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(surfaceRadius),
          side: BorderSide(
            color: active ? const Color(0x70bf70ff) : const Color(0x1dffffff),
          ),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            active ? const Color(0x0dbf70ff) : const Color(0x05ffffff),
            active ? const Color(0x08bf70ff) : Colors.transparent,
          ],
        ),
      ),
      child: InkWell(
        onTap: widget.onTap,
        onHover: (value) => setState(() => hovered = value),
        onFocusChange: (value) => setState(() => focused = value),
        borderRadius: BorderRadius.circular(surfaceRadius),
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        child: Padding(padding: const EdgeInsets.all(26), child: widget.child),
      ),
    );
  }
}
