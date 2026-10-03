import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/user_roles.dart';
import '../../core/cloud/supabase_auth_helper.dart';
import '../../core/services/marketplace/connect_marketplace_service.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/clivora_scaffold.dart';

const _savedPrefsKey = 'connect_saved_ids';
const _teal = Color(0xFF0F766E);

/// CLIVORA Connect. Pro Plus marketplace for freelancers and clients.
class ConnectMarketplaceScreen extends ConsumerStatefulWidget {
  const ConnectMarketplaceScreen({super.key});

  @override
  ConsumerState<ConnectMarketplaceScreen> createState() =>
      _ConnectMarketplaceScreenState();
}

class _ConnectMarketplaceScreenState
    extends ConsumerState<ConnectMarketplaceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _skillCtrl = TextEditingController();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _profiles = [];
  List<Map<String, dynamic>> _needs = [];
  List<Map<String, dynamic>> _requests = [];
  Set<String> _savedIds = {};
  String _profileFilter = 'all'; // all | verified | available
  String _talentSort = 'featured'; // featured | rating | newest
  String _inboxFilter = 'all'; // all | pending | accepted | declined
  String? _categoryFilter; // null = all categories
  bool _showSavedOnly = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedIds();
      _reload();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _skillCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedIds() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(
      () => _savedIds = (prefs.getStringList(_savedPrefsKey) ?? []).toSet(),
    );
  }

  Future<void> _persistSavedIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_savedPrefsKey, _savedIds.toList()..sort());
  }

  Future<void> _toggleSaved(Map<String, dynamic> row) async {
    final id = _connectRowId(row);
    if (id.isEmpty) return;
    setState(() {
      if (_savedIds.contains(id)) {
        _savedIds.remove(id);
      } else {
        _savedIds.add(id);
      }
    });
    await _persistSavedIds();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cloudOk = await SupabaseAuthHelper.ensureCloudSession();
      if (!cloudOk) {
        if (!mounted) return;
        setState(() {
          _error =
              'Cloud session expired. Sign out and sign in again to load Connect.';
          _loading = false;
          _profiles = [];
          _needs = [];
          _requests = [];
        });
        return;
      }
      final svc = ref.read(connectMarketplaceServiceProvider);
      final user = ref.read(authStateProvider).valueOrNull;
      final isClient = isClientUser(user);
      // Clients browse freelancers; freelancers browse client about-listings.
      final profiles = isClient
          ? await svc.browseFreelancers(skill: _skillCtrl.text, sort: _talentSort)
          : await svc.browseClients(skill: _skillCtrl.text, sort: _talentSort);
      final needs = await svc.browseNeeds();
      final requests = await svc.myRequests();
      if (!mounted) return;
      setState(() {
        _profiles = profiles;
        _needs = needs;
        _requests = requests;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _showSaved() {
    _tabs.animateTo(0);
    setState(() => _showSavedOnly = true);
  }

  @override
  Widget build(BuildContext context) {
    final hasAccess = ref.watch(isProPlusProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    final isClient = isClientUser(user);
    final scheme = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    return ClivoraScaffold(
      title: 'Connect',
      showBackButton: false,
      action: IconButton(
        tooltip: 'Refresh',
        onPressed: _loading ? null : _reload,
        icon: const Icon(Icons.refresh),
      ),
      body: Column(
        children: [
          if (hasAccess) const _ConnectCreditsBanner(),
          _QuickActionsRow(
            isClient: isClient,
            savedCount: _savedIds.length,
            onListing: () => hasAccess
                ? context.push('/connect/listing')
                : context.push('/upgrade'),
            onPostJob: () => hasAccess
                ? context.push('/connect/need')
                : context.push('/upgrade'),
            onSaved: _showSaved,
            onInbox: () => _tabs.animateTo(2),
          ),
                TabBar(
                  controller: _tabs,
                  labelColor: scheme.primary,
                  unselectedLabelColor: scheme.onSurface.withValues(
                    alpha: 0.55,
                  ),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                  tabs: [
                    Tab(text: isClient ? 'Talent' : 'Clients'),
                    Tab(text: isClient ? 'Jobs' : 'Open jobs'),
                    Tab(text: 'Inbox (${_requests.length})'),
                  ],
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _error!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.error, fontSize: 12),
                    ),
                  ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: _reload,
                          child: TabBarView(
                            controller: _tabs,
                            children: [
                              _TalentTab(
                                profiles: _profiles,
                                skillCtrl: _skillCtrl,
                                filter: _profileFilter,
                                sort: _talentSort,
                                categoryFilter: _categoryFilter,
                                showSavedOnly: _showSavedOnly,
                                savedIds: _savedIds,
                                onFilterChanged: (filter) {
                                  setState(() {
                                    _profileFilter = filter;
                                    _showSavedOnly = false;
                                  });
                                },
                                onCategoryChanged: (cat) =>
                                    setState(() => _categoryFilter = cat),
                                onSortChanged: (sort) {
                                  setState(() => _talentSort = sort);
                                  _reload();
                                },
                                onClearSavedFilter: () =>
                                    setState(() => _showSavedOnly = false),
                                onSearch: _reload,
                                onOpenDetail: (row) => _showProfileDetail(
                                  row,
                                  browseClients: !isClient,
                                  onContact: () => _contactProfile(row),
                                ),
                                onToggleSaved: _toggleSaved,
                                browseClients: !isClient,
                                onBrowseOpenJobs: !isClient
                                    ? () => _tabs.animateTo(1)
                                    : null,
                              ),
                              _NeedsTab(
                                needs: _needs,
                                isClient: isClient,
                                categoryFilter: _categoryFilter,
                                onCategoryChanged: (cat) =>
                                    setState(() => _categoryFilter = cat),
                                onCreate: () => context.push('/connect/need'),
                                onOpenDetail: (row) => _showNeedDetail(
                                  row,
                                  canApply: !isClient,
                                  onApply: () => _contactNeed(row),
                                ),
                              ),
                              _InboxTab(
                                requests: _requests,
                                myUid: ref
                                    .read(connectMarketplaceServiceProvider)
                                    .currentUserId,
                                filter: _inboxFilter,
                                onFilterChanged: (f) =>
                                    setState(() => _inboxFilter = f),
                                onAccept: (id) async {
                                  await ref
                                      .read(connectMarketplaceServiceProvider)
                                      .respondToRequest(id, accept: true);
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Accepted. Identity unlocked.',
                                      ),
                                    ),
                                  );
                                  await _reload();
                                },
                                onDecline: (id) async {
                                  await ref
                                      .read(connectMarketplaceServiceProvider)
                                      .respondToRequest(id, accept: false);
                                  await _reload();
                                },
                                onReview: (row) => _leaveConnectReview(row),
                                onLinkWorkspace: (row) async {
                                  try {
                                    final id = await ref
                                        .read(connectMarketplaceServiceProvider)
                                        .linkAcceptedPartnerToWorkspace(row);
                                    if (!mounted) return;
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          id == null
                                              ? 'Could not link partner.'
                                              : isClient
                                                  ? 'Partner linked. Open your portal to continue.'
                                                  : 'Added to Clients.',
                                        ),
                                      ),
                                    );
                                    if (id != null && !isClient) {
                                      router.push('/customers');
                                    } else if (id != null && isClient) {
                                      router.push('/client-portal');
                                    }
                                  } catch (e) {
                                    if (!mounted) return;
                                    messenger.showSnackBar(
                                      SnackBar(content: Text('$e')),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Future<void> _leaveConnectReview(Map<String, dynamic> row) async {
    final myUid = ref.read(connectMarketplaceServiceProvider).currentUserId;
    if (myUid == null) return;
    final peerId = row['to_user_id'] == myUid
        ? row['from_user_id'] as String?
        : row['to_user_id'] as String?;
    if (peerId == null) return;

    var rating = 5;
    final bodyCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Leave a Connect review'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 1; i <= 5; i++)
                        IconButton(
                          onPressed: () => setLocal(() => rating = i),
                          icon: Icon(
                            i <= rating ? Icons.star : Icons.star_border,
                            color: Colors.amber.shade700,
                          ),
                        ),
                    ],
                  ),
                  TextField(
                    controller: bodyCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Optional feedback',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(connectMarketplaceServiceProvider).leaveReview(
            toUserId: peerId,
            rating: rating,
            body: bodyCtrl.text,
            requestId: row['id'] as String?,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted. Thanks!')),
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      bodyCtrl.dispose();
    }
  }

  Future<void> _contactProfile(Map<String, dynamic> row) async {
    final message = await _askMessage(
      'Introduce yourself without sharing personal details yet.',
    );
    if (message == null || message.isEmpty) return;
    try {
      await ref
          .read(connectMarketplaceServiceProvider)
          .sendContactRequest(
            toUserId: row['user_id'] as String,
            targetProfileId: row['id'] as String?,
            message: message,
          );
      await ref
          .read(connectMarketplaceServiceProvider)
          .logConnectEvent('connect_request_sent');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request sent. Email stays hidden until accept.'),
          ),
        );
        await _reload();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _contactNeed(Map<String, dynamic> row) async {
    final isCrawled = row['is_crawled_job'] == true;
    final companyName = row['company_name'] as String?;
    final message = await _askMessage(
      isCrawled
          ? 'Pitch your fit for ${companyName ?? 'this role'}. Keep 100% of your earnings (\$0 Platform Fee).'
          : 'Pitch your fit for this need. Stay anonymous for now.',
    );
    if (message == null || message.isEmpty) return;
    try {
      final svc = ref.read(connectMarketplaceServiceProvider);
      if (isCrawled) {
        await svc.submitJobProposal(
          jobId: row['id'] as String,
          message: message,
          companyName: companyName,
          companyEmail: row['company_email'] as String?,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Proposal submitted! Hiring team will receive review details.'),
            ),
          );
          await _reload();
        }
      } else {
        await svc.sendContactRequest(
          toUserId: row['client_user_id'] as String,
          targetNeedId: row['id'] as String?,
          message: message,
        );
        await svc.logConnectEvent('connect_need_pitch_sent');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pitch sent anonymously.')),
          );
          await _reload();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<String?> _askMessage(String hint) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit proposal'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _showProfileDetail(
    Map<String, dynamic> row, {
    required bool browseClients,
    required VoidCallback onContact,
  }) async {
    final title =
        row['display_title'] as String? ??
        (browseClients ? 'Client' : 'Freelancer');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ConnectDetailSheet(
        title: title,
        subtitle: row['headline'] as String? ?? '',
        description: row['bio'] as String? ?? '',
        skills: _stringList(row['skills']),
        moneyLabel: row['rate_band'] as String? ?? 'Negotiable',
        moneyCaption: 'Rate',
        location: row['location_label'] as String?,
        avgRating: (row['avg_rating'] as num?)?.toDouble(),
        reviewCount: (row['review_count'] as num?)?.toInt(),
        verified: row['is_verified'] == true,
        ctaLabel: 'Contact',
        onCta: () {
          Navigator.pop(ctx);
          onContact();
        },
      ),
    );
  }

  Future<void> _showNeedDetail(
    Map<String, dynamic> row, {
    required bool canApply,
    required VoidCallback onApply,
  }) async {
    final title = row['title'] as String? ?? 'Job';
    final company = row['company_name'] as String? ?? '';
    final loc = row['location'] as String? ?? row['location_label'] as String?;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ConnectDetailSheet(
        title: title,
        subtitle: company.isNotEmpty ? company : 'CLIVORA Connect',
        description: row['summary'] as String? ?? '',
        skills: _stringList(row['skills']),
        moneyLabel: row['budget_band'] as String? ?? 'Negotiable',
        moneyCaption: 'Compensation',
        location: loc,
        avgRating: null,
        reviewCount: null,
        verified: false,
        sourceUrl: row['source_url'] as String?,
        isExternal: row['is_external'] == true,
        ctaLabel: canApply ? 'Apply via CLIVORA (\$0 Platform Fee)' : null,
        onCta: canApply
            ? () {
                Navigator.pop(ctx);
                onApply();
              }
            : null,
      ),
    );
  }
}

class _ConnectCreditsBanner extends ConsumerStatefulWidget {
  const _ConnectCreditsBanner();
  @override
  ConsumerState<_ConnectCreditsBanner> createState() => _ConnectCreditsBannerState();
}

class _ConnectCreditsBannerState extends ConsumerState<_ConnectCreditsBanner> {
  String _label = 'Loading credits…';
  bool _needsProfile = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final s = await ref.read(connectMarketplaceServiceProvider).creditSummary();
        if (!mounted) return;
        if (s == null) {
          setState(() {
            _needsProfile = true;
            _label = 'Finish your Connect listing to unlock credits';
          });
        } else {
          setState(() {
            _needsProfile = false;
            _label = s.label;
          });
        }
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _needsProfile = true;
          _label = 'Finish your Connect listing to unlock credits';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _needsProfile ? () => context.push('/connect/listing') : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.toll_outlined, size: 18, color: primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _needsProfile
                      ? '$_label · tap to edit listing'
                      : '$_label · contact/proposal 1 · publish 3 · \$0 fee',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (_needsProfile) Icon(Icons.chevron_right, size: 18, color: primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({
    required this.isClient,
    required this.savedCount,
    required this.onListing,
    required this.onPostJob,
    required this.onSaved,
    required this.onInbox,
  });

  final bool isClient;
  final int savedCount;
  final VoidCallback onListing;
  final VoidCallback onPostJob;
  final VoidCallback onSaved;
  final VoidCallback onInbox;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          _ActionTextButton(
            icon: Icons.badge_outlined,
            label: 'My listing',
            onPressed: onListing,
          ),
          if (isClient)
            _ActionTextButton(
              icon: Icons.add_business_outlined,
              label: 'Post job',
              onPressed: onPostJob,
            ),
          _ActionTextButton(
            icon: Icons.favorite_border,
            label: savedCount == 0 ? 'Saved' : 'Saved $savedCount',
            onPressed: onSaved,
          ),
          _ActionTextButton(
            icon: Icons.inbox_outlined,
            label: 'Inbox',
            onPressed: onInbox,
          ),
        ],
      ),
    );
  }
}

