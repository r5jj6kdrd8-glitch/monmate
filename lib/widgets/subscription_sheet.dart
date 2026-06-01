import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mongo_mate/helpers/toast.dart';
import 'package:mongo_mate/utilities/subscription_service.dart';
import 'package:mongo_mate/widgets/app_background.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionSheet {
  static Future<void> show(BuildContext context) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SubscriptionPage(),
      ),
    );
  }
}

class SubscriptionPage extends StatelessWidget {
  const SubscriptionPage({super.key});

  Future<void> _openUrl(Uri url) async {
    if (!await launchUrl(url)) {
      ToastHelper.show('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Subscription'),
      ),
      body: AppBackground(
        child: SafeArea(
          child: AnimatedBuilder(
            animation: SubscriptionService.instance,
            builder: (context, _) {
              final service = SubscriptionService.instance;
              final monthly = service.monthlyProduct;
              final annual = service.annualProduct;
              final monthlyLabel = monthly?.price ?? '\$0.99 / month';
              final annualLabel = annual?.price ?? '\$9.99 / year';

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                children: [
                  GlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(CupertinoIcons.sparkles),
                            const SizedBox(width: 8),
                            Text(
                              'MonMate Pro',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const Spacer(),
                            if (service.isPro)
                              Chip(
                                label: const Text('Active'),
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Remove ads and support MonMate.',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          service.isPro
                              ? (Platform.isAndroid
                                  ? 'Your subscription is active for this Google Account.'
                                  : 'Your subscription is active for this Apple ID.')
                              : (Platform.isAndroid
                                  ? 'Choose monthly or annual and manage your plan in Google Play subscriptions.'
                                  : 'Choose monthly or annual and manage your plan in App Store subscriptions.'),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (service.lastError != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            service.lastError!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                        ],
                        if (!service.storeAvailable) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Subscriptions are currently unavailable for this build.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: service.isPro || service.isBusy
                              ? null
                              : () async {
                                  final started = await service.buyMonthly();
                                  if (!started && context.mounted) {
                                    ToastHelper.show(service.lastError ??
                                        'Unable to start purchase');
                                  }
                                },
                          icon: const Icon(CupertinoIcons.calendar),
                          label: Text('Monthly $monthlyLabel'),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.tonalIcon(
                          onPressed: service.isPro || service.isBusy
                              ? null
                              : () async {
                                  final started = await service.buyAnnual();
                                  if (!started && context.mounted) {
                                    ToastHelper.show(service.lastError ??
                                        'Unable to start purchase');
                                  }
                                },
                          icon: const Icon(CupertinoIcons.star_circle),
                          label: Text('Annual $annualLabel'),
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: service.isBusy
                                ? null
                                : () async {
                                    await service.restorePurchases();
                                    if (context.mounted) {
                                      ToastHelper.show(Platform.isAndroid
                                          ? 'Restore request sent to Google Play'
                                          : 'Restore request sent to App Store');
                                    }
                                  },
                            child: const Text('Restore Purchases'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  GlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Subscription Terms',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          Platform.isAndroid
                              ? 'Subscriptions renew automatically unless canceled at least 24 hours before the end of the current period. You can manage or cancel anytime in Google Play subscriptions.'
                              : 'Subscriptions renew automatically unless canceled at least 24 hours before the end of the current period. You can manage or cancel anytime in App Store subscriptions.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _openUrl(
                                Uri.parse(
                                    'https://pahlavan.co.uk/monmate/privacy'),
                              ),
                              icon: const Icon(CupertinoIcons.shield_fill),
                              label: const Text('Privacy Policy'),
                            ),
                            if (Platform.isIOS)
                              OutlinedButton.icon(
                                onPressed: () => _openUrl(
                                  Uri.parse(
                                      'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/'),
                                ),
                                icon: const Icon(CupertinoIcons.doc_text),
                                label: const Text('Apple EULA'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
