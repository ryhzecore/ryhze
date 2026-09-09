import 'package:flutter/material.dart';
import 'design.dart';

class StudioBand extends StatelessWidget {
  final double gutter;
  final VoidCallback onAbout;
  const StudioBand({super.key, required this.gutter, required this.onAbout});
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width <= 700;
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('One identity. Many worlds.'),
        const SizedBox(height: 20),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Films. Games.\n'),
              const TextSpan(
                text: 'Ryhze.',
                style: TextStyle(color: Color(0xff8a6eab)),
              ),
            ],
          ),
          style: heading(
            mobile ? 54 : (width * .05).clamp(46, 76),
          ).copyWith(height: 1.1),
        ),
      ],
    );
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'We create stories and build worlds. A shared identity connects them, while every production has room to be itself.',
          style: TextStyle(fontSize: mobile ? 13 : 14, height: 1.75),
        ),
        const SizedBox(height: 30),
        TextButton(
          onPressed: onAbout,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.only(bottom: 10),
            shape: const RoundedRectangleBorder(),
          ),
          child: const DecoratedBox(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0x44ffffff))),
            ),
            child: Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'The story behind Ryhze',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  SizedBox(width: 24),
                  Icon(Icons.arrow_forward, size: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
    return Container(
      margin: EdgeInsets.symmetric(horizontal: gutter),
      padding: EdgeInsets.only(top: mobile ? 45 : 70, bottom: mobile ? 60 : 90),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x16ffffff))),
      ),
      child: mobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, const SizedBox(height: 30), copy],
            )
          : Row(
              children: [
                Expanded(child: title),
                SizedBox(width: width * (width <= 1000 ? .06 : .12)),
                Expanded(child: copy),
              ],
            ),
    );
  }
}

class RyhzeFooter extends StatelessWidget {
  final double gutter;
  final ValueChanged<String> navigate;
  const RyhzeFooter({super.key, required this.gutter, required this.navigate});
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width <= 700;
    final brand = InkWell(
      onTap: () => navigate('games'),
      child: Image.asset('assets/brand/wordmark.png', width: 120),
    );
    final tagline = Text(
      'Entertainment has no limits.',
      textAlign: mobile && width > 350 ? TextAlign.right : TextAlign.left,
      style: TextStyle(
        fontSize: mobile ? 9 : 11,
        color: const Color(0xff84808c),
      ),
    );
    final links = Wrap(
      spacing: mobile ? 22 : 24,
      runSpacing: 8,
      children: [
        for (final item in [
          ('Our story', 'about'),
          ('Contact', 'contact'),
          ('Privacy & cookies', 'privacy'),
        ])
          TextButton(
            onPressed: () => navigate(item.$2),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
            ),
            child: Text(item.$1, style: TextStyle(fontSize: mobile ? 10 : 11)),
          ),
      ],
    );
    return Container(
      padding: EdgeInsets.fromLTRB(gutter, 44, gutter, 30),
      decoration: const BoxDecoration(
        color: Color(0xff070709),
        border: Border(top: BorderSide(color: Color(0x13ffffff))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (width > 1000)
            Row(
              children: [
                brand,
                const SizedBox(width: 32),
                Expanded(child: tagline),
                links,
              ],
            )
          else ...[
            if (width <= 350) ...[
              Align(alignment: Alignment.centerLeft, child: brand),
              const SizedBox(height: 22),
              tagline,
            ] else
              Row(
                children: [
                  brand,
                  const SizedBox(width: 22),
                  Expanded(child: tagline),
                ],
              ),
            const SizedBox(height: 22),
            links,
          ],
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.only(top: 25),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0x0cffffff))),
            ),
            child: Text(
              '© ${DateTime.now().year} Ryhze. All rights reserved.',
              style: TextStyle(
                fontSize: mobile ? 8 : 9,
                color: const Color(0xff625d6b),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
