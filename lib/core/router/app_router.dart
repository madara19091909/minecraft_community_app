import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/access_denied_screen.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/communities/presentation/communities_screen.dart';
import '../../features/communities/presentation/community_detail_screen.dart';
import '../../features/communities/presentation/community_form_screen.dart';
import '../../features/communities/presentation/community_members_screen.dart';
import '../../features/create/presentation/create_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/home/presentation/post_detail_screen.dart';
import '../../features/messages/presentation/chat_screen.dart';
import '../../features/messages/presentation/messages_screen.dart';
import '../../features/messages/presentation/new_chat_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/reports/presentation/report_detail_screen.dart';
import '../../features/reports/presentation/reports_queue_screen.dart';
import '../../features/settings/presentation/about_screen.dart';
import '../../features/settings/presentation/account_settings_screen.dart';
import '../../features/settings/presentation/appearance_screen.dart';
import '../../features/settings/presentation/blocked_users_screen.dart';
import '../../features/settings/presentation/notification_settings_screen.dart';
import '../../features/settings/presentation/privacy_settings_screen.dart';
import '../../features/settings/presentation/security_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/user_profile_screen.dart';
import '../../features/shell/presentation/main_shell.dart';
import '../widgets/loading_view.dart';

abstract class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const denied = '/access-denied';
  static const home = '/home';
  static const communities = '/communities';
  static const create = '/create';
  static const messages = '/messages';
  static const profile = '/profile';
  static const editProfile = '/profile/edit';
  static String user(String username) => '/u/$username';
  static String post(String id) => '/post/$id';
  static const notifications = '/notifications';
  static const settings = '/settings';
  static const settingsAccount = '/settings/account';
  static const settingsPrivacy = '/settings/privacy';
  static const settingsBlocked = '/settings/blocked';
  static const settingsNotifications = '/settings/notifications';
  static const settingsAppearance = '/settings/appearance';
  static const settingsSecurity = '/settings/security';
  static const settingsAbout = '/settings/about';
  static const reports = '/reports';
  static String report(String id) => '/reports/$id';
  static const newChat = '/messages/new';
  static String chat(String id) => '/chat/$id';
  static const newCommunity = '/communities/new';
  static String community(String id) => '/c/$id';
  static String editCommunity(String id) => '/c/$id/edit';
  static String communityMembers(String id) => '/c/$id/members';
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.read(authControllerProvider);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: auth,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final String target;
      switch (auth.phase) {
        case AuthPhase.loading:
          target = Routes.splash;
        case AuthPhase.signedOut:
          target = Routes.login;
        case AuthPhase.error:
          target = Routes.denied;
        case AuthPhase.ready:
          if (!auth.canAccessApp) {
            target = Routes.denied;
          } else if ([Routes.splash, Routes.login, Routes.denied].contains(loc)) {
            target = Routes.home;
          } else {
            target = loc;
          }
      }
      return target == loc ? null : target;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (_, __) => const Scaffold(body: LoadingView()),
      ),
      GoRoute(path: Routes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(path: Routes.denied, builder: (_, __) => const AccessDeniedScreen()),
      GoRoute(path: Routes.editProfile, builder: (_, __) => const EditProfileScreen()),
      GoRoute(
        path: '/u/:username',
        builder: (_, state) =>
            UserProfileScreen(username: state.pathParameters['username']!),
      ),
      GoRoute(
        path: '/post/:id',
        builder: (_, state) => PostDetailScreen(postId: state.pathParameters['id']!),
      ),
      GoRoute(path: Routes.settings, builder: (_, __) => const SettingsScreen()),
      GoRoute(path: Routes.settingsAccount, builder: (_, __) => const AccountSettingsScreen()),
      GoRoute(path: Routes.settingsPrivacy, builder: (_, __) => const PrivacySettingsScreen()),
      GoRoute(path: Routes.settingsBlocked, builder: (_, __) => const BlockedUsersScreen()),
      GoRoute(
          path: Routes.settingsNotifications,
          builder: (_, __) => const NotificationSettingsScreen()),
      GoRoute(path: Routes.settingsAppearance, builder: (_, __) => const AppearanceScreen()),
      GoRoute(path: Routes.settingsSecurity, builder: (_, __) => const SecurityScreen()),
      GoRoute(path: Routes.settingsAbout, builder: (_, __) => const AboutScreen()),
      GoRoute(path: Routes.reports, builder: (_, __) => const ReportsQueueScreen()),
      GoRoute(
        path: '/reports/:id',
        builder: (_, s) => ReportDetailScreen(reportId: s.pathParameters['id']!),
      ),
      GoRoute(path: Routes.notifications, builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: Routes.newChat, builder: (_, __) => const NewChatScreen()),
      GoRoute(
        path: '/chat/:id',
        builder: (_, s) => ChatScreen(conversationId: s.pathParameters['id']!),
      ),
      GoRoute(path: Routes.newCommunity, builder: (_, __) => const CommunityFormScreen()),
      GoRoute(
        path: '/c/:id',
        builder: (_, s) => CommunityDetailScreen(communityId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/c/:id/edit',
        builder: (_, s) => CommunityFormScreen(communityId: s.pathParameters['id']),
      ),
      GoRoute(
        path: '/c/:id/members',
        builder: (_, s) => CommunityMembersScreen(communityId: s.pathParameters['id']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.home, builder: (_, __) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.communities, builder: (_, __) => const CommunitiesScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.create, builder: (_, __) => const CreateScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.messages, builder: (_, __) => const MessagesScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.profile, builder: (_, __) => const ProfileScreen()),
          ]),
        ],
      ),
    ],
  );
});
