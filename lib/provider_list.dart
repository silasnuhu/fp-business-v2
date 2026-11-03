import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/services/socket/socket_event_controller.dart';
import 'package:whoxa/dependency_injection.dart';
import 'package:whoxa/featuers/auth/provider/business_profile_provider.dart';
import 'package:whoxa/featuers/chat/provider/label_provider.dart';
import 'package:whoxa/featuers/profile/provider/catalog_provider.dart';
import 'package:whoxa/featuers/ai_assistant/provider/ai_assistant_provider.dart';
import 'package:whoxa/featuers/ai_assistant/repository/ai_assistant_repository.dart';
import 'package:whoxa/featuers/auth/provider/auth_provider.dart';
import 'package:whoxa/featuers/chat/group/provider/group_provider.dart';
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:whoxa/featuers/chat/provider/archive_chat_provider.dart';
import 'package:whoxa/featuers/home/provider/chatbot_provider.dart';
import 'package:whoxa/featuers/home/provider/home_provider.dart';
import 'package:whoxa/featuers/language_method/provider/language_provider.dart';
import 'package:whoxa/featuers/onboarding/Provider/onboarding_provider.dart';
import 'package:whoxa/featuers/call/call_provider.dart';
import 'package:whoxa/featuers/profile/provider/profile_provider.dart';
import 'package:whoxa/featuers/project-config/provider/config_provider.dart';
import 'package:whoxa/featuers/provider/theme_provider.dart';
import 'package:whoxa/featuers/provider/voice_provider.dart';
import 'package:whoxa/featuers/story/provider/story_provider.dart';
import 'package:whoxa/featuers/subscription/data/subscription_repository.dart';
import 'package:whoxa/featuers/subscription/provider/subscription_provider.dart';
import 'package:whoxa/featuers/contacts/provider/contact_provider.dart';
import 'package:whoxa/featuers/provider/tabbar_provider.dart';
import 'package:whoxa/featuers/report/provider/report_provider.dart';
import 'package:whoxa/featuers/call/call_history/providers/call_history_provider.dart';

List<SingleChildWidget> appProviders = [
  // Subscription: premium_user from the backend + store purchase stream
  // (lazy: store billing only starts when the subscription screen opens)
  ChangeNotifierProvider<SubscriptionProvider>(
    create:
        (_) => SubscriptionProvider(
          repository: ApiSubscriptionRepository(getIt<ApiClient>()),
        ),
  ),
  // Core providers
  // Project Configuration Provider (should be first)
  ChangeNotifierProvider<ProjectConfigProvider>(
    create: (_) => getIt<ProjectConfigProvider>(),
  ),
  ChangeNotifierProvider<AuthProvider>(create: (_) => getIt<AuthProvider>()),
  ChangeNotifierProvider<TabbarProvider>(
    create: (_) => getIt<TabbarProvider>(),
  ),
  ChangeNotifierProvider<ProfileProvider>(
    create: (_) => getIt<ProfileProvider>(),
  ),
  ChangeNotifierProvider<ContactListProvider>(
    create: (_) => getIt<ContactListProvider>(),
  ),

  // ✅ FIXED: ArchiveChatProvider is now registered and linked in dependency_injection.dart
  ChangeNotifierProvider<ArchiveChatProvider>(
    create: (_) => getIt<ArchiveChatProvider>(),
  ),

  // Socket-related providers - FIXED ORDER AND INITIALIZATION
  // Use .value constructor to share the same instance across the app
  ChangeNotifierProvider<SocketEventController>.value(
    value: getIt<SocketEventController>(),
  ),

  // ChatProvider gets the shared SocketEventController instance
  ChangeNotifierProvider<ChatProvider>(
    create: (context) {
      // Get the SocketEventController from the context (already provided above)
      final socketEventController = context.read<SocketEventController>();
      final chatProvider = ChatProvider(
        getIt(),
        socketEventController,
        getIt(),
      );

      // Only initialize if socket is connected
      // The SocketManager will handle connection initialization
      return chatProvider;
    },
  ),
  ChangeNotifierProvider(create: (_) => ChatbotProvider(getIt<ApiClient>())),
  ChangeNotifierProvider<AiAssistantProvider>(
    create:
        (context) => AiAssistantProvider(
          AiAssistantRepository(getIt<ApiClient>()),
          context.read<SocketEventController>(),
        ),
  ),

  // Feature providers
  ChangeNotifierProvider<HomeProvider>(create: (_) => getIt<HomeProvider>()),
  ChangeNotifierProvider<LanguageProvider>(
    create: (_) => getIt<LanguageProvider>(),
  ),
  ChangeNotifierProvider<OnboardingProvider>(
    create: (_) => getIt<OnboardingProvider>(),
  ),
  ChangeNotifierProvider<StoryProvider>(create: (_) => getIt<StoryProvider>()),
  ChangeNotifierProvider<GroupProvider>(create: (_) => getIt<GroupProvider>()),
  ChangeNotifierProvider<ReportProvider>(
    create: (_) => getIt<ReportProvider>(),
  ),
  ChangeNotifierProvider<ThemeProvider>(create: (_) => getIt<ThemeProvider>()),

  // Call-related providers
  ChangeNotifierProvider<CallHistoryProvider>(
    create: (_) => getIt<CallHistoryProvider>(),
  ),

  // ✅ Opus Call Provider (using dependency injection)
  ChangeNotifierProvider<CallProvider>(create: (_) => getIt<CallProvider>()),
  ChangeNotifierProvider<VoiceProvider>(create: (_) => getIt<VoiceProvider>()),

  // Business app providers
  ChangeNotifierProvider<BusinessProfileProvider>(
    create: (_) => BusinessProfileProvider(),
  ),
  ChangeNotifierProvider<CatalogProvider>(create: (_) => CatalogProvider()),
  ChangeNotifierProvider<LabelProvider>(create: (_) => LabelProvider()),
];
