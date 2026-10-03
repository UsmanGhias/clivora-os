import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_service.dart';
import '../../core/theme/clivora_colors.dart';
import '../../data/database/database.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_scaffold.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/filter_chip_row.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  String _type = 'all';

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesProvider(_type == 'all' ? null : _type));

    return ClivoraScaffold(
      title: 'Notes',
      showBackButton: true,
      action: ClivoraIconButton(
        icon: Icons.add,
        onPressed: () => context.push('/notes/new'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilterChipRow(
            options: const ['all', 'personal', 'client', 'project'],
            selected: _type,
            onSelected: (v) => setState(() => _type = v),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: notesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (notes) {
                if (notes.isEmpty) {
                  return EmptyState(
                    icon: Icons.note_outlined,
                    message: 'No notes yet',
                    actionLabel: 'Create your first note',
                    onAction: () => context.push('/notes/new'),
                  );
                }
                return ListView.separated(
                  itemCount: notes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    return Dismissible(
                      key: ValueKey(note.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (_) async {
                        return await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete note?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                                ],
                              ),
                            ) ??
                            false;
                      },
                      onDismissed: (_) => ref.read(databaseProvider).deleteNote(note.id),
                      child: ListTile(
                        onTap: () => context.push('/notes/${note.id}/edit'),
                        tileColor: Theme.of(context).cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Theme.of(context).dividerColor),
                        ),
                        leading: Icon(_typeIcon(note.type), color: ClivoraColors.primaryPurple),
                        title: Text(note.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          note.content.isNotEmpty
                              ? note.content
                              : DateFormat('MMM d, yyyy').format(note.updatedAt),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'client':
        return Icons.person_outline;
      case 'project':
        return Icons.work_outline;
      default:
        return Icons.note_outlined;
    }
  }
}

class NoteFormScreen extends ConsumerStatefulWidget {
  const NoteFormScreen({super.key, this.noteId});

  final int? noteId;

  @override
  ConsumerState<NoteFormScreen> createState() => _NoteFormScreenState();
}

class _NoteFormScreenState extends ConsumerState<NoteFormScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _type = 'personal';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.noteId != null) {
      _load();
    } else {
      _loading = false;
    }
  }

  Future<void> _load() async {
    final note = await ref.read(databaseProvider).getNote(widget.noteId!);
    if (note != null && mounted) {
      _titleController.text = note.title;
      _contentController.text = note.content;
      _type = note.type;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title is required')));
      return;
    }
    final db = ref.read(databaseProvider);
    if (widget.noteId != null) {
      final existing = await db.getNote(widget.noteId!);
      if (existing != null) {
        await db.updateNote(existing.copyWith(
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          type: _type,
          updatedAt: DateTime.now(),
        ));
      }
    } else {
      await db.insertNote(NotesCompanion.insert(
        ownerUserId: ref.read(authStateProvider).valueOrNull!.id,
        title: _titleController.text.trim(),
        content: Value(_contentController.text.trim()),
        type: Value(_type),
      ));
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.noteId != null ? 'Edit Note' : 'New Note'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'TITLE', hintText: 'Note title'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'TYPE'),
            items: const [
              DropdownMenuItem(value: 'personal', child: Text('Personal')),
              DropdownMenuItem(value: 'client', child: Text('Client')),
              DropdownMenuItem(value: 'project', child: Text('Project')),
            ],
            onChanged: (v) => setState(() => _type = v ?? 'personal'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _contentController,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'CONTENT',
              hintText: 'Write your note here...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(onPressed: _save, child: const Text('Save Note')),
        ],
      ),
    );
  }
}
