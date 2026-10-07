import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/repositories/notification_repository.dart';
import '../../../state/notifications/notifications_cubit.dart';
import '../../../widgets/glass/glass_icon_button.dart';

/// Bell icon with the unread count. Opens '/notifications' and refreshes the
/// badge when the user comes back.
class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => UnreadCountCubit(ctx.read<NotificationRepository>())..refresh(),
      child: BlocBuilder<UnreadCountCubit, int>(
        builder: (context, count) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              GlassIconButton(
                icon: count > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                tooltip: 'Thông báo',
                onPressed: () async {
                  final cubit = context.read<UnreadCountCubit>();
                  await context.push('/notifications');
                  await cubit.refresh();
                },
              ),
              Positioned(
                right: -2,
                top: -2,
                child: AnimatedScale(
                  scale: count > 0 ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutBack,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    constraints: const BoxConstraints(minWidth: 18),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