class _ActionTextButton extends StatelessWidget {
  const _ActionTextButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: TextButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        ),
      ),
    );
  }
}

class _TalentTab extends StatelessWidget {
  const _TalentTab({
    required this.profiles,
    required this.skillCtrl,
    required this.filter,
    required this.sort,
    required this.categoryFilter,
    required this.showSavedOnly,
    required this.savedIds,
    required this.onFilterChanged,
    required this.onCategoryChanged,
    required this.onSortChanged,
    required this.onClearSavedFilter,
    required this.onSearch,
    required this.onOpenDetail,
    required this.onToggleSaved,
    this.browseClients = false,
    this.onBrowseOpenJobs,
  });

  final List<Map<String, dynamic>> profiles;
  final TextEditingController skillCtrl;
  final String filter;
  final String sort;
  final String? categoryFilter;
  final bool showSavedOnly;
  final Set<String> savedIds;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String> onSortChanged;
  final VoidCallback onClearSavedFilter;
  final VoidCallback onSearch;
  final void Function(Map<String, dynamic>) onOpenDetail;
  final Future<void> Function(Map<String, dynamic>) onToggleSaved;
  final bool browseClients;
  final VoidCallback? onBrowseOpenJobs;

  @override
  Widget build(BuildContext context) {
    final filtered = profiles.where((row) {
      final id = _connectRowId(row);
      if (showSavedOnly && !savedIds.contains(id)) return false;
      if (filter == 'verified' && row['is_verified'] != true) return false;
      if (filter == 'available' &&
          (row['availability'] as String? ?? '').toLowerCase() != 'available') {
        return false;
      }
      if (!_matchesCategory(row, categoryFilter)) return false;
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 88),
      children: [
        _TalentControls(
          skillCtrl: skillCtrl,
          filter: filter,
          sort: sort,
          categoryFilter: categoryFilter,
          showSavedOnly: showSavedOnly,
          browseClients: browseClients,
          onFilterChanged: onFilterChanged,
          onCategoryChanged: onCategoryChanged,
          onSortChanged: onSortChanged,
          onClearSavedFilter: onClearSavedFilter,
          onSearch: onSearch,
        ),
        if (filtered.isEmpty)
          _CompactEmpty(
            icon: Icons.person_search_outlined,
            text: showSavedOnly
                ? 'No saved listings yet.'
                : browseClients
                ? 'No client About listings yet. Browse Open jobs for work to apply to.'
                : 'No freelancers yet.',
            actionLabel: browseClients && !showSavedOnly ? 'Browse Open jobs' : null,
            onAction: browseClients && !showSavedOnly ? onBrowseOpenJobs : null,
          )
        else
          ..._withDividers(
            context,
            filtered.map(
              (row) => _ProfileFeedRow(
                row: row,
                browseClients: browseClients,
                saved: savedIds.contains(_connectRowId(row)),
                onTap: () => onOpenDetail(row),
                onToggleSaved: () => onToggleSaved(row),
              ),
            ),
          ),
      ],
    );
  }
}

