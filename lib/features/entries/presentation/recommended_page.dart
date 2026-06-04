import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import 'content_flow_page.dart';
import 'entry_providers.dart';

class RecommendedPage extends ConsumerWidget {
  const RecommendedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(recommendedEntriesProvider);
    final t = context.t;

    return Scaffold(
      appBar: AppBar(title: Text(t.recommended)),
      body: entries.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(child: Text(t.recommendationsEmpty));
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  t.recommendationsReason,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Expanded(child: EntryList(entries: items)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text(t.recommendationsFailed(error))),
      ),
    );
  }
}
