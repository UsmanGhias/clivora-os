import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart' show Value;
import '../../constants/admin_config.dart';

import '../../auth/auth_service.dart';
import '../../auth/user_roles.dart';
import '../../cloud/supabase_auth_helper.dart';
import '../../../data/database/database.dart';
import '../../../data/database/user_scoped_queries.dart';
import '../../../data/models/invoice_line_item.dart';
import '../../../data/providers/app_providers.dart';
import '../sync_outbox_service.dart';
import 'connect_credits.dart';

String cleanJobText(dynamic raw) {
  if (raw == null) return '';
  var s = raw.toString();
  s = s.replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'<li>', caseSensitive: false), '\n• ');
  s = s.replaceAll(RegExp(r'</li>', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'</(p|div|h1|h2|h3|h4|h5|h6|tr|table|ul|ol)>', caseSensitive: false), '\n\n');
  s = s.replaceAll(RegExp(r'<[^>]+>'), ' ');
  s = s.replaceAll('&amp;', '&');
  s = s.replaceAll('&lt;', '<');
  s = s.replaceAll('&gt;', '>');
  s = s.replaceAll('&quot;', '"');
  s = s.replaceAll('&#x27;', "'");
  s = s.replaceAll('&#39;', "'");
  s = s.replaceAll('&apos;', "'");
  s = s.replaceAll('&#x2F;', '/');
  s = s.replaceAll('&#47;', '/');
  s = s.replaceAll('&nbsp;', ' ');
  s = s.replaceAll('&bull;', '•');
  s = s.replaceAll('&middot;', '·');
  s = s.replaceAll(RegExp(r'[\u2014\u2013]'), '-');
  s = s.replaceAll(RegExp(r'[ \t]+'), ' ');
  s = s.replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n');
  return s.trim();
}

final connectMarketplaceServiceProvider = Provider<ConnectMarketplaceService>((ref) {
  return ConnectMarketplaceService(ref);
});

class ConnectMarketplaceService {
  ConnectMarketplaceService(this.ref);
  final Ref ref;

  SupabaseClient? get client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  String? get currentUserId => client?.auth.currentUser?.id ?? client?.auth.currentSession?.user.id;

  /// Ensures Supabase is ready and the JWT session is valid (refresh if needed).
  Future<({SupabaseClient client, String uid})> _requireAuthedClient() async {
    final c = client;
    if (c == null) {
      throw StateError('Cloud not ready. Close and reopen the app, then try again.');
    }
    final ok = await SupabaseAuthHelper.ensureCloudSession();
    var uid = c.auth.currentUser?.id ?? c.auth.currentSession?.user.id;
    if (!ok || uid == null) {
      final local = ref.read(authStateProvider).valueOrNull;
      if (local != null) {
        throw StateError(
          'Your cloud session expired. Sign out and sign in again to use Connect.',
        );
      }
      throw StateError('Sign in required');
    }
    return (client: c, uid: uid);
  }

  bool get hasConnectAccess => true;

  /// Legacy alias, prefer [hasConnectAccess].
  bool get hasProPlus => true;

  Future<List<Map<String, dynamic>>> browseFreelancers({
    String? skill,
    String sort = 'featured',
  }) async {
    return _browseProfiles(accountType: 'freelancer', skill: skill, sort: sort);
  }

  /// Client Pro Plus about/listings so freelancers can discover & connect.
  Future<List<Map<String, dynamic>>> browseClients({
    String? skill,
    String sort = 'featured',
  }) async {
    return _browseProfiles(accountType: 'client', skill: skill, sort: sort);
  }

  Future<ConnectCreditSummary?> creditSummary() async {
    try {
      final auth = await _requireAuthedClient();
      final c = auth.client;
      final rows = await c.rpc('connect_credit_summary');
      final list = (rows as List?) ?? const [];
      if (list.isEmpty) return null;
      return ConnectCreditSummary.fromRow(Map<String, dynamic>.from(list.first as Map));
    } catch (e) {
      // Fall back to account row when eligibility blocks summary RPC.
      try {
        final auth = await _requireAuthedClient();
        final row = await auth.client
            .from('connect_credit_accounts')
            .select()
            .eq('user_id', auth.uid)
            .maybeSingle();
        if (row == null) return null;
        return ConnectCreditSummary.fromRow(Map<String, dynamic>.from(row));
      } catch (_) {
        if (e is StateError) return null;
        throw mapConnectRpcError(e);
      }
    }
  }