class _TalentControls extends StatelessWidget {
  const _TalentControls({
    required this.skillCtrl,
    required this.filter,
    required this.sort,
    required this.categoryFilter,
    required this.showSavedOnly,
    required this.browseClients,
    required this.onFilterChanged,
    required this.onCategoryChanged,
    required this.onSortChanged,
    required this.onClearSavedFilter,
    required this.onSearch,
  });

  final TextEditingController skillCtrl;
  final String filter;
  final String sort;
  final String? categoryFilter;
  final bool showSavedOnly;
  final bool browseClients;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String> onSortChanged;
  final VoidCallback onClearSavedFilter;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        children: [
          SizedBox(
            height: 42,
            child: TextField(
              controller: skillCtrl,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                hintText: browseClients ? 'Filter clients' : 'Filter by skill',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  onPressed: onSearch,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) => onSearch(),
            ),
          ),
          const SizedBox(height: 6),
          _CategoryChipRow(
            selected: categoryFilter,
            onChanged: onCategoryChanged,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final entry in const [
                        ('all', 'All'),
                        ('verified', 'Verified'),
                        ('available', 'Available'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(entry.$2),
                            selected: filter == entry.$1 && !showSavedOnly,
                            onSelected: (_) => onFilterChanged(entry.$1),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      if (showSavedOnly)
                        InputChip(
                          label: const Text('Saved'),
                          selected: true,
                          onDeleted: onClearSavedFilter,
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.sort, size: 15, color: scheme.onSurfaceVariant),
              const SizedBox(width: 3),
              PopupMenuButton<String>(
                initialValue: sort,
                onSelected: onSortChanged,
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'featured', child: Text('Featured')),
                  PopupMenuItem(value: 'rating', child: Text('Top rated')),
                  PopupMenuItem(value: 'newest', child: Text('Newest')),
                ],
                child: Text(
                  sort == 'rating'
                      ? 'Top rated'
                      : sort == 'newest'
                          ? 'Newest'
                          : 'Featured',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileFeedRow extends StatelessWidget {
  const _ProfileFeedRow({
    required this.row,
    required this.browseClients,
    required this.saved,
    required this.onTap,
    required this.onToggleSaved,
  });

  final Map<String, dynamic> row;
  final bool browseClients;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback onToggleSaved;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final title =
        row['display_title'] as String? ??
        (browseClients ? 'Client' : 'Freelancer');
    final headline = row['headline'] as String? ?? '';
    final skills = _stringList(row['skills']);
    final meta = [
      row['rate_band'] as String? ?? 'Negotiable',
      ...skills.take(2),
    ].where((value) => value.trim().isNotEmpty).join(' · ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              _AvatarDot(
                text: title,
                fallback: browseClients ? 'C' : 'F',
                avatarUrl: row['avatar_url'] as String?,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (row['is_verified'] == true) ...[
                          const SizedBox(width: 5),
                          const Icon(Icons.verified, color: _teal, size: 15),
                        ],
                      ],
                    ),
                    if (headline.isNotEmpty)
                      Text(
                        headline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: onSurface.withValues(alpha: 0.68),
                          fontSize: 12.5,
                        ),
                      ),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _teal,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      () {
                        final count =
                            (row['review_count'] as num?)?.toInt() ?? 0;
                        final avg =
                            (row['avg_rating'] as num?)?.toDouble() ?? 0;
                        final since = row['created_at'] as String?;
                        final parts = <String>[];
                        if (count > 0 && avg > 0) {
                          parts.add('★ ${avg.toStringAsFixed(1)} ($count)');
                        } else {
                          parts.add('New');
                        }
                        if (since != null && since.length >= 7) {
                          parts.add('Since ${since.substring(0, 7)}');
                        }
                        final completion =
                            (row['completion_rate'] as num?)?.toDouble() ?? 0;
                        if (completion > 0) {
                          parts.add('${completion.toStringAsFixed(0)}% done');
                        }
                        return parts.join(' · ');
                      }(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: onSurface.withValues(alpha: 0.55),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: saved ? 'Unsave' : 'Save',
                onPressed: onToggleSaved,
                icon: Icon(
                  saved ? Icons.favorite : Icons.favorite_border,
                  color: saved ? _teal : onSurface.withValues(alpha: 0.45),
                  size: 20,
                ),
                visualDensity: VisualDensity.compact,
              ),
              Icon(
                Icons.chevron_right,
                color: onSurface.withValues(alpha: 0.35),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NeedsTab extends StatelessWidget {
  const _NeedsTab({
    required this.needs,
    required this.isClient,
    required this.categoryFilter,
    required this.onCategoryChanged,
    required this.onCreate,
    required this.onOpenDetail,
  });

  final List<Map<String, dynamic>> needs;
  final bool isClient;
  final String? categoryFilter;
  final ValueChanged<String?> onCategoryChanged;
  final VoidCallback onCreate;
  final void Function(Map<String, dynamic>) onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final filtered =
        needs.where((row) => _matchesCategory(row, categoryFilter)).toList();

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 88),
      children: [
        _CategoryChipRow(
          selected: categoryFilter,
          onChanged: onCategoryChanged,
        ),
        if (isClient)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Post job'),
              style: TextButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ),
        if (filtered.isEmpty)
          _CompactEmpty(
            icon: Icons.work_outline,
            text: isClient ? 'No jobs posted yet.' : 'No open jobs yet.',
          )
        else
          ..._withDividers(
            context,
            filtered.map(
              (row) => _NeedFeedRow(
                row: row,
                onTap: () => onOpenDetail(row),
              ),
            ),
          ),
      ],
    );
  }
}

