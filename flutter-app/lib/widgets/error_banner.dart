import 'package:flutter/material.dart';
import '../api/api_client.dart';

/// Renders an error in a friendly, non-blocking way. Calls out the Render
/// cold-start case specifically — that's the most common "error" the user
/// will see in the first ~minute of using the app.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final coldStart = isLikelyColdStart(error);
    final message = coldStart
        ? 'Backend is warming up (Render free tier sleeps after inactivity). First request takes ~30–60 s.'
        : error.toString();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            coldStart ? Icons.hourglass_empty : Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            coldStart ? 'Warming up…' : 'Something went wrong',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    );
  }
}
