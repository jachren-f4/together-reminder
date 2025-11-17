# ResultsContentBuilder Pattern

**Related:** QUEST_UNIFICATION_PLAN_V2.md Phase 0.5

---

## Problem

`UnifiedResultsScreen` uses a content builder to render quest-specific results:

```dart
typedef ResultsContentBuilder<T extends BaseSession> = Widget Function(T session);
```

This works for **Classic** and **Affirmation** (single shared session), but **You or Me** uses **dual sessions** (one per user).

---

## Solution: Fetch Partner Session in Widget

**Pattern:** Content widget receives user session, fetches partner session in `initState()`.

### Implementation

**Unified Results Screen:**
```dart
class UnifiedResultsScreen extends StatefulWidget {
  final BaseSession session;
  final ResultsConfig config;
  final Widget Function(BaseSession) contentBuilder;  // ← Simple signature

  @override
  Widget build(BuildContext context) {
    return contentBuilder(session);  // Pass user session
  }
}
```

**You or Me Results Content:**
```dart
class YouOrMeResultsContent extends StatefulWidget {
  final YouOrMeSession userSession;  // ← Receives user's session

  @override
  State<YouOrMeResultsContent> createState() => _YouOrMeResultsContentState();
}

class _YouOrMeResultsContentState extends State<YouOrMeResultsContent> {
  YouOrMeSession? _partnerSession;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPartnerSession();
  }

  Future<void> _loadPartnerSession() async {
    final partner = StorageService().getPartner();
    if (partner == null) return;

    // Extract timestamp from user session ID (format: youorme_{userId}_{timestamp})
    final timestamp = widget.userSession.id.split('_').last;

    // Construct partner session ID using same timestamp
    final partnerSessionId = 'youorme_${partner.pushToken}_$timestamp';

    // Fetch partner session from Firebase/Hive
    final service = YouOrMeService();
    final partnerSession = await service.getSession(partnerSessionId, forceRefresh: true);

    setState(() {
      _partnerSession = partnerSession;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(child: CircularProgressIndicator());
    }

    // Now have both sessions for rendering
    return Column(
      children: [
        Text('Agreement: ${_calculateAgreement()}%'),
        // ... answer badges, comparison, etc.
      ],
    );
  }

  double _calculateAgreement() {
    if (_partnerSession == null) return 0;

    // Compare answers from both sessions
    // widget.userSession.answers vs _partnerSession.answers
    // ...
  }
}
```

---

## Benefits

1. **Simple builder signature** - No special cases for dual sessions
2. **Type-safe** - Content widget knows its session type
3. **Encapsulation** - Dual-session logic stays in content widget
4. **Flexible** - Can fetch additional data as needed (partner stats, etc.)

---

## Alternative Considered (Rejected)

**Option B:** Change builder signature to pass context + metadata:

```dart
typedef ResultsContentBuilder<T extends BaseSession> = Widget Function(
  BuildContext context,
  T session,
  Map<String, dynamic>? metadata,  // ← Could pass partner session here
);
```

**Rejected because:**
- More complex signature
- Unified screen needs to know about dual sessions
- Breaks single responsibility (results screen shouldn't know about fetching)

---

## Usage in Quest Type Config

```dart
register('youorme', QuestTypeConfig<YouOrMeSession>(
  formatType: 'youorme',
  // ...
  resultsContentBuilder: (session) => YouOrMeResultsContent(
    userSession: session,  // ← Simple: just pass session
  ),
  // ...
));
```

---

## Testing Considerations

**Unit Test YouOrMeResultsContent:**
- Mock YouOrMeService.getSession()
- Verify partner session fetch logic
- Test loading states
- Test agreement calculation

**Integration Test:**
- Alice and Bob both complete You or Me
- Navigate to results
- Verify both sessions loaded
- Verify correct agreement percentage displayed

---

**End of Document**