class _NeedFeedRow extends StatelessWidget {
  const _NeedFeedRow({required this.row, required this.onTap});

  final Map<String, dynamic> row;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final title = row['title'] as String? ?? 'Job';
    final summary = row['summary'] as String? ?? '';
    final budget = row['budget_band'] as String? ?? 'Negotiable';
    final skills = _stringList(row['skills']);
    final skillLine = skills.take(3).where((s) => s.trim().isNotEmpty).join(' · ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _InitialDot(text: title, fallback: 'J'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    if (row['company_name'] != null && (row['company_name'] as String).isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${row['company_name']}${row['location'] != null ? ' · ${row['location']}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: onSurface.withValues(alpha: 0.65),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (summary.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: onSurface.withValues(alpha: 0.68),
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          budget,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _teal,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: _teal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '\$0 Fee',
                            style: TextStyle(
                              color: _teal,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: (row['is_external'] == true)
                                ? Colors.blueGrey.withValues(alpha: 0.12)
                                : const Color(0xFF047857).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            (row['is_external'] == true)
                                ? 'Curated Remote'
                                : 'Clivora Client',
                            style: TextStyle(
                              color: (row['is_external'] == true)
                                  ? Colors.blueGrey.shade800
                                  : const Color(0xFF047857),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (skillLine.isNotEmpty)
                      Text(
                        skillLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: onSurface.withValues(alpha: 0.5),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Icon(
                  Icons.chevron_right,
                  color: onSurface.withValues(alpha: 0.35),
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InboxTab extends StatelessWidget {
  const _InboxTab({
    required this.requests,
    required this.myUid,
    required this.filter,
    required this.onFilterChanged,
    required this.onAccept,
    required this.onDecline,
    required this.onReview,
    required this.onLinkWorkspace,
  });

  final List<Map<String, dynamic>> requests;
  final String? myUid;
  final String filter;
  final ValueChanged<String> onFilterChanged;
  final Future<void> Function(String id) onAccept;
  final Future<void> Function(String id) onDecline;
  final Future<void> Function(Map<String, dynamic> row) onReview;
  final Future<void> Function(Map<String, dynamic> row) onLinkWorkspace;

  @override
  Widget build(BuildContext context) {
    final filtered = filter == 'all'
        ? requests
        : requests
              .where((r) => (r['status'] as String? ?? 'pending') == filter)
              .toList();

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 88),
      children: [
        _InboxFilters(filter: filter, onFilterChanged: onFilterChanged),
        if (requests.isEmpty)
          const _CompactEmpty(
            icon: Icons.inbox_outlined,
            text: 'No Connect requests yet.',
          )
        else if (filtered.isEmpty)
          const _CompactEmpty(
            icon: Icons.filter_alt_off_outlined,
            text: 'No requests here.',
          )
        else
          ..._withDividers(
            context,
            filtered.map((row) {
              final incoming = row['to_user_id'] == myUid;
              final status = row['status'] as String? ?? 'pending';
              return _InboxFeedRow(
                row: row,
                incoming: incoming,
                status: status,
                onAccept: () => onAccept(row['id'] as String),
                onDecline: () => onDecline(row['id'] as String),
                onReview: () => onReview(row),
                onLinkWorkspace: () => onLinkWorkspace(row),
              );
            }),
          ),
      ],
    );
  }
}

class _InboxFilters extends StatelessWidget {
  const _InboxFilters({required this.filter, required this.onFilterChanged});

  final String filter;
  final ValueChanged<String> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          for (final f in const ['all', 'pending', 'accepted', 'declined'])
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(f[0].toUpperCase() + f.substring(1)),
                selected: filter == f,
                onSelected: (_) => onFilterChanged(f),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }
}

class _InboxFeedRow extends StatelessWidget {
  const _InboxFeedRow({
    required this.row,
    required this.incoming,
    required this.status,
    required this.onAccept,
    required this.onDecline,
    required this.onReview,
    required this.onLinkWorkspace,
  });

  final Map<String, dynamic> row;
  final bool incoming;
  final String status;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onReview;
  final VoidCallback onLinkWorkspace;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final accepted = status == 'accepted';
    final title = incoming ? 'Incoming request' : 'Sent request';
    final partnerName =
        (incoming ? row['from_name'] : row['to_name']) as String?;
    final partnerEmail =
        (incoming ? row['from_email'] : row['to_email']) as String?;
    final message = row['message'] as String? ?? '';
    final meta = accepted
        ? 'Unlocked · ${partnerName ?? 'Partner'}${partnerEmail == null ? '' : ' · $partnerEmail'}'
        : (incoming ? 'Incoming' : 'Sent');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _InitialDot(
            text: accepted ? partnerName ?? title : title,
            fallback: incoming ? 'I' : 'S',
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _InboxStatusChip(status: status),
                  ],
                ),
                if (message.isNotEmpty)
                  Text(
                    message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: onSurface.withValues(alpha: 0.68),
                      fontSize: 12.5,
                    ),
                  ),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accepted ? _teal : onSurface.withValues(alpha: 0.56),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (incoming && status == 'pending') ...[
            IconButton(
              tooltip: 'Decline',
              onPressed: onDecline,
              icon: const Icon(Icons.close, size: 18),
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              tooltip: 'Accept',
              onPressed: onAccept,
              icon: const Icon(Icons.check, size: 18, color: _teal),
              visualDensity: VisualDensity.compact,
            ),
          ] else if (accepted) ...[
            IconButton(
              tooltip: 'Leave review',
              onPressed: onReview,
              icon: Icon(Icons.star_outline, size: 18, color: Colors.amber.shade800),
              visualDensity: VisualDensity.compact,
            ),
            TextButton(
              onPressed: onLinkWorkspace,
              style: TextButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Add'),
            ),
          ] else
            Icon(
              Icons.chevron_right,
              color: onSurface.withValues(alpha: 0.28),
              size: 20,
            ),
        ],
      ),
    );
  }
}

