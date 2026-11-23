import 'package:flutter/material.dart';

import '../models/platform.dart';
import '../models/sale_campaign.dart';

class SaleBanner extends StatelessWidget {
  const SaleBanner({super.key, required this.campaign, required this.onTap});

  final SaleCampaign campaign;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final image = campaign.imageUrl;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (image != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    image,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    cacheWidth: 156,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => SizedBox(
                      width: 52,
                      child: Icon(
                        campaign.platform.icon,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      campaign.platform.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      campaign.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_outward_rounded,
                size: 17,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
