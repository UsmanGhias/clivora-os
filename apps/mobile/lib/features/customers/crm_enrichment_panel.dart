import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cloud/cloud_crm_enrichment_repository.dart';
import '../../core/cloud/supabase_auth_helper.dart';
import '../../core/services/feature_flags_service.dart';
import '../../core/theme/clivora_colors.dart';

/// Freelancer-only CRM enrichment (matches web CrmEnrichmentPanel). Hidden when flag off.
class CrmEnrichmentPanel extends ConsumerStatefulWidget {
  const CrmEnrichmentPanel({super.key, this.cloudCustomerId, this.localCustomerId});

  final String? cloudCustomerId;
  final int? localCustomerId;

  @override
  ConsumerState<CrmEnrichmentPanel> createState() => _CrmEnrichmentPanelState();
}

class _CrmEnrichmentPanelState extends ConsumerState<CrmEnrichmentPanel> {
  bool _enabled = false;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _resolvedCloudId;
  List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _activities = [];
  int? _score;
  List<Map<String, dynamic>> _dupes = [];
  final _companyCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _companyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final on = await ref.read(featureFlagsServiceProvider).crmEnrichment();
    String? cloudId = widget.cloudCustomerId;
    if (cloudId == null && widget.localCustomerId != null) {
      try {
        final uid = SupabaseAuthHelper.currentUid;
        if (uid != null) {
          final row = await SupabaseAuthHelper.client
              .from('crm_customers')
              .select('id')
              .eq('owner_uid', uid)
              .eq('local_id', widget.localCustomerId!)
              .maybeSingle();
          cloudId = row?['id'] as String?;
        }
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _enabled = on;
      _resolvedCloudId = cloudId;
      _loading = false;
    });
    if (!on) return;
    await _refresh();
  }

  Future<void> _refresh() async {
    final repo = ref.read(cloudCrmEnrichmentRepositoryProvider);
    try {
      final companies = await repo.listCompanies();
      final activities = _resolvedCloudId == null
          ? <Map<String, dynamic>>[]
          : await repo.listActivities(customerId: _resolvedCloudId);
      if (!mounted) return;
      setState(() {
        _companies = companies;
        _activities = activities;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (!_enabled) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('CRM enrichment', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              'Companies, timeline, lead score, duplicates (same as web when enabled).',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ClivoraColors.textSecondary),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _companyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Company name',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          if (_companyCtrl.text.trim().isEmpty) return;
                          setState(() => _busy = true);
                          try {
                            await ref.read(cloudCrmEnrichmentRepositoryProvider).upsertCompany(
                                  name: _companyCtrl.text,
                                );
                            _companyCtrl.clear();
                            await _refresh();
                          } catch (e) {
                            setState(() => _error = '$e');
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        },
                  child: const Text('Add'),
                ),
              ],
            ),
            if (_companies.isNotEmpty) ...[
              const SizedBox(height: 8),
              ..._companies.take(6).map((c) => Text('• ${c['name']}', style: const TextStyle(fontSize: 13))),
            ],
            if (widget.cloudCustomerId != null || _resolvedCloudId != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _noteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Activity title',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            final cid = _resolvedCloudId;
                            if (cid == null || _noteCtrl.text.trim().isEmpty) return;
                            setState(() => _busy = true);
                            try {
                              await ref.read(cloudCrmEnrichmentRepositoryProvider).addActivity(
                                    customerId: cid,
                                    title: _noteCtrl.text,
                                  );
                              _noteCtrl.clear();
                              await _refresh();
                            } catch (e) {
                              setState(() => _error = '$e');
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          },
                    child: const Text('Log'),
                  ),
                ],
              ),
              ..._activities.take(8).map(
                    (a) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('${a['activity_type']}: ${a['title']}', style: const TextStyle(fontSize: 13)),
                    ),
                  ),
              OutlinedButton(
                onPressed: _busy || _resolvedCloudId == null
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          final repo = ref.read(cloudCrmEnrichmentRepositoryProvider);
                          final score = await repo.recomputeLeadScore(_resolvedCloudId!);
                          final dupes = await repo.findDuplicates(_resolvedCloudId!);
                          if (!mounted) return;
                          setState(() {
                            _score = score;
                            _dupes = dupes.where((d) => ((d['score'] as num?)?.toInt() ?? 0) > 0).toList();
                          });
                        } catch (e) {
                          setState(() => _error = '$e');
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                child: const Text('Recompute lead score & duplicates'),
              ),
              if (_score != null) Text('Lead score: $_score', style: const TextStyle(fontWeight: FontWeight.w600)),
              ..._dupes.map(
                (d) => Text(
                  'Possible duplicate: ${d['contact_person']} (${d['company']}) - ${d['score']}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