class _InitialDot extends StatelessWidget {
  const _InitialDot({required this.text, required this.fallback, this.avatarUrl});

  final String text;
  final String fallback;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    if (url != null && url.startsWith('http')) {
      return ClipOval(
        child: Image.network(
          url,
          width: 34,
          height: 34,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _letter(context),
        ),
      );
    }
    return _letter(context);
  }

  Widget _letter(BuildContext context) {
    final initial = _initialFor(text, fallback);
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _teal.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: const TextStyle(
          color: _teal,
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
      ),
    );
  }
}

typedef _AvatarDot = _InitialDot;

class _CompactEmpty extends StatelessWidget {
  const _CompactEmpty({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 32, color: onSurface.withValues(alpha: 0.35)),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: onSurface.withValues(alpha: 0.6),
              fontSize: 13,
              height: 1.35,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

List<Widget> _withDividers(BuildContext context, Iterable<Widget> rows) {
  final color = Theme.of(context).dividerColor.withValues(alpha: 0.55);
  final widgets = <Widget>[];
  for (final row in rows) {
    if (widgets.isNotEmpty) {
      widgets.add(Divider(height: 1, thickness: 0.6, color: color));
    }
    widgets.add(row);
  }
  return widgets;
}

List<String> _stringList(Object? value) {
  if (value is List) return value.map((e) => e.toString()).toList();
  return const [];
}

String _connectRowId(Map<String, dynamic> row) =>
    (row['id'] ?? row['user_id'] ?? '').toString();

String _initialFor(String value, String fallback) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return fallback;
  return trimmed.substring(0, 1).toUpperCase();
}

const _connectCategories = <String>[
  'Web & Software',
  'Design & Creative',
  'Sales & Marketing',
  'Writing',
  'Admin & Support',
  'Other',
];

const _categoryKeywords = <String, List<String>>{
  'Web & Software': [
    'web',
    'software',
    'dev',
    'code',
    'react',
    'flutter',
    'mobile',
    'api',
    'app',
  ],
  'Design & Creative': [
    'design',
    'ui',
    'ux',
    'brand',
    'figma',
    'creative',
    'illustrat',
  ],
  'Sales & Marketing': [
    'sales',
    'marketing',
    'seo',
    'ads',
    'growth',
    'content market',
  ],
  'Writing': ['writ', 'copy', 'blog', 'edit', 'content'],
  'Admin & Support': ['admin', 'support', 'va', 'assistant', 'ops'],
  'Other': <String>[],
};

bool _matchesCategory(Map<String, dynamic> row, String? category) {
  if (category == null || category.isEmpty || category == 'Other') return true;
  final keys = _categoryKeywords[category] ?? const <String>[];
  if (keys.isEmpty) return true;
  final skills = _stringList(row['skills']).join(' ').toLowerCase();
  final title = (row['display_title'] as String? ??
          row['title'] as String? ??
          '')
      .toLowerCase();
  final headline = (row['headline'] as String? ??
          row['summary'] as String? ??
          '')
      .toLowerCase();
  final hay = '$skills $title $headline';
  return keys.any(hay.contains);
}

class _CategoryChipRow extends StatelessWidget {
  const _CategoryChipRow({
    required this.selected,
    required this.onChanged,
  });

  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          for (final cat in _connectCategories)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(cat),
                selected: selected == cat,
                onSelected: (on) => onChanged(on ? cat : null),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }
}