  Future<void> acceptProposal({
    required String proposalId,
    required String clientUserId,
    required String freelancerUserId,
    String? requestId,
    double amount = 0,
  }) async {
    final auth = await _requireAuthedClient();
    final c = auth.client;
    try {
      await c.rpc('connect_accept_proposal', params: {'p_proposal_id': proposalId});
    } catch (e) {
      throw mapConnectRpcError(e);
    }
    if (requestId == null || requestId.isEmpty) {
      return;
    }
    // Kickoff milestone remains a free follow-up after accepting an engagement request.
    await c.from('connect_milestones').insert({
      'engagement_request_id': requestId,
      'client_user_id': clientUserId,
      'freelancer_user_id': freelancerUserId,
      'title': 'Kickoff milestone',
      'amount': amount,
      'currency': 'USD',
      'status': 'pending',
    });
  }

  Future<List<Map<String, dynamic>>> _browseProfiles({
    required String accountType,
    String? skill,
    String sort = 'featured',
  }) async {
    final c = client;
    if (c == null) return [];
    try {
      await SupabaseAuthHelper.refreshSessionIfNeeded();
    } catch (_) {}
    final base = c
        .from('connect_profiles')
        .select(
          'id,user_id,display_title,headline,bio,skills,rate_band,availability,location_label,is_verified,account_type,created_at,avg_rating,review_count,completion_rate,reputation_score,profile_completeness',
        )
        .eq('account_type', accountType)
        .eq('is_listed', true)
        .eq('moderation_status', 'approved');
    final ordered = sort == 'newest'
        ? base.order('created_at', ascending: false)
        : sort == 'rating'
            ? base.order('avg_rating', ascending: false)
            : base.order('reputation_score', ascending: false);
    final rows = await ordered.limit(50);
    final list = (rows as List).cast<Map<String, dynamic>>();
    final enriched = await _attachAvatarUrls(list);
    if (skill == null || skill.trim().isEmpty) return enriched;
    final needle = skill.trim().toLowerCase();
    return enriched.where((r) {
      final skills = (r['skills'] as List?)?.map((e) => e.toString().toLowerCase()) ?? [];
      final title = (r['display_title'] as String? ?? '').toLowerCase();
      final headline = (r['headline'] as String? ?? '').toLowerCase();
      return skills.any((s) => s.contains(needle)) ||
          title.contains(needle) ||
          headline.contains(needle);
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _attachAvatarUrls(List<Map<String, dynamic>> rows) async {
    final c = client;
    if (c == null || rows.isEmpty) return rows;
    final ids = rows
        .map((r) => r['user_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return rows;
    try {
      final avatars = await c.from('profiles').select('id, avatar_url').inFilter('id', ids);
      final map = <String, String?>{};
      for (final row in (avatars as List)) {
        final m = Map<String, dynamic>.from(row as Map);
        map[m['id'].toString()] = m['avatar_url'] as String?;
      }
      return rows
          .map((r) => {
                ...r,
                'avatar_url': map[r['user_id']?.toString()] ?? r['avatar_url'],
              })
          .toList();
    } catch (_) {
      return rows;
    }
  }

  Future<List<Map<String, dynamic>>> browseNeeds() async {
    final c = client;
    if (c == null) return [];
    try {
      await SupabaseAuthHelper.refreshSessionIfNeeded();
    } catch (_) {}

    final List<Map<String, dynamic>> combined = [];

    // 1. Fetch live published jobs from connect_jobs (530+ live listings, $0 platform fees)
    try {
      final jobRows = await c
          .from('connect_jobs')
          .select(
            'id,title,company_name,company_domain,company_email,source_url,description,category,tags,salary_min,salary_max,currency,location,job_type,seo_slug,posted_by,created_at',
          )
          .eq('is_public', true)
          .eq('status', 'published')
          .order('created_at', ascending: false)
          .limit(1000);

      for (final j in (jobRows as List)) {
        final row = Map<String, dynamic>.from(j as Map);
        final minSal = row['salary_min'];
        final maxSal = row['salary_max'];
        String budgetBand = 'Competitive (\$ USD)';
        if (minSal != null && maxSal != null) {
          budgetBand = '\$$minSal - \$$maxSal USD';
        } else if (minSal != null) {
          budgetBand = '\$$minSal USD';
        }

        final rawTags = row['tags'];
        List<dynamic> skills = [];
        if (rawTags is List && rawTags.isNotEmpty) {
          skills = rawTags.map((t) => cleanJobText(t)).toList();
        } else if (row['category'] != null) {
          skills = [cleanJobText(row['category'])];
        }

        final sourceUrl = row['source_url']?.toString().trim();
        final isExternal = sourceUrl != null && sourceUrl.isNotEmpty;

        combined.add({
          'id': row['id'],
          'client_user_id': row['posted_by'] ?? '00000000-0000-0000-0000-000000000000',
          'title': cleanJobText(row['title'] ?? 'Remote Role'),
          'summary': cleanJobText(row['description'] ?? ''),
          'skills': skills,
          'budget_band': budgetBand,
          'created_at': row['created_at'],
          'moderation_status': 'approved',
          'is_open': true,
          'company_name': cleanJobText(row['company_name']),
          'company_email': row['company_email'],
          'company_domain': row['company_domain'],
          'source_url': sourceUrl,
          'is_external': isExternal,
          'location': cleanJobText(row['location'] ?? 'Remote'),
          'seo_slug': row['seo_slug'],
          'category': row['category'],
          'is_crawled_job': isExternal,
        });
      }
    } catch (e) {
      debugPrint('[browseNeeds] connect_jobs fetch error: $e');
    }

    // 2. Fetch community needs from connect_need_posts (if accessible)
    try {
      final needRows = await c
          .from('connect_need_posts')
          .select('id,client_user_id,title,summary,skills,budget_band,created_at,moderation_status,is_open')
          .eq('is_open', true)
          .eq('moderation_status', 'approved')
          .order('created_at', ascending: false)
          .limit(50);

      for (final n in (needRows as List)) {
        final row = Map<String, dynamic>.from(n as Map);
        row['is_crawled_job'] = false;
        combined.add(row);
      }
    } catch (_) {
      // Ignored if user does not have Pro Plus to read connect_need_posts
    }

    return combined;
  }

  /// Submits a proposal to a live remote job with $0 platform fee
  Future<String?> submitJobProposal({
    required String jobId,
    required String message,
    String? companyName,
    String? companyEmail,
    double amount = 0,
    int timelineDays = 7,
  }) async {
    final auth = await _requireAuthedClient();
    final c = auth.client;
    final uid = auth.uid;

    final inserted = await c.from('connect_proposals').insert({
      'from_user_id': uid,
      'job_id': jobId,
      'amount': amount,
      'currency': 'USD',
      'timeline_days': timelineDays,
      'message': message.trim(),
      'status': 'pending',
      'client_name': companyName,
      'client_email': companyEmail,
    }).select('id, review_token').single();

    final proposalId = inserted['id'] as String?;
    final reviewToken = inserted['review_token'] as String? ?? proposalId;

    if (companyEmail != null && companyEmail.trim().isNotEmpty) {
      try {
        await c.functions.invoke('send-clivora-email', body: {
          'to': companyEmail.trim(),
          'subject': 'New proposal on CLIVORA (\$0 Platform Fee)',
          'purpose': 'proposal_received',
          'companyName': companyName ?? 'Hiring Team',
          'freelancerName': 'CLIVORA Candidate',
          'jobTitle': 'Remote Role',
          'amount': amount,
          'timelineDays': timelineDays,
          'pitchMessage': message.trim(),
          'reviewUrl': '$kClivoraWebBaseUrl/connect/review?token=$reviewToken',
        });
      } catch (err) {
        debugPrint('[submitJobProposal] email notification note: $err');
      }
    }

    return proposalId;
  }

  Future<Map<String, dynamic>?> myListing() async {
    try {
      final auth = await _requireAuthedClient();
      return await auth.client
          .from('connect_profiles')
          .select()
          .eq('user_id', auth.uid)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  Future<void> upsertListing({
    required String displayTitle,
    required String headline,
    required String bio,
    required List<String> skills,
    required String rateBand,
    required String availability,
    required String locationLabel,
    required bool isListed,
  }) async {
    final auth = await _requireAuthedClient();
    final c = auth.client;
    final uid = auth.uid;
    if (!hasConnectAccess) {
      throw StateError('CLIVORA Connect requires Pro Plus');
    }

    final user = ref.read(authStateProvider).valueOrNull;
    final accountType = isClientUser(user) ? 'client' : 'freelancer';
    final existing = await myListing();
    final wasListed = existing?['is_listed'] == true;
    final wantFirstPublish =
        isListed && !wasListed && accountType == 'freelancer';

    // Upsert content first. For first freelancer publish, keep unlisted until
    // connect_publish_profile succeeds (avoids PROFILE_INCOMPLETE / spend-before-row).
    await c.from('connect_profiles').upsert({
      'user_id': uid,
      'account_type': accountType,
      'display_title': displayTitle.trim(),
      'headline': headline.trim(),
      'bio': bio.trim(),
      'skills': skills,
      'rate_band': rateBand,
      'availability': availability,
      'location_label': locationLabel.trim(),
      'is_listed': wantFirstPublish ? false : isListed,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id');

    if (wantFirstPublish) {
      try {
        await c.rpc('connect_publish_profile', params: {
          'p_headline': headline.trim().isEmpty ? displayTitle.trim() : headline.trim(),
          'p_bio': bio.trim(),
          'p_skills': skills,
          'p_rate': double.tryParse(rateBand.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0,
        });
      } catch (e) {
        throw mapConnectRpcError(e);
      }
    }
  }

  Future<void> createNeedPost({
    required String title,
    required String summary,
    required List<String> skills,
    required String budgetBand,
  }) async {
    final auth = await _requireAuthedClient();
    if (!hasConnectAccess) {
      throw StateError('CLIVORA Connect requires Pro Plus');
    }
    try {
      await auth.client.rpc('connect_publish_need', params: {
        'p_title': title.trim(),
        'p_summary': summary.trim(),
        'p_skills': skills,
        'p_budget_band': budgetBand,
      });
    } catch (e) {
      throw mapConnectRpcError(e);
    }
  }

  Future<void> sendContactRequest({
    required String toUserId,
    String? targetProfileId,
    String? targetNeedId,
    required String message,
  }) async {
    final auth = await _requireAuthedClient();
    final uid = auth.uid;
    if (!hasConnectAccess) {
      throw StateError('CLIVORA Connect requires Pro Plus');
    }
    if (toUserId == uid) throw StateError('Cannot contact yourself');
    try {
      await auth.client.rpc('connect_send_request', params: {
        'p_to_user_id': toUserId,
        'p_target_profile_id': targetProfileId,
        'p_target_need_id': targetNeedId,
        'p_message': message.trim(),
      });
    } catch (e) {
      throw mapConnectRpcError(e);
    }
  }

  Future<List<Map<String, dynamic>>> myRequests() async {
    try {
      final auth = await _requireAuthedClient();
      final uid = auth.uid;
      final rows = await auth.client
          .from('connect_request_details')
          .select()
          .or('from_user_id.eq.$uid,to_user_id.eq.$uid')
          .order('created_at', ascending: false)
          .limit(100);
      return (rows as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> respondToRequest(String requestId, {required bool accept}) async {
    final auth = await _requireAuthedClient();

    try {
      await auth.client.rpc('connect_respond_request', params: {
        'p_request_id': requestId,
        'p_accept': accept,
      });
    } catch (e) {
      throw mapConnectRpcError(e);
    }

    if (accept) {
      await logConnectEvent('connect_request_accepted', payload: {'request_id': requestId});
    }
  }

  Future<void> leaveReview({
    required String toUserId,
    required int rating,
    String body = '',
    String? requestId,
  }) async {
    final auth = await _requireAuthedClient();
    if (rating < 1 || rating > 5) throw StateError('Rating must be 1-5');
    if (requestId == null || requestId.isEmpty) {
      throw StateError('A released milestone engagement is required to leave a review');
    }
    try {
      await auth.client.rpc('connect_submit_review', params: {
        'p_to_user_id': toUserId,
        'p_request_id': requestId,
        'p_rating': rating,
        'p_body': body.trim(),
      });
    } catch (e) {
      throw mapConnectRpcError(e);
    }
  }

  Future<void> submitProposal({
    required String toUserId,
    required double amount,
    required String message,
    String? needId,
    String? requestId,
    int? timelineDays,
    String currency = 'USD',
  }) async {
    final auth = await _requireAuthedClient();
    if (!hasConnectAccess) throw StateError('CLIVORA Connect requires Pro Plus');
    try {
      await auth.client.rpc('connect_submit_proposal', params: {
        'p_to_user_id': toUserId,
        'p_need_id': needId,
        'p_amount': amount,
        'p_currency': currency,
        'p_timeline_days': timelineDays,
        'p_message': message.trim(),
      });
    } catch (e) {
      throw mapConnectRpcError(e);
    }
  }

  Future<List<Map<String, dynamic>>> milestonesForRequest(String requestId) async {
    final c = client;
    if (c == null) return [];
    final rows = await c
        .from('connect_milestones')
        .select()
        .eq('engagement_request_id', requestId)
        .order('created_at');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> addMilestone({
    required String requestId,
    required String clientUserId,
    required String freelancerUserId,
    required String title,
    required double amount,
    String currency = 'USD',
  }) async {
    final auth = await _requireAuthedClient();
    await auth.client.from('connect_milestones').insert({
      'engagement_request_id': requestId,
      'client_user_id': clientUserId,
      'freelancer_user_id': freelancerUserId,
      'title': title.trim(),
      'amount': amount,
      'currency': currency,
      'status': 'pending',
    });
  }

  Future<void> updateMilestoneStatus(String milestoneId, String status) async {
    final auth = await _requireAuthedClient();
    try {
      await auth.client.rpc('connect_transition_milestone', params: {
        'p_milestone_id': milestoneId,
        'p_status': status,
      });
    } catch (e) {
      throw mapConnectRpcError(e);
    }
  }

  Future<Map<String, dynamic>> homeSummary({required bool client}) async {
    try {
      final auth = await _requireAuthedClient();
      final data = await auth.client.rpc(client ? 'client_home_summary' : 'freelancer_home_summary');
      if (data is Map) return Map<String, dynamic>.from(data);
      return {};
    } catch (e) {
      if (e is StateError) return {};
      throw mapConnectRpcError(e);
    }
  }

  Future<String> createMeetingRoom({String title = 'CLIVORA Meeting', String? projectId}) async {
    final auth = await _requireAuthedClient();
    final uid = auth.uid;
    final slug = 'clivora-${DateTime.now().millisecondsSinceEpoch}';
    final url = 'https://meet.jit.si/$slug';
    await auth.client.from('meeting_links').insert({
      'owner_uid': uid,
      'project_id': projectId,
      'title': title,
      'room_url': url,
      'scheduled_at': DateTime.now().toIso8601String(),
    });
    return url;
  }

  /// After mutual accept: create a local CRM customer from revealed partner identity.
  Future<int?> linkAcceptedPartnerToWorkspace(Map<String, dynamic> request) async {
    final myUid = currentUserId;
    if (myUid == null) return null;
    final incoming = request['to_user_id'] == myUid;
    final name = (incoming ? request['from_name'] : request['to_name']) as String? ?? 'Connect partner';
    final email = (incoming ? request['from_email'] : request['to_email']) as String? ?? '';
    if (email.trim().isEmpty) return null;

    final ownerId = ref.read(authStateProvider).valueOrNull?.id;
    if (ownerId == null) return null;

    final db = ref.read(databaseProvider);
    final existing = await db.watchCustomersForUser(ownerId).first;
    final needle = email.trim().toLowerCase();
    final match = existing.where((c) {
      return parseStringList(c.emails).any((e) => e.trim().toLowerCase() == needle);
    }).toList();
    if (match.isNotEmpty) return match.first.id;

    final id = await db.insertCustomer(
      CustomersCompanion.insert(
        ownerUserId: ownerId,
        contactPerson: name.trim().isEmpty ? email.split('@').first : name.trim(),
        emails: Value(encodeStringList([email.trim()])),
        notes: const Value('Added from CLIVORA Connect after mutual accept.'),
      ),
    );
    try {
      await ref.read(syncOutboxServiceProvider).enqueue(
            SyncOutboxItem(kind: 'crm_customer', payload: {'localId': id}),
          );
    } catch (e) {
      debugPrint('Connect partner CRM enqueue failed: $e');
    }
    await logConnectEvent('connect_workspace_linked', payload: {
      'customer_email': email,
      'customer_id': id,
    });
    ref.invalidate(customersProvider);
    ref.invalidate(dashboardStatsProvider);
    return id;
  }

  Future<void> logConnectEvent(String type, {Map<String, dynamic>? payload}) async {
    try {
      final c = client;
      final email = c?.auth.currentUser?.email ?? '';
      if (c == null) return;
      await c.from('clivora_events').insert({
        'event_type': type,
        'user_email': email,
        'user_name': '',
        'plan': 'pro_plus',
        'amount': 0,
        'payload': payload ?? {},
        'source': 'connect',
      });
    } catch (e) {
      debugPrint('Connect event log: $e');
    }
  }
}
