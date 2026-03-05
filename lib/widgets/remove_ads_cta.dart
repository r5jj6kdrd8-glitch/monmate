import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mongo_mate/utilities/subscription_service.dart';
import 'package:mongo_mate/widgets/app_background.dart';

class RemoveAdsCta extends StatelessWidget {
  final VoidCallback onPressed;
  const RemoveAdsCta({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SubscriptionService.instance,
      builder: (context, _) {
        if (SubscriptionService.instance.isPro) {
          return const SizedBox.shrink();
        }
        final scheme = Theme.of(context).colorScheme;
        return GlassPanel(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Icon(CupertinoIcons.sparkles, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Remove Ads and Support MonMate',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: onPressed,
                child: const Text('Upgrade'),
              ),
            ],
          ),
        );
      },
    );
  }
}