class _InboxStatusChip extends StatelessWidget {
  const _InboxStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    late final Color bg;
    late final Color fg;
    late final String label;
    switch (normalized) {
      case 'accepted':
        bg = _teal.withValues(alpha: 0.14);
        fg = _teal;
        label = 'Accepted';
      case 'declined':
        bg = Colors.red.withValues(alpha: 0.12);
        fg = Colors.red.shade700;
        label = 'Declined';
      default:
        bg = Colors.amber.withValues(alpha: 0.18);
        fg = Colors.amber.shade900;
        label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ConnectDetailSheet extends StatelessWidget {
  const _ConnectDetailSheet({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.skills,
    required this.moneyLabel,
    required this.moneyCaption,
    required this.location,
    required this.avgRating,
    required this.reviewCount,
    required this.verified,
    required this.ctaLabel,
    required this.onCta,
    this.sourceUrl,
    this.isExternal = false,
  });

  final String title;
  final String subtitle;
  final String description;
  final List<String> skills;
  final String moneyLabel;
  final String moneyCaption;
  final String? location;
  final double? avgRating;
  final int? reviewCount;
  final bool verified;
  final String? ctaLabel;
  final VoidCallback? onCta;
  final String? sourceUrl;
  final bool isExternal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final hasRating =
        (reviewCount ?? 0) > 0 && (avgRating ?? 0) > 0;

    return Container(
      margin: const EdgeInsets.only(top: 48),
      padding: EdgeInsets.only(bottom: bottom),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (verified)
                    const Padding(
                      padding: EdgeInsets.only(left: 6, top: 2),
                      child: Icon(Icons.verified, color: _teal, size: 20),
                    ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.7),
                    height: 1.35,
                  ),
                ),
              if (isExternal) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.public, size: 14, color: Colors.blueGrey.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Curated Remote Listing · \$0 Platform Take Rate on CLIVORA',
                          style: TextStyle(
                            color: Colors.blueGrey.shade800,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DetailMetaChip(
                    icon: Icons.payments_outlined,
                    label: '$moneyCaption: $moneyLabel',
                  ),
                  if (location != null && location!.trim().isNotEmpty)
                    _DetailMetaChip(
                      icon: Icons.place_outlined,
                      label: location!.trim(),
                    ),
                  if (hasRating)
                    _DetailMetaChip(
                      icon: Icons.star_rounded,
                      label:
                          '${avgRating!.toStringAsFixed(1)} (${reviewCount!})',
                    ),
                ],
              ),
              if (description.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Description',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description.trim(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                    color: scheme.onSurface.withValues(alpha: 0.82),
                  ),
                ),
              ],
              if (skills.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Skills',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final skill in skills)
                      Chip(
                        label: Text(skill),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                  ],
                ),
              ],
              if (sourceUrl != null && sourceUrl!.isNotEmpty) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(sourceUrl!),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Open Official Employer Portal'),
                  ),
                ),
              ],
              if (ctaLabel != null && onCta != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onCta,
                    icon: Icon(
                      ctaLabel!.contains('Apply')
                          ? Icons.send_outlined
                          : Icons.chat_bubble_outline,
                    ),
                    label: Text(ctaLabel!),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailMetaChip extends StatelessWidget {
  const _DetailMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _teal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _teal),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: _teal,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
