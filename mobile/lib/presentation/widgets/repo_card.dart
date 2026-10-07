import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/repo_model.dart';
import 'glass/glass_badge.dart';
import 'glass/glass_card.dart';

class RepoCard extends StatelessWidget {
  final RepoModel repo;
  final VoidCallback? onTap;

  const RepoCard({
    super.key,
    required this.repo,
    this.onTap,
  });

  Color _getLanguageColor(String? lang) {
    if (lang == null) return Colors.grey;
    switch (lang.toLowerCase()) {
      case 'dart':
        return AppColors.langDart;
      case 'python':
        return AppColors.langPython;
      case 'typescript':
        return AppColors.langTypeScript;
      case 'javascript':
        return AppColors.langJavaScript;
      case 'rust':
        return AppColors.langRust;
      case 'go':
        return AppColors.langGo;
      case 'kotlin':
        return AppColors.langKotlin;
      case 'swift':
        return AppColors.langSwift;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      padding: const EdgeInsets.all(16),
      borderRadius: 22,
      enableGlow: repo.isHot,
      glowColor: repo.isHot ? const Color(0xFFFF3366) : null,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Owner/Repo name, Hot Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withAlpha(isDark ? 40 : 120),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(30),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.network(
                    repo.effectiveOwnerAvatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildAvatarFallback(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      repo.owner,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      repo.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (repo.isHot) ...[
                const SizedBox(width: 8),
                GlassBadge.hot(),
              ],
            ],
          ),

          // Description
          if (repo.description != null && repo.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              repo.description!,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                height: 1.42,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 14),

          // Footer: Language tag, Stars, Forks, Stars gained badge
          Row(
            children: [
              if (repo.language != null) ...[
                Container(
                  width: 8.5,
                  height: 8.5,
                  decoration: BoxDecoration(
                    color: _getLanguageColor(repo.language),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _getLanguageColor(repo.language).withAlpha(140),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  repo.language!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(width: 14),
              ],
              const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFB800)),
              const SizedBox(width: 3.5),
              Text(
                _formatNumber(repo.stars),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(width: 14),
              Icon(
                Icons.fork_right_rounded,
                size: 15,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
              const SizedBox(width: 3),
              Text(
                _formatNumber(repo.forks),
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const Spacer(),
              if (repo.starsGained7d > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.success.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.success.withAlpha(90), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.trending_up_rounded, size: 12, color: AppColors.success),
                      const SizedBox(width: 3),
                      Text(
                        '+${repo.starsGained7d}/7d',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback() {
    return Container(
      color: const Color(0xFF1E293B),
      child: Center(
        child: Text(
          repo.name.isNotEmpty ? repo.name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return number.toString();
  }
}
