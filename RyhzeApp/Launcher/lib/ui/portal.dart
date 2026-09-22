import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/ai.dart';
import '../core/state.dart';
import 'ai_tools.dart';
import 'ai_widgets.dart';
import 'design.dart';
import 'page_header.dart';

class PortalPage extends StatefulWidget {
  final RyhzeState state;
  const PortalPage({super.key, required this.state});
  @override
  State<PortalPage> createState() => _PortalPageState();
}

class _PortalPageState extends State<PortalPage> with WidgetsBindingObserver {
  late final ai = RyhzeAi(widget.state);
  final composer = TextEditingController(), search = TextEditingController();
  final scroll = ScrollController();
  String tab = 'Chat';
  bool history = false, archived = false, foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ai.addListener(changed);
    unawaited(ai.refresh());
  }

  void changed() {
    if (!mounted) return;
    if (!ai.allowed) {
      composer.clear();
      search.clear();
    }
    final follow = scroll.hasClients && scroll.position.extentAfter < 100;
    setState(() {});
    if (follow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && scroll.hasClients) {
          scroll.jumpTo(scroll.position.maxScrollExtent);
        }
      });
    }
  }

  void selectTab(String value) {
    setState(() => tab = value);
    ai.setVisible(foreground && tab == 'Chat');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    ai.setVisible(foreground && tab == 'Chat');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ai.removeListener(changed);
    ai.dispose();
    composer.clear();
    composer.dispose();
    search.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> send({AiObject? retry}) async {
    final text = retry == null
        ? composer.text
        : aiText(retry['content'] ?? retry['question']);
    if (await ai.send(text, retry: retry)) {
      if (mounted && retry == null && composer.text == text) composer.clear();
    }
  }

  Future<void> remember(AiObject message) => aiEdit(
    context,
    ai,
    title: 'Remember this',
    explanation:
        'Keep useful context. Saving memory does not approve a decision.',
    fields: [
      AiField(
        'content',
        'Memory',
        value: aiText(
          message['content'],
        ).substring(0, aiText(message['content']).length.clamp(0, 4000)),
        lines: 5,
        required: true,
      ),
      const AiField(
        'category',
        'Type',
        value: 'context',
        choices: {
          'context': 'Context',
          'preference': 'Preference',
          'project': 'Project',
        },
      ),
      AiField('project', 'Project', value: ai.project, choices: aiProjects(ai)),
    ],
    save: (values) async {
      await ai.call(
        '/ai/memories',
        body: {...values, 'source_message': message['id'], 'archived': false},
      );
    },
  ).then((_) {});
  Future<void> task(AiObject message) => aiEdit(
    context,
    ai,
    title: 'Review as task',
    action: 'Create task',
    fields: [
      AiField(
        'title',
        'Title',
        value: aiText(ai.chat?['title']),
        limit: 200,
        required: true,
      ),
      AiField(
        'body',
        'Task',
        value: aiText(message['content']),
        limit: 20000,
        lines: 5,
      ),
      AiField('project', 'Project', value: ai.project, choices: aiProjects(ai)),
    ],
    save: (values) async {
      await ai.call(
        '/records/task',
        body: {
          ...values,
          'status': 'todo',
          'division': 'Ryhze',
          'priority': 'normal',
          'due': '',
        },
      );
    },
  ).then((_) {});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 800;
    return Scaffold(
      backgroundColor: canvas,
      body: SafeArea(
        child: Column(
          children: [
            RyhzePageHeader(
              title: 'Gideon',
              compact: compact,
              actions: ai.allowed
                  ? [
                      if (tab == 'Chat')
                        Pill(
                          'Conversations',
                          icon: Icons.history,
                          iconOnly: true,
                          onPressed: () => setState(() => history = !history),
                        ),
                      Pill(
                        'Refresh AI',
                        icon: Icons.refresh,
                        iconOnly: true,
                        onPressed: ai.loading ? null : ai.refresh,
                      ),
                    ]
                  : [],
            ),
            if (!ai.allowed)
              const Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Sign in with your approved account and enable admin access to open AI.',
                    ),
                  ),
                ),
              )
            else ...[
              if (MediaQuery.viewInsetsOf(context).bottom == 0)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final value in [
                          'Chat',
                          'Memory',
                          'Sources',
                          'Models',
                          'Reports',
                          'Knowledge',
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Pill(
                              value,
                              height: 44,
                              primary: tab == value,
                              onPressed: () => selectTab(value),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              if (ai.loading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: StatusProgress(label: 'Connecting to your workspace'),
                ),
              if (ai.error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          ai.error!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.amber),
                        ),
                      ),
                      Pill(
                        'Retry connection',
                        icon: Icons.refresh,
                        iconOnly: true,
                        onPressed: ai.refresh,
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: tab != 'Chat'
                    ? AiTools(
                        key: ValueKey(tab),
                        ai: ai,
                        tab: tab,
                        onOpenChat: (id) async {
                          await ai.open(id);
                          if (mounted) selectTab('Chat');
                        },
                        onAsk: (text) {
                          ai.newChat();
                          composer.text = text;
                          selectTab('Chat');
                        },
                      )
                    : Padding(
                        padding: EdgeInsets.fromLTRB(
                          compact ? 12 : 24,
                          0,
                          compact ? 12 : 24,
                          12,
                        ),
                        child: compact && history
                            ? _history()
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (!compact) ...[
                                    SizedBox(width: 250, child: _history()),
                                    const SizedBox(width: 20),
                                  ],
                                  Expanded(child: _conversation()),
                                ],
                              ),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _history() {
    final rows = ai.chats
        .where(
          (c) =>
              aiFlag(c['archived']) == archived &&
              aiText(
                c['title'],
              ).toLowerCase().contains(search.text.toLowerCase()),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Pill(
          'New conversation',
          icon: Icons.add,
          onPressed: ai.sending
              ? null
              : () {
                  ai.newChat();
                  composer.clear();
                  setState(() => history = false);
                },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Search conversations',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Archived'),
          value: archived,
          onChanged: (v) => setState(() => archived = v!),
        ),
        Expanded(
          child: rows.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No conversations in this view.'),
                )
              : ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final c = rows[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextButton(
                        onPressed: ai.sending
                            ? null
                            : () async {
                                await ai.open(aiText(c['id']));
                                if (mounted) setState(() => history = false);
                              },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              aiText(c['title']),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: ai.chat?['id'] == c['id']
                                    ? Colors.white
                                    : const Color(0xffb7b5c0),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _conversation() {
    final messages = aiList(ai.chat?['messages']);
    final partial = aiText(ai.run?['partial']);
    final disabled = ai.sending || ai.running || aiFlag(ai.chat?['archived']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (MediaQuery.viewInsetsOf(context).bottom == 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        aiText(ai.chat?['title']).isEmpty
                            ? 'What are we working on?'
                            : aiText(ai.chat?['title']),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: heading(22),
                      ),
                      Text(
                        ai.collaborating
                            ? 'Gideon + Gemini'
                            : ai.online
                            ? 'Gideon · Workspace connected'
                            : 'Gideon · Offline',
                        style: const TextStyle(
                          color: Color(0xffb7b5c0),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (ai.chat != null) ...[
                  Pill(
                    'Rename conversation',
                    icon: Icons.edit_outlined,
                    iconOnly: true,
                    onPressed: disabled
                        ? null
                        : () => aiEdit(
                            context,
                            ai,
                            title: 'Rename conversation',
                            fields: [
                              AiField(
                                'title',
                                'Title',
                                value: aiText(ai.chat!['title']),
                                limit: 200,
                                required: true,
                              ),
                            ],
                            save: ai.editChat,
                          ),
                  ),
                  const SizedBox(width: 8),
                  Pill(
                    aiFlag(ai.chat!['archived'])
                        ? 'Restore conversation'
                        : 'Archive conversation',
                    icon: Icons.archive_outlined,
                    iconOnly: true,
                    onPressed: ai.sending || ai.running
                        ? null
                        : () => aiEdit(
                            context,
                            ai,
                            title: aiFlag(ai.chat!['archived'])
                                ? 'Restore conversation'
                                : 'Archive conversation',
                            explanation:
                                'The conversation stays saved in your workspace.',
                            fields: [],
                            save: (_) => ai.editChat({
                              'archived': !aiFlag(ai.chat!['archived']),
                            }),
                          ),
                  ),
                ],
              ],
            ),
          ),
        Expanded(
          child: RepaintBoundary(
            child: ListView.builder(
              controller: scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: messages.isEmpty
                  ? 1
                  : messages.length + (partial.isEmpty ? 0 : 1),
              itemBuilder: (context, i) {
                if (messages.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ask about projects, explore an idea, or find what Ryhze has already decided.',
                        ),
                        const SizedBox(height: 20),
                        for (final prompt in [
                          'What needs my attention this week?',
                          'What is approved and what is still open?',
                          'Help me plan the next project milestone.',
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TextButton(
                              onPressed: () => composer.text = prompt,
                              child: Text(prompt),
                            ),
                          ),
                      ],
                    ),
                  );
                }
                if (i == messages.length) {
                  return _message({
                    'role': 'assistant',
                    'content': partial,
                  }, live: true);
                }
                return _message(messages[i]);
              },
            ),
          ),
        ),
        if (ai.running || ai.sending)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Preparing your reply… You can return to this conversation later.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        if (ai.pending != null &&
            !ai.running &&
            !ai.sending &&
            ai.error != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Pill(
              'Retry saved message',
              onPressed: () => send(retry: ai.pending),
            ),
          ),
        if (!ai.available && !ai.loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Saved chats remain available. Reconnect the workspace or a model in Models to reply.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        Focus(
          onKeyEvent: (_, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.enter &&
                !HardwareKeyboard.instance.isShiftPressed &&
                !composer.value.composing.isValid) {
              if (!disabled && ai.available) unawaited(send());
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: TextField(
            controller: composer,
            enabled: !disabled,
            minLines: 1,
            maxLines: 4,
            maxLength: 4000,
            decoration: const InputDecoration(
              labelText: 'Message Gideon',
              counterText: '',
              hintText: 'Message Gideon…',
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: aiChoice(
                'Conversation project',
                ai.project,
                aiProjects(ai),
                ai.chat != null || disabled
                    ? null
                    : (v) => setState(() => ai.project = v),
              ),
            ),
            const SizedBox(width: 12),
            ValueListenableBuilder(
              valueListenable: composer,
              builder: (_, value, _) => Pill(
                'Send message',
                icon: Icons.arrow_upward,
                iconOnly: true,
                primary: true,
                onPressed:
                    disabled || !ai.available || value.text.trim().isEmpty
                    ? null
                    : send,
              ),
            ),
          ],
        ),
        if (ai.collaborating)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Relevant conversation, memory and sources are shared with Google. Manage this in Models.',
              style: TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _message(AiObject message, {bool live = false}) {
    final assistant = message['role'] == 'assistant';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: AiCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              assistant
                  ? live
                        ? 'Gideon · Writing'
                        : 'Gideon'
                  : 'You',
              style: const TextStyle(fontSize: 12, color: Color(0xffb7b5c0)),
            ),
            const SizedBox(height: 10),
            SelectableText(aiText(message['content'])),
            if (aiText(message['notice']).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(aiText(message['notice'])),
              ),
            if (['failed', 'interrupted'].contains(message['status']) &&
                !assistant)
              TextButton(
                onPressed: ai.sending || ai.running
                    ? null
                    : () => send(retry: message),
                child: const Text('Retry reply'),
              ),
            if (assistant && !live) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => remember(message),
                    child: const Text('Remember…'),
                  ),
                  TextButton(
                    onPressed: () => task(message),
                    child: const Text('Review as task'),
                  ),
                  TextButton(
                    onPressed: () => Clipboard.setData(
                      ClipboardData(text: aiText(message['content'])),
                    ),
                    child: const Text('Copy'),
                  ),
                ],
              ),
              if (aiList(message['sources']).isNotEmpty)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    'Sources & memory used · ${aiList(message['sources']).length}',
                  ),
                  children: [
                    for (final source in aiList(message['sources']))
                      ListTile(
                        title: Text('[${source['number']}] ${source['title']}'),
                        subtitle: SelectableText(
                          '${aiText(source['excerpt'])}\n${aiText(source['source'])}',
                        ),
                        trailing:
                            Uri.tryParse(aiText(source['source']))?.scheme ==
                                'https'
                            ? IconButton(
                                tooltip: 'Open source',
                                icon: const Icon(Icons.open_in_new),
                                onPressed: () => launchUrl(
                                  Uri.parse(aiText(source['source'])),
                                  mode: LaunchMode.externalApplication,
                                ),
                              )
                            : null,
                      ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}
