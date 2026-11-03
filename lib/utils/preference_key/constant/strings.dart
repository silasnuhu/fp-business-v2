/// NOTE:
/// The following string method is used throughout the app.
/// If any strings are added or updated, they must also be updated
/// in the language API. Otherwise, the changes will not be reflected
/// in translations.
library;

import 'package:whoxa/featuers/language_method/provider/language_provider.dart';

class AppString {
  // static final LanguageProvider _langProvider =
  //     getIt<LanguageProvider>(); // or Provider.of(context), or a singleton

  static late LanguageProvider _langProvider;

  static void initStrings(LanguageProvider langProvider) {
    _langProvider = langProvider;
    loginTypeString = LoginTypeString(_langProvider);
    loginEmailPhoneString = LoginEmailPhoneString(_langProvider);
    otpScreenString = OTPScreenString(_langProvider);
    addInfoScreenString = AddInfoScreenString(_langProvider);
    bottomNavString = BottomNavString(_langProvider);
    homeScreenString = HomeScreenString(_langProvider);
    geoupProfileString = GeoupProfileString(_langProvider);
    settingStrigs = SettingStrigs(_langProvider);
    chatBubbleStrings = ChatBubbleStrings(_langProvider);
    storyStrings = StoryStrings(_langProvider);
    onboardingStrings = OnboardingStrings(_langProvider);
    avatarScreenString = AvatarScreenString(_langProvider);
    blockUserStrings = BlockUserStrings(_langProvider);
    deleteChatString = DeleteChatString(_langProvider);
    emptyDataString = EmptyDataString(_langProvider);
    reportString = ReportString(_langProvider);
    locationStrings = LocationStrings(_langProvider);
    chatLockStrings = ChatLockStrings(_langProvider);
    subscriptionStrings = SubscriptionStrings(_langProvider);
    profileStrings = ProfileStrings(_langProvider);
  }

  /// Generic translation helper for one-off strings that don't warrant a
  /// dedicated named getter (snackbars, dialogs, empty states, etc. spread
  /// across the app). Routes through the same static translation source as
  /// every other AppString getter, so it stays in sync with app language.
  static String tr(String text) => _langProvider.textTranslate(text);

  static String get openSettings => _langProvider.textTranslate('Open settings');

  /// Same as [tr], but for templates containing `{placeholder}` tokens that
  /// need substituting with dynamic values after translation, e.g.
  /// `AppString.trParams("{name} left the group", {"name": userName})`.
  static String trParams(String template, Map<String, String> params) {
    var result = tr(template);
    params.forEach((key, value) {
      result = result.replaceAll('{$key}', value);
    });
    return result;
  }

  static late LoginTypeString loginTypeString;
  static late LoginEmailPhoneString loginEmailPhoneString;
  static late OTPScreenString otpScreenString;
  static late AddInfoScreenString addInfoScreenString;
  static late BottomNavString bottomNavString;
  static late HomeScreenString homeScreenString;
  static late GeoupProfileString geoupProfileString;
  static late SettingStrigs settingStrigs;
  static late ChatBubbleStrings chatBubbleStrings;
  static late StoryStrings storyStrings;
  static late OnboardingStrings onboardingStrings;
  static late AvatarScreenString avatarScreenString;
  static late BlockUserStrings blockUserStrings;
  static late DeleteChatString deleteChatString;
  static late EmptyDataString emptyDataString;
  static late ReportString reportString;
  static late LocationStrings locationStrings;
  static late ChatLockStrings chatLockStrings;
  static late SubscriptionStrings subscriptionStrings;
  static late ProfileStrings profileStrings;

  //============= below common strings for using all screens
  static String get welcome => _langProvider.textTranslate("Welcome");
  static String get hello => _langProvider.textTranslate(
    "Start a new conversation and stay connected.",
  );
  static const String phone = "Phone";
  static const String email = "Email";
  static String get error => _langProvider.textTranslate("Error");
  static String get success => _langProvider.textTranslate("Success");
  static String get failedToAddEmail =>
      _langProvider.textTranslate("Failed to add email");
  static String get failedToAddPhonenmuber =>
      _langProvider.textTranslate("Failed to add Phone nmuber");
  static String get failedToAddOTP =>
      _langProvider.textTranslate("Failed to add OTP, Resend OTP");
  static String get pleaseEnterMobilenumber =>
      _langProvider.textTranslate("Please Enter Mobile number");
  static String get pleaseEnterEmailID =>
      _langProvider.textTranslate("Please Enter Email ID");
  static String get login => _langProvider.textTranslate("Login");
  static String get phoneNumber => _langProvider.textTranslate("Phone Number");
  static String get country => _langProvider.textTranslate("Country");
  static String get oTPResendonmobilenumber =>
      _langProvider.textTranslate("OTP Resend on mobile number");
  static String get oTPResendonemail =>
      _langProvider.textTranslate("OTP Resend on email");
  static String get pleaseaddyourusername =>
      _langProvider.textTranslate("Please add your username");
  static String get pleaseaddyourfirstname =>
      _langProvider.textTranslate("Please add your firstname");
  static String get pleaseaddyourlastname =>
      _langProvider.textTranslate("Please add your lastname");
  static String get pleaseaddyourgendertype =>
      _langProvider.textTranslate("Please add your gender type");
  static String get pleaseaddyourcountry =>
      _langProvider.textTranslate("Please add your country");
  static String get delete => _langProvider.textTranslate("Delete");
  static String get block => _langProvider.textTranslate("Block");
  static String get cancel => _langProvider.textTranslate("Cancel");
  static String online = "Online";
  static String get typeMessage => _langProvider.textTranslate("Type Message");
  static String get continues => _langProvider.textTranslate("Continue");
  static String get seeAll => _langProvider.textTranslate("See all");
  static String get createGroup => _langProvider.textTranslate("Create Group");
  static String get howItWorks => _langProvider.textTranslate("How It Works:");
  static String get one => _langProvider.textTranslate("1.");
  static String get two => _langProvider.textTranslate("2.");
  static String get three => _langProvider.textTranslate("3.");
  static String get four => _langProvider.textTranslate("4.");
  static String get somethingWhileSendingOtp =>
      _langProvider.textTranslate("Something went wrong while sending OTP");
  static String get next => _langProvider.textTranslate("Next");
  static String get typing => _langProvider.textTranslate("typing");
  static String get startChat => _langProvider.textTranslate("Start Chat");
  static String get document => _langProvider.textTranslate("Document");
  static String get photo => _langProvider.textTranslate("Photo");
  static String get video => _langProvider.textTranslate("Video");
  static String get location => _langProvider.textTranslate("Location");
  static String get gif => _langProvider.textTranslate("GIF");
  static String get poll => _langProvider.textTranslate("Poll");
  static String get connectionError => _langProvider.textTranslate(
    "Connection error. Please check your internet connection",
  );
  static String get connectionError2 => _langProvider.textTranslate(
    "No internet connection. Please check your internet settings.",
  );
  static String get or => _langProvider.textTranslate("Or");
  static String get camera => _langProvider.textTranslate("Camera");
  static String get gellery => _langProvider.textTranslate("Gallery");
  static String get submit => _langProvider.textTranslate("Submit");
  static String get save => _langProvider.textTranslate("Save");
  static String get noStatusSelected =>
      _langProvider.textTranslate("No status selected");
  static String get invite => _langProvider.textTranslate("Invite");
  static String get appVersion => _langProvider.textTranslate("App version");
  static String get notification => _langProvider.textTranslate("Notification");
  static String get allCalls => _langProvider.textTranslate("All Calls");
  static String get contactList => _langProvider.textTranslate("Contact List");
  static String get darkMode => _langProvider.textTranslate("Dark mode");
  static String get lightMode => _langProvider.textTranslate("Light mode");
  static String get groupInformation =>
      _langProvider.textTranslate("Group Information");
  static String get groupName => _langProvider.textTranslate("Group Name");
  static String get enterYourGroupName =>
      _langProvider.textTranslate("Enter your Group Name");
  static String get description => _langProvider.textTranslate("Description");
  static String get viewContact => _langProvider.textTranslate("View Contact");
  static String get viewLocation =>
      _langProvider.textTranslate("View Location");
  static String get storyUnavailable =>
      _langProvider.textTranslate("Story unavailable");
  static String get media => _langProvider.textTranslate("Media");
  static String get documents => _langProvider.textTranslate("Documents");
  static String get links => _langProvider.textTranslate("Links");
  static String get gropuInfo => _langProvider.textTranslate("Group Info");
  static String get groupStatistics =>
      _langProvider.textTranslate("Group Statistics");
  static String get groupMembers =>
      _langProvider.textTranslate("Group Members");
  static String get admin => _langProvider.textTranslate("Admin");
  static String get loadingMembers =>
      _langProvider.textTranslate("Loading members");
  static String get noMembersFound =>
      _langProvider.textTranslate("No members found");
  static String get failedtoloadMembers =>
      _langProvider.textTranslate("Failed to load members");
  static String get retry => _langProvider.textTranslate("Retry");
  static String get addMembers => _langProvider.textTranslate("Add Members");
  static String get reportGroup => _langProvider.textTranslate("Report Group");
  static String get exitGroup => _langProvider.textTranslate("Exit Group");
  static String get exit => _langProvider.textTranslate("Exit");
  static String get areyousureyouwanttoleave =>
      _langProvider.textTranslate("Are you sure you want to leave");
  static String get youwillnolongerreceivemessagesfromthisgroup => _langProvider
      .textTranslate("You will no longer receive messages from this group.");
  static String get editGroup => _langProvider.textTranslate("Edit Group");
  static String get enterGroupName =>
      _langProvider.textTranslate("Enter group name");
  static String get groupDescription =>
      _langProvider.textTranslate("Group Description");
  static String get enterGroupDescription =>
      _langProvider.textTranslate("Enter group description (optional)");
  static String get updating => _langProvider.textTranslate("Updating");
  static String get forwardFailed =>
      _langProvider.textTranslate("Forward Failed");
  static String get failedToForwardAnyMessages =>
      _langProvider.textTranslate("Failed to forward any messages");
  static String get noMessagesSelectedForForwarding =>
      _langProvider.textTranslate("No messages selected for forwarding");
  static String get pleaseSelectAtLeastOneChatOrContact =>
      _langProvider.textTranslate("Please select at least one chat or contact");
  static String get messagesForwardedSuccessfully =>
      _langProvider.textTranslate("Messages forwarded successfully");
  static String get forward => _langProvider.textTranslate("Forward");
  static String get message => _langProvider.textTranslate("Message");
  static String get makeGroupAdmin =>
      _langProvider.textTranslate("Make Group Admin");
  static String get removeAdmin => _langProvider.textTranslate("Remove Admin");
  static String get remove => _langProvider.textTranslate("Remove");
  static String get deletingGroup =>
      _langProvider.textTranslate("Deleting Group");
  static String get deleteGroup => _langProvider.textTranslate("Delete Group");
  static String get photoCapturedSuccessfully =>
      _langProvider.textTranslate("Photo captured successfully");
  static String get errorAccessingCamera =>
      _langProvider.textTranslate("Error accessing camera");
  static String get imageSelectedSuccessfully =>
      _langProvider.textTranslate("Image selected successfully");
  static String get errorAccessingGallery =>
      _langProvider.textTranslate("Error accessing gallery");
  static String get groupUpdatedSuccessfully =>
      _langProvider.textTranslate("Group updated successfully");
  static String get failedToUpdateGroup =>
      _langProvider.textTranslate("Failed to update group");
  static String get pleaseSelectAnAvatar =>
      _langProvider.textTranslate("Please select an avatar.");
  static String get failedToArchiveChat =>
      _langProvider.textTranslate("Failed to archive chat");
  static String get chat => _langProvider.textTranslate("Chat");
  static String get archivedSuccessfully =>
      _langProvider.textTranslate("archived successfully");
  static String get archiving => _langProvider.textTranslate("Archiving");
  static String get archive => _langProvider.textTranslate("Archive");
  static String get areYouSureYouWantToArchive =>
      _langProvider.textTranslate("Are you sure you want to archive");
  static String get archiveChat => _langProvider.textTranslate("Archive Chat");
  static String get failedToDeleteChat =>
      _langProvider.textTranslate("Failed to delete chat");
  static String get pleaseTryAgain =>
      _langProvider.textTranslate("Please try again.");
  static String get deletedSuccessfully =>
      _langProvider.textTranslate("deleted successfully");
  // *
  static String get deleting => _langProvider.textTranslate("Deleting");
  static String get unableToDeleteChatInvalidChatID =>
      _langProvider.textTranslate("Unable to delete chat: Invalid chat ID");
  static String get unableToArchiveChatInvalidChatID =>
      _langProvider.textTranslate("Unable to archive chat: Invalid chat ID");
  static String get wouldYouLikeToInvite =>
      _langProvider.textTranslate("Would you like to invite");
  static String get tojoin => _langProvider.textTranslate("to join");
  static String get inviteContact =>
      _langProvider.textTranslate("Invite Contact");
  static String get noContactsAvailable =>
      _langProvider.textTranslate("No contacts available");
  static String get inviteLinkCopiedToClipboard =>
      _langProvider.textTranslate("Invite link copied to clipboard!");
  static String get invites => _langProvider.textTranslate("Invites");
  static String get contacts => _langProvider.textTranslate("Contacts");
  static String get sendMessage => _langProvider.textTranslate("Send Message");
  static String get viewProfile => _langProvider.textTranslate("View Profile");
  static String get ok => _langProvider.textTranslate("Ok");
  static String get noPhoneNumberAvailable =>
      _langProvider.textTranslate("No phone number available");
  static String get copiedToClipboard =>
      _langProvider.textTranslate("Copied to clipboard");
  static String get refresh => _langProvider.textTranslate("Refresh");
  static String get tappedOnMessage =>
      _langProvider.textTranslate("Tapped on message");
  static String get anErrorOccurredWhileClearingChat =>
      _langProvider.textTranslate("An error occurred while clearing chat.");
  static String get errorClearingChat =>
      _langProvider.textTranslate("Error clearing chat");
  static String get failedToClearChatPleaseTryAgain =>
      _langProvider.textTranslate("Failed to clear chat, Please try again.");
  static String get chatClearedSuccessfully =>
      _langProvider.textTranslate("Chat cleared successfully");
  static String get clearChatForMeOnly => _langProvider.textTranslate(
    "Messages will be removed from this chat for you only. Other participants will still see them.",
  );
  static String get editMessage => _langProvider.textTranslate("Edit message");
  static String get edited => _langProvider.textTranslate("Edited");
  static String get failedToEditMessage =>
      _langProvider.textTranslate("Failed to edit message");
  static String get anRrrorOccurredPleaseTryAgain =>
      _langProvider.textTranslate("An error occurred. Please try again.");
  static String get unableTolocateMessage =>
      _langProvider.textTranslate("Unable to locate message");
  static String get messageFound =>
      _langProvider.textTranslate("Message found!");
  static String get failedToDeleteMessages =>
      _langProvider.textTranslate("Failed to delete messages");
  static String get these => _langProvider.textTranslate("These");
  static String get willBeDeletedForEveryoneInTheChat =>
      _langProvider.textTranslate("will be deleted for everyone in the chat.");
  static String get deleteForEveryone =>
      _langProvider.textTranslate("Delete for Everyone?");
  static String get failedToForwardMessages =>
      _langProvider.textTranslate("Failed to forward messages");
  static String get forwardMessages =>
      _langProvider.textTranslate("Forward Messages?");
  static String get to => _langProvider.textTranslate("to");
  static String get failedToUnstarMessage =>
      _langProvider.textTranslate("Failed to unstar message");
  static String get messageUnstarredSuccessfully =>
      _langProvider.textTranslate("Message unstarred successfully");
  static String get messageStarredSuccessfully =>
      _langProvider.textTranslate("Message starred successfully");
  static String get couldNotLaunch =>
      _langProvider.textTranslate("Could not launch");
  static String get loadingmedia =>
      _langProvider.textTranslate("Loading media");
  static String get failedToUnarchiveChat =>
      _langProvider.textTranslate("Failed to unarchive chat");
  static String get unarchivedSuccessfully =>
      _langProvider.textTranslate("unarchived successfully");
  static String get unarchiving => _langProvider.textTranslate("Unarchiving");
  static String get failedToDeleteGroup =>
      _langProvider.textTranslate("Failed to delete group");
  static String get groupDeletedSuccessfully =>
      _langProvider.textTranslate("Group deleted successfully");
  static String get failedToLeaveGroup =>
      _langProvider.textTranslate("Failed to leave group");
  static String get youHaveLeftTheGroup =>
      _langProvider.textTranslate("You have left the group");
  static String get leavingGroup =>
      _langProvider.textTranslate("Leaving group");
  static String get mediaGalleryComingSoon =>
      _langProvider.textTranslate("Media gallery coming soon");
  static String get notificationSettingChangedto =>
      _langProvider.textTranslate("Notification setting changed to");
  static String get errorUpdatingGroup =>
      _langProvider.textTranslate("Error updating group");
  static String get errorGroupIDNotFound =>
      _langProvider.textTranslate("Error: Group ID not found");
  static String get avatarProfileNotFound =>
      _langProvider.textTranslate("Avatar Profile Not Found");
  // *
  static String get searchContacts =>
      _langProvider.textTranslate("Search contacts");
  // *
  static String get noContactsAvailableforChat =>
      _langProvider.textTranslate("No contacts available for chat");
  //*
  static String get noContactstoInvite =>
      _langProvider.textTranslate("No contacts to invite");
  static String get connectingToChatService =>
      _langProvider.textTranslate("Connecting to chat service");
  static String get connectionTochatServerlostReconnecting => _langProvider
      .textTranslate("Connection to chat server lost. Reconnecting");
  static String get loadingMoreChats =>
      _langProvider.textTranslate("Loading more chats");
  // *
  static String get loadingChats =>
      _langProvider.textTranslate("Loading chats");
  // *
  static String get searchNameOrNumber =>
      _langProvider.textTranslate("Search name or number");
  // *
  static String get add => _langProvider.textTranslate("Add");
  // *
  static String get whathisGroupAbout =>
      _langProvider.textTranslate("What's this group about? (Optional)");
  // *
  static String get members => _langProvider.textTranslate("Members");
  // *
  static String get outof => _langProvider.textTranslate("out of");
  // *
  static String get pleaseEnterAGroupName =>
      _langProvider.textTranslate("Please enter a group name");
  static String get pleaseSelectAtleastOneContact =>
      _langProvider.textTranslate("Please select at least one contact");
  // *
  static String get creatingGroup =>
      _langProvider.textTranslate("Creating Group");
  static String get enterGroupNameToContinue =>
      _langProvider.textTranslate("Enter Group name to continue");
  static String get forwardMessages1 =>
      _langProvider.textTranslate("Forward Messages");
  static String get searchChatsAndContacts =>
      _langProvider.textTranslate("Search chats and contacts");
  static String get recentChats => _langProvider.textTranslate("Recent Chats");
  static String get allContacts => _langProvider.textTranslate("All Contacts");
  static String get clearAll => _langProvider.textTranslate("Clear All");
  static String get forwardTo => _langProvider.textTranslate("Forward to");
  static String get recipient => _langProvider.textTranslate("recipient");
  static String get loadingContacts =>
      _langProvider.textTranslate("Loading contacts");
  static String get noChatsAvailable =>
      _langProvider.textTranslate("No chats available");
  static String get selectGroupImage =>
      _langProvider.textTranslate("Select Group Image");
  static String get pleaseSelectAtLeastOneContactToAdd =>
      _langProvider.textTranslate("Please select at least one contact to add");
  static String get addingMembers =>
      _langProvider.textTranslate("Adding Members");
  static String get memberAddedSuccessfully =>
      _langProvider.textTranslate("member(s) added successfully");
  static String get alreadyInGroup =>
      _langProvider.textTranslate("Already in group");
  static String get noContactsAvailableAsPerYourSearch =>
      _langProvider.textTranslate("No contacts available as per your search");
  static String get selectNewContactsToAdd => _langProvider.textTranslate(
    'Select new contacts to add. Existing members are shown with Already in group',
  );
  static String get selectContactsToAdd =>
      _langProvider.textTranslate("Select Contacts to Add");
  static String get and => _langProvider.textTranslate("and");
  static String get moreError => _langProvider.textTranslate("more error");
  static String get errorDetails =>
      _langProvider.textTranslate("Error details");
  static String get done => _langProvider.textTranslate("Done");
  static String get someForwardsFailed =>
      _langProvider.textTranslate("Some forwards failed");
  static String get successfullyForwarded =>
      _langProvider.textTranslate("Successfully forwarded");
  static String get partialSuccess =>
      _langProvider.textTranslate("Partial Success");
  static String get allMessagesHaveBeenDeliveredSuccessfully => _langProvider
      .textTranslate("All messages have been delivered successfully.");
  static String get messageto => _langProvider.textTranslate("message to");
  static String get success1 => _langProvider.textTranslate("Success!");
  static String get anUnexpectedErrorOccurred =>
      _langProvider.textTranslate("An unexpected error occurred");
  static String get forwarding => _langProvider.textTranslate("Forwarding");
  static String get yourReportSubmitted =>
      _langProvider.textTranslate("Your report submitted");
  static String get reportNotAvailable =>
      _langProvider.textTranslate("Reports Not Available");
  static String get reportUser => _langProvider.textTranslate("Report User");
  static String get noNearbyLocationFound =>
      _langProvider.textTranslate("No nearby location found");
  static String get searchLocationNotFound =>
      _langProvider.textTranslate("Search location not found");
  static String get searchingForMessage =>
      _langProvider.textTranslate("Searching for message");
  static String get unstarring => _langProvider.textTranslate("Unstarring");
  static String get starring => _langProvider.textTranslate("Starring");
  static String get messageUnpinnedSuccessfully =>
      _langProvider.textTranslate("Message unpinned successfully");
  static String get unpinningMessage =>
      _langProvider.textTranslate("Unpinning message");
  static String get messagePinnedForLifetime =>
      _langProvider.textTranslate("Message pinned for lifetime");
  // *
  static String get messagePinnedFor =>
      _langProvider.textTranslate("Message pinned for");
  static String get days => _langProvider.textTranslate("days");
  static String get day => _langProvider.textTranslate("day");
  // *
  static String get unpinning => _langProvider.textTranslate("Unpinning");
  // *
  static String get pinning => _langProvider.textTranslate("Pinning");
  static String get errorSelectingGIFPleaseTryAgain =>
      _langProvider.textTranslate("Error selecting GIF. Please try again.");
  static String get couldGIFURLPleaseTryAgain =>
      _langProvider.textTranslate("Could not get GIF URL. Please try again.");
  static String get failedToSendGIFPleaseTryAgain =>
      _langProvider.textTranslate("Failed to send GIF. Please try again.");
  static String get pleaseWaitWhileWeClearAllMessages =>
      _langProvider.textTranslate("Please wait while we clear all messages");
  static String get clearingChat =>
      _langProvider.textTranslate("Clearing chat");
  static String get deletingMessages =>
      _langProvider.textTranslate("Deleting Messages");
  static String get deleted => _langProvider.textTranslate("Deleted");
  static String get of => _langProvider.textTranslate("of");
  static String get successfullyDeleted =>
      _langProvider.textTranslate("Successfully deleted");
  static String get forEveryone => _langProvider.textTranslate("for everyone");
  static String get foryou => _langProvider.textTranslate('for you');
  static String get failedToDeleteMessagesPleaseTryAgain => _langProvider
      .textTranslate("Failed to delete messages. Please try again.");
  static String get someDeletionsFailed =>
      _langProvider.textTranslate("Some deletions failed.");
  static String get deleteOnlyMineForEveryone =>
      _langProvider.textTranslate("Delete Only Mine for Everyone");
  static String get gotIt => _langProvider.textTranslate("Got It");
  static String get selectOnlyYourOwnMessagesToDeleteThemforEveryone =>
      _langProvider.textTranslate(
        "Select only your own messages to delete them for everyone",
      );
  static String get usetoRemoveAllSelectedMessagesFromYourView =>
      _langProvider.textTranslate(
        'Use "Delete for Me" to remove all selected messages from your view',
      );
  static String get options => _langProvider.textTranslate("Options");
  static String get fromOthers => _langProvider.textTranslate("from others");
  static String get ofYourOwnMessages =>
      _langProvider.textTranslate("of your own messages");
  static String get ofYourOwnMessage =>
      _langProvider.textTranslate("of your own message");
  static String get yourSelectionContains =>
      _langProvider.textTranslate("Your selection contains");
  static String get youCanOnlyDeleteYourOwnMessagesForEveryone => _langProvider
      .textTranslate("You can only delete your own messages for everyone.");
  static String get cannotDeleteForEveryone =>
      _langProvider.textTranslate("Cannot Delete for Everyone");
  static String get deleteForEveryone1 =>
      _langProvider.textTranslate("Delete for Everyone");
  static String
  get thisActionCannotbBeUndoneTheMessages => _langProvider.textTranslate(
    "This action cannot be undone. The messages will be removed for all participants.",
  );
  static String get deleteMineforEveryone =>
      _langProvider.textTranslate("Delete Mine for Everyone");
  static String get deleteForMe => _langProvider.textTranslate("Delete for Me");
  static String get automaticallyFiltersToYour =>
      _langProvider.textTranslate("Automatically filters to your");
  static String get deleteOnlyYourMessagesForEveryone =>
      _langProvider.textTranslate("Delete only your messages for everyone");
  static String get removesAllSelectedMessagesFromYourViewOnly => _langProvider
      .textTranslate("Removes all selected messages from your view only");
  static String get useDeleteforMe =>
      _langProvider.textTranslate('Use "Delete for Me"');
  static String get yourOptions => _langProvider.textTranslate("Your options");
  static String get cannotDelete =>
      _langProvider.textTranslate("Cannot delete");
  static String get canDelete => _langProvider.textTranslate("Can delete");
  static String get yourCurrentSelection =>
      _langProvider.textTranslate("Your current selection");
  static String get messagesOfOthers =>
      _langProvider.textTranslate("messages of others");
  static String get youHaveSelected =>
      _langProvider.textTranslate("You have selected");
  static String get forwarded => _langProvider.textTranslate("Forwarded");
  static String get forwardingMessages =>
      _langProvider.textTranslate("Forwarding Messages");
  static String get messagesWillBeForwarded => _langProvider.textTranslate(
    'Messages will be forwarded with "Forwarded" label',
  );
  static String get thisTypeofMessageCannotBeDeleted =>
      _langProvider.textTranslate("This type of message cannot be deleted.");
  static String get cannotSelectMessage =>
      _langProvider.textTranslate('Cannot Select Message');
  static String get removedasadminmessagescannotbeDeleted => _langProvider
      .textTranslate("Removed as admin messages cannot be deleted.");
  static String get systemMessage =>
      _langProvider.textTranslate("System Message");
  static String get promotedasadminmessagescannotbedeleted => _langProvider
      .textTranslate("Promoted as admin messages cannot be deleted.");
  static String get memberleftmessagescannotbedeleted =>
      _langProvider.textTranslate("Member left messages cannot be deleted.");
  static String get memberremovalmessagescannotbedeleted =>
      _langProvider.textTranslate("Member removal messages cannot be deleted.");
  static String get memberadditionmessagescannotbedeleted => _langProvider
      .textTranslate("Member addition messages cannot be deleted.");
  static String get groupcreationmessagescannotbedeleted =>
      _langProvider.textTranslate("Group creation messages cannot be deleted.");
  static String get thismessagehasalreadybeendeletedandcannotbeselected =>
      _langProvider.textTranslate(
        "This message has already been deleted and cannot be selected.",
      );
  static String get messageAlreadyDeleted =>
      _langProvider.textTranslate("Message Already Deleted");
  static String get nomessagesyet =>
      _langProvider.textTranslate("No messages yet");
  static String get typeatleastcharacterstosearch =>
      _langProvider.textTranslate("Type at least 2 characters to search");
  static String get searchmessages =>
      _langProvider.textTranslate("Search messages");
  static String get tryadifferentsearchterm =>
      _langProvider.textTranslate("Try a different search term");
  static String get nomessagesfound =>
      _langProvider.textTranslate("No messages found");
  static String get searchingmessages =>
      _langProvider.textTranslate("Searching messages");
  static String get messagecopied =>
      _langProvider.textTranslate("Message copied");
  static String get noMediainThisCategory =>
      _langProvider.textTranslate("No media in this category");
  // *
  static String get inviteFriendsTo =>
      _langProvider.textTranslate("Invite friends to");
  // *
  static String get shareThisLinkWithYourFriendsToInviteThemTojoin =>
      _langProvider.textTranslate(
        "Join me on Flickpitch! Download the app and start chatting",
      );
  // *
  static String get shareLink => _langProvider.textTranslate("Share Link");
  // 8
  static String get copyLink => _langProvider.textTranslate("Copy Link");
  // Demo account message
  static String get demoAccountRestrictions => _langProvider.textTranslate(
    "This is a demo account. You cannot delete or archive chats, block users, or delete your account. These features are only available in real accounts. Please register to try them with a real account.",
  );
  static String get demoAccountTitle =>
      _langProvider.textTranslate("Demo Account");
  static String get catalog => _langProvider.textTranslate("Catalog");
  static String get noCatalogItemAvailable =>
      _langProvider.textTranslate("No catalog items available");
  static String get businessAccount =>
      _langProvider.textTranslate("Business Account");
  static String get thisAccountHas =>
      _langProvider.textTranslate("This account was joined in");
  static String get businessCategory =>
      _langProvider.textTranslate("Business Category");
  static String get businessHours =>
      _langProvider.textTranslate("Business hours");
  static String get appointmentsOnly =>
      _langProvider.textTranslate("Appointments Only");
  static String get chooseImage => _langProvider.textTranslate("Choose Image");
  static String get chooseVideo => _langProvider.textTranslate("Choose Video");
  static String get thisBusinessHasnt => _langProvider.textTranslate(
    "This business hasn't added any catalog items yet.",
  );
  static String get myStory => _langProvider.textTranslate("My Story");
  // ============= strings moved here from one-off AppString.tr(...) call sites
  static String get adminPromoted => _langProvider.textTranslate('Admin promoted');
  static String get adminRemoved => _langProvider.textTranslate('Admin removed');
  static String get adminWithSpace => _langProvider.textTranslate("Admin ");
  static String get admins => _langProvider.textTranslate('Admins');
  static String get allMessagesWillBePermanentlyDeleted => _langProvider.textTranslate('• All messages will be permanently deleted\n• All members will be removed\n• Group history will be lost');
  static String areYouSureDeleteName(String name) =>
      trParams('Are you sure you want to delete "{name}"?', {'name': name});
  static String areYouSureLeaveGroupName(String name) =>
      trParams('Are you sure you want to leave "{name}"? You will no longer receive messages from this group.', {'name': name});
  static String get audio => _langProvider.textTranslate('Audio');
  static String get audioEmoji => _langProvider.textTranslate('🎵 Audio');
  static String get blockVerb => _langProvider.textTranslate('block');
  static String get canMessages => _langProvider.textTranslate("can messages");
  static String cancelledTypeCall(String type) =>
      trParams('Cancelled {type} call', {'type': type});
  static String get contact => _langProvider.textTranslate('Contact');
  static String get contactEmoji => _langProvider.textTranslate("👤 Contact");
  static String countMembers(String count) =>
      trParams('{count} members', {'count': count});
  static String countOnline(String count) =>
      trParams('{count} online', {'count': count});
  static String dateAtTime(String date, String time) =>
      trParams("{date} at {time}", {'date': date, 'time': time});
  static String get deleteForever => _langProvider.textTranslate('Delete Forever');
  static String get deleteGroupQuestion => _langProvider.textTranslate('Delete Group?');
  static String get demoAccountLoginWithRealCredentials => _langProvider.textTranslate("Demo account - Login with real credentials to delete messages");
  static String get demoAccountsCannotDeleteTheirAccount => _langProvider.textTranslate("Demo accounts cannot delete their account");
  static String get demoAccountsCannotEditGroupInformation => _langProvider.textTranslate('Demo accounts cannot edit group information');
  static String get demoAccountsCannotManageGroupAdmins => _langProvider.textTranslate('Demo accounts cannot manage group admins');
  static String get demoAccountsCannotPurchaseASubscription => _langProvider.textTranslate('Demo accounts cannot purchase a subscription');
  static String get demoAccountsCannotRemoveGroupMembers => _langProvider.textTranslate('Demo accounts cannot remove group members');
  static String get demoAccountsCannotSendMessagesHere => _langProvider.textTranslate("Demo accounts cannot send messages here");
  static String get demoAccountsCannotUploadMedia => _langProvider.textTranslate("Demo accounts cannot upload media");
  static String get documentEmoji => _langProvider.textTranslate('📄 Document');
  static String documentErrorWithMessage(String error) =>
      trParams("Document error: {error}", {'error': error});
  static String errorApplyingThemeColor(String error) =>
      trParams("Error applying theme color: {error}", {'error': error});
  static String get errorOccurredDuringAccountDeletion => _langProvider.textTranslate('Error occurred during account deletion');
  static String errorResettingTheme(String error) =>
      trParams("Error resetting theme: {error}", {'error': error});
  static String errorWithMessage(String error) =>
      trParams("Error: {error}", {'error': error});
  static String failedToActionUser(String action) =>
      trParams('Failed to {action} user', {'action': action});
  static String get failedToLoadMoreMessages => _langProvider.textTranslate("Failed to load more messages");
  static String get failedToLoadStarredMessages => _langProvider.textTranslate('Failed to load starred messages');
  static String failedToRefreshMessages(String error) =>
      trParams("Failed to refresh messages: {error}", {'error': error});
  static String get found => _langProvider.textTranslate('FOUND');
  static String get gifFilmEmoji => _langProvider.textTranslate('🎞️ GIF');
  static String get gifMaskEmoji => _langProvider.textTranslate("🎭 GIF");
  static String get gifTitleCase => _langProvider.textTranslate("Gif");
  static String get groupChat => _langProvider.textTranslate('Group Chat');
  static String get groupWasCreated => _langProvider.textTranslate('Group was created');
  static String get holdToRecord => _langProvider.textTranslate("Hold to record");
  static String get image => _langProvider.textTranslate("Image");
  static String get incomingCall => _langProvider.textTranslate('Incoming Call');
  static String get incomingCallLower => _langProvider.textTranslate('Incoming call');
  static String incomingTypeCall(String type) =>
      trParams('Incoming {type} call', {'type': type});
  static String incomingTypeCallFromCaller(String type, String caller) =>
      trParams('Incoming {type} call from {caller}', {'type': type, 'caller': caller});
  static String get individualChat => _langProvider.textTranslate('Individual Chat');
  static String get invalidTimestamp => _langProvider.textTranslate('Invalid timestamp');
  static String get justNow => _langProvider.textTranslate('Just now');
  static String lastSeenDateAtTime(String date, String time) =>
      trParams('last seen {date} at {time}', {'date': date, 'time': time});
  static String get lastSeenRecently => _langProvider.textTranslate('Last seen recently');
  static String lastSeenTodayAtTime(String time) =>
      trParams('last seen today at {time}', {'time': time});
  static String get leaveGroup => _langProvider.textTranslate('Leave Group');
  static String get leaveGroupQuestion => _langProvider.textTranslate('Leave Group?');
  static String get link => _langProvider.textTranslate("Link");
  static String get linkEmoji => _langProvider.textTranslate("🔗 Link");
  static String get loadingArchivedChats => _langProvider.textTranslate("Loading archived chats...");
  static String get loadingDots => _langProvider.textTranslate("Loading...");
  static String get loadingMessages => _langProvider.textTranslate("Loading messages...");
  static String get loadingMoreArchivedChats => _langProvider.textTranslate("Loading more archived chats...");
  static String get loadingMoreChatsDots => _langProvider.textTranslate("Loading more chats...");
  static String get locationEmoji => _langProvider.textTranslate('📍 Location');
  static String get logoutCompletedWithWarnings => _langProvider.textTranslate('Logout completed with warnings');
  static String get mediaFiles => _langProvider.textTranslate('Media & Files');
  static String get memberAdded => _langProvider.textTranslate('Member added');
  static String get memberRemoved => _langProvider.textTranslate('Member removed');
  static String get messageEmoji => _langProvider.textTranslate("💬 Message");
  static String get microphonePermissionRequired => _langProvider.textTranslate("Microphone permission required");
  static String minSecDuration(String m, String s) =>
      trParams('{m}min {s}sec', {'m': m, 's': s});
  static String get missedCall => _langProvider.textTranslate('Missed Call');
  static String get missedCallLower => _langProvider.textTranslate('Missed call');
  static String missedTypeCall(String type) =>
      trParams('Missed {type} call', {'type': type});
  static String missedTypeCallFromCaller(String type, String caller) =>
      trParams('Missed {type} call from {caller}', {'type': type, 'caller': caller});
  static String nDaysAgoShort(String n) =>
      trParams("{n}d ago", {'n': n});
  static String nHoursAgoShort(String n) =>
      trParams("{n}h ago", {'n': n});
  static String nHrAgo(String n) =>
      trParams('{n} hr ago', {'n': n});
  static String nMinAgo(String n) =>
      trParams('{n} min ago', {'n': n});
  static String nMinutesAgoShort(String n) =>
      trParams("{n}m ago", {'n': n});
  static String nResultsFound(String n) =>
      trParams("{n} results found", {'n': n});
  static String nResultsFoundPlural(String n) =>
      trParams('{n} result(s) found', {'n': n});
  static String nSecondsAgo(String n) =>
      trParams('{n} seconds ago', {'n': n});
  static String nameAddedToGroupByActor(String name, String actor) =>
      trParams('{name} was added to this group by {actor}.', {'name': name, 'actor': actor});
  static String nameCreatedTheGroup(String name) =>
      trParams('{name} created the group', {'name': name});
  static String nameLeftTheGroup(String name) =>
      trParams('{name} left the group', {'name': name});
  static String namePromotedToAdminByActor(String name, String actor) =>
      trParams('{name} was promoted to admin by {actor}.', {'name': name, 'actor': actor});
  static String nameRemovedAsAdminByActor(String name, String actor) =>
      trParams('{name} was removed as admin by {actor}.', {'name': name, 'actor': actor});
  static String nameRemovedFromGroupByActor(String name, String actor) =>
      trParams('{name} was removed from this group by {actor}.', {'name': name, 'actor': actor});
  static String nameWasAdded(String name) =>
      trParams('{name} was added', {'name': name});
  static String nameWasPromotedToAdmin(String name) =>
      trParams('{name} was promoted to admin', {'name': name});
  static String nameWasRemoved(String name) =>
      trParams('{name} was removed', {'name': name});
  static String nameWasRemovedAsAdmin(String name) =>
      trParams('{name} was removed as admin', {'name': name});
  static String nameWithGroupSuffix(String name) =>
      trParams("{name} (Group)", {'name': name});
  static String get notificationSettings => _langProvider.textTranslate('Notification Settings');
  static String get onlineStatus => _langProvider.textTranslate('Online');
  static String get onlyWithSpace => _langProvider.textTranslate("Only ");
  static String get outgoingCall => _langProvider.textTranslate('Outgoing Call');
  static String get outgoingCallLower => _langProvider.textTranslate('Outgoing call');
  static String outgoingTypeCall(String type) =>
      trParams('Outgoing {type} call', {'type': type});
  static String get photoEmoji => _langProvider.textTranslate('📷 Photo');
  static String get pinned => _langProvider.textTranslate('Pinned');
  static String get pleaseTryAgainNoPeriod => _langProvider.textTranslate("Please try again");
  static String get pleaseUseRealAccountToTest => _langProvider.textTranslate('Please use real account to test this feature');
  static String get pollMessage => _langProvider.textTranslate('Poll message');
  static String get readLess => _langProvider.textTranslate("Read less");
  static String get readMore => _langProvider.textTranslate("Read more");
  static String get report => _langProvider.textTranslate("Report");
  static String get searchChats => _langProvider.textTranslate('Search chats...');
  static String get searchMessages => _langProvider.textTranslate('Search Messages');
  static String get searchingChats => _langProvider.textTranslate("Searching chats...");
  static String get searchingForMessageDots => _langProvider.textTranslate('Searching for message...');
  static String get send => _langProvider.textTranslate("Send");
  static String get socialPost => _langProvider.textTranslate("Social Post");
  static String get someoneLeftTheGroup => _langProvider.textTranslate('Someone left the group');
  static String get somethingWentWrong => _langProvider.textTranslate("Something went wrong");
  static String get somethingWentWrongTryAgain => _langProvider.textTranslate("Something went wrong, try again");
  static String get starred => _langProvider.textTranslate('Starred');
  static String statusCall(String status) =>
      trParams('{status} Call', {'status': status});
  static String statusTypeCall(String status, String type) =>
      trParams('{status} {type} Call', {'status': status, 'type': type});
  static String get storyReply => _langProvider.textTranslate("Story Reply");
  static String get text => _langProvider.textTranslate("Text");
  static String get textMessage => _langProvider.textTranslate('Text message');
  static String get thisActionCannotBeUndone => _langProvider.textTranslate('This action cannot be undone:');
  static String get thisMessageWasDeleted => _langProvider.textTranslate('This message was deleted.');
  static String get thisUserHasLockedTheirChat => _langProvider.textTranslate('This user has locked their chat.');
  static String todayAtTime(String time) =>
      trParams("Today at {time}", {'time': time});
  static String get trySearchingWithDifferentKeywords => _langProvider.textTranslate('Try searching with different keywords');
  static String typeCall(String type) =>
      trParams('{type} Call', {'type': type});
  static String get typingDots => _langProvider.textTranslate("Typing...");
  static String get unableToGetYourCurrentLocation => _langProvider.textTranslate("Unable to get your current location");
  static String get unableToSendLocation => _langProvider.textTranslate("Unable to send location");
  static String get unblockUser => _langProvider.textTranslate('Unblock User');
  static String get unblockVerb => _langProvider.textTranslate('unblock');
  static String get unknownUser => _langProvider.textTranslate('Unknown User');
  static String get unstarringMessages => _langProvider.textTranslate("Unstarring Messages.");
  static String unsupportedMessageType(String type) =>
      trParams('Unsupported message type: {type}', {'type': type});
  static String get videoEmoji => _langProvider.textTranslate('🎥 Video');
  static String get voice => _langProvider.textTranslate("Voice");
  static String get voiceEmoji => _langProvider.textTranslate("🎙️ Voice");
  static String get voiceMessage => _langProvider.textTranslate("Voice message");
  static String get yesterday => _langProvider.textTranslate('Yesterday');
  static String yesterdayAtTime(String time) =>
      trParams("Yesterday at {time}", {'time': time});
  static String yesterdayTime(String time) =>
      trParams("Yesterday {time}", {'time': time});
  static String youAndNameBlockedEachOther(String name) =>
      trParams('You and {name} have blocked each other. Unblock to continue chatting.', {'name': name});
  static String youBlockedNameUnblock(String name) =>
      trParams('You blocked {name}. Unblock to continue chatting.', {'name': name});
  static String get youLeftTheGroup => _langProvider.textTranslate('You left the group');
  static String get youWereAdded => _langProvider.textTranslate('You were added');
  static String get youWerePromotedToAdmin => _langProvider.textTranslate('You were promoted to admin');
  static String get youWereRemoved => _langProvider.textTranslate('You were removed');
  static String get youWereRemovedAsAdmin => _langProvider.textTranslate('You were removed as admin');

  // ============= strings moved here from one-off AppString.tr(...) call sites


}

class LocationStrings {
  final LanguageProvider _langProvider;
  LocationStrings(this._langProvider);

  String get sendLocation => _langProvider.textTranslate("Send Location");
  String get searchPlace => _langProvider.textTranslate("Search place");
  String get nearbyPlaces => _langProvider.textTranslate("Nearby Places");
  String get searchPlaces => _langProvider.textTranslate("Search places");
}

class LoginTypeString {
  final LanguageProvider _langProvider;
  LoginTypeString(this._langProvider);

  String get continuewithPhoneorEmail =>
      _langProvider.textTranslate("Continue with Phone or Email");
  String get or => _langProvider.textTranslate("Or");
}

class LoginEmailPhoneString {
  final LanguageProvider _langProvider;
  LoginEmailPhoneString(this._langProvider);

  String get mobileNumber => _langProvider.textTranslate("Mobile Number");
  String get entermail => _langProvider.textTranslate("Enter mail");
  String get weWillPhone => _langProvider.textTranslate(
    "Enter your phone number to receive a 6-digit verification code.",
  );
  String get weWillEmail => _langProvider.textTranslate(
    "Enter your email address to receive a 6-digit verification code.",
  );
  String get sendOtp => _langProvider.textTranslate("Send OTP");
}

class OTPScreenString {
  final LanguageProvider _langProvider;
  OTPScreenString(this._langProvider);

  String get digitOtpHaseBeenSentTo =>
      _langProvider.textTranslate("6 digit OTP has been sent to ");
  String get resendCodein0130 =>
      _langProvider.textTranslate("Resend Code in 01:30");
  String get resendCodein000 =>
      _langProvider.textTranslate("Resend Code in 00:0");
  String get resendCodein0 => _langProvider.textTranslate("Resend Code in 0");
  String get resendOTP => _langProvider.textTranslate("Resend OTP");
}

class AddInfoScreenString {
  final LanguageProvider _langProvider;
  AddInfoScreenString(this._langProvider);

  String get addInfo => _langProvider.textTranslate("Add Info");
  String get userName => _langProvider.textTranslate("User Name");
  String get firstName => _langProvider.textTranslate("First Name");
  String get lastName => _langProvider.textTranslate("Last Name");
  String get gender => _langProvider.textTranslate("Gender");
  final String male = "Male";
  final String female = "Female";
  String get contactDetails => _langProvider.textTranslate("Contact Details");
  String get nonChangeable => _langProvider.textTranslate("Non Changeable");
  String get changeProfile => _langProvider.textTranslate("Change Profile");
}

class AvatarScreenString {
  final LanguageProvider _langProvider;
  AvatarScreenString(this._langProvider);

  String get selectProfile => _langProvider.textTranslate("Select Profile");
  String get chooseAvtar => _langProvider.textTranslate("Choose Avtar");
  String get chooseFrom => _langProvider.textTranslate("Choose From");
  String get avatar => _langProvider.textTranslate("Avatar");
  String get selectAvatarPhoto =>
      _langProvider.textTranslate("Select Avatar Photo");
}

class BottomNavString {
  final LanguageProvider _langProvider;
  BottomNavString(this._langProvider);

  String get call => _langProvider.textTranslate("Call");
  String get status => _langProvider.textTranslate("Status");
  String get contact => _langProvider.textTranslate("Contact");
  String get setting => _langProvider.textTranslate("Setting");
  String get chat => _langProvider.textTranslate("Chat");
}

class HomeScreenString {
  final LanguageProvider _langProvider;
  HomeScreenString(this._langProvider);

  String get chat => _langProvider.textTranslate("Chat");
  String get searchUser => _langProvider.textTranslate("Search User");
  String get createGroup => _langProvider.textTranslate("Create Group");
  String get personalizedPrayersforEveryNeed =>
      _langProvider.textTranslate("Personalized Prayers for Every Need");
  String get chats => _langProvider.textTranslate("Chats");
  String get newGroup => _langProvider.textTranslate("New Group");
  String get archiveChat => _langProvider.textTranslate("Archive Chat");
  String get chatLock => _langProvider.textTranslate("Chat Lock");
  String get viewProfile => _langProvider.textTranslate("View Profile");
  String get groupInfo => _langProvider.textTranslate("Group Info");
  String get archived => _langProvider.textTranslate("Archived");
  String get unarchiveChat => _langProvider.textTranslate("Unarchive Chat");
  String get archivelist => _langProvider.textTranslate("Archive list");
  String get pinnedMessage => _langProvider.textTranslate('Pinned Message');
  String get unpinMessage => _langProvider.textTranslate("Unpin Message");
  // *
  String get pinMessage => _langProvider.textTranslate("Pin Message");
  // *
  String get youCanUnpinAtAnyTime =>
      _langProvider.textTranslate("You can unpin at any time");
  // *
  String get hours => _langProvider.textTranslate("Hours");
  // *
  String get days => _langProvider.textTranslate("Days");
  String get messages => _langProvider.textTranslate("messages");
  String get deleteMessage => _langProvider.textTranslate("Delete Message");
  String get chooseHowYouWantToDeleteTheMessages =>
      _langProvider.textTranslate("Choose how you want to delete the messages");
  String get areYouSureYouWantToUnpin => _langProvider.textTranslate(
    'Are you sure you want to unpin this message?',
  );
  String
  get itWillBeRemovedFromThePinnedMessages => _langProvider.textTranslate(
    'It will be removed from the pinned messages list and other users will no longer see it as pinned.',
  );
  // *
  String get thisWillDelete => _langProvider.textTranslate(
    'This will delete all messages from this chat. This action cannot be undone.',
  );
  String get unpin => _langProvider.textTranslate("Unpin");
  String get areYouSureBlock =>
      _langProvider.textTranslate("Are you sure you want to Block");
  String get areYouSureUnblock =>
      _langProvider.textTranslate("Are you sure you want to Unblock");
  // *
  String get block => _langProvider.textTranslate("Blocked");
  // *
  String get unblock => _langProvider.textTranslate("Unblocked");
  String get clearChat => _langProvider.textTranslate("Clear Chat");
  String get clearThisChat => _langProvider.textTranslate("Clear this Chat?");
  String get alsoDeleteMediaReceived => _langProvider.textTranslate(
    "Also delete media received in this chat from the device gallery",
  );
}

class ChatLockStrings {
  final LanguageProvider _languageProvider;

  ChatLockStrings(this._languageProvider);

  String get chatLock => _languageProvider.textTranslate("Chat Lock");
  String get lockChat => _languageProvider.textTranslate("Lock Chat");
  String get setPin => _languageProvider.textTranslate("Set PIN");
  String get manageAnytime => _languageProvider.textTranslate("Manage anytime");
  String get existingPinMessage => _languageProvider.textTranslate(
    "Your existing lock PIN will be used for this chat.",
  );
  String get youCanChangeOr => _languageProvider.textTranslate(
    "You can change or remove the lock from chat settings.",
  );
  String get digitPin => _languageProvider.textTranslate(
    "A 4-digit PIN is required every time you open this chat.",
  );
  String get pinProtected => _languageProvider.textTranslate("PIN protected");
  String get messagesHidden =>
      _languageProvider.textTranslate("Messages hidden");
  String get lockedChatShows => _languageProvider.textTranslate(
    'Locked chat shows "🔒 Locked message" instead of preview.',
  );
  String get lockThisChat => _languageProvider.textTranslate("Lock this Chat?");
  String get lockRemovedFrom =>
      _languageProvider.textTranslate("Lock removed from");
  String get pinUpdatedFor =>
      _languageProvider.textTranslate("PIN updated for");
  String get pinUpdated => _languageProvider.textTranslate("PIN updated");
  String get isNowLocked => _languageProvider.textTranslate("is now locked");
  String get chatIsLocked => _languageProvider.textTranslate("Chat is locked");
  String get chatIsUnlocked =>
      _languageProvider.textTranslate("Chat is unlocked");
  String get removeLock => _languageProvider.textTranslate("Remove Lock");
  String get disablePinProtection =>
      _languageProvider.textTranslate("Disable PIN protection");
  String get setPinToProtectThisChat =>
      _languageProvider.textTranslate("Set a PIN to protect this chat");
  String get changePin => _languageProvider.textTranslate("Change PIN");
  String get setANew4DigitPIN =>
      _languageProvider.textTranslate("Set a new 4-digit PIN");
  String get enterPin => _languageProvider.textTranslate("Enter PIN");
  String get confirmPin => _languageProvider.textTranslate("Confirm PIN");
  String get enterYour4DigitPINFor =>
      _languageProvider.textTranslate("Enter your 4-digit PIN for");
  String get removeLockConfirmMessage => _languageProvider.textTranslate(
    'Are you sure you want to remove the lock from this chat?',
  );
  String get reenterYourPINToConfirm =>
      _languageProvider.textTranslate("Re-enter your PIN to confirm");
  String get createa4DigitPIN =>
      _languageProvider.textTranslate("Create a 4-digit PIN for");
  String get cancel => _languageProvider.textTranslate("Cancel");
  String get incorrectPin => _languageProvider.textTranslate("Incorrect PIN");
  String get pinsDoNotMatch =>
      _languageProvider.textTranslate("PINs do not match");
}

class GeoupProfileString {
  final LanguageProvider _langProvider;
  GeoupProfileString(this._langProvider);

  String get audio => _langProvider.textTranslate("Audio");
  String get video => _langProvider.textTranslate("Video");
  String get search => _langProvider.textTranslate("Search");
  String get report => _langProvider.textTranslate("Report");
  String get block => _langProvider.textTranslate("Block");
  String get unBlock => _langProvider.textTranslate("Unblock");
  String get mediaLinkandDocs =>
      _langProvider.textTranslate("Media, links and docs");
  // *
  String get docs => _langProvider.textTranslate('Docs');
  String get links => _langProvider.textTranslate('Links');
  String get makeAdmin => _langProvider.textTranslate("Make Admin");
  String get areyousureyouwanttomake =>
      _langProvider.textTranslate("Are you sure you want to make");
  String get anadmin => _langProvider.textTranslate('an admin');
  String get confirm => _langProvider.textTranslate("Confirm");
  String get isnowanadmin => _langProvider.textTranslate("is now an admin");
  String get failedtomake => _langProvider.textTranslate("Failed to make");
  String get removeMember => _langProvider.textTranslate("Remove Member");
  String get areyousureyouwanttoremove =>
      _langProvider.textTranslate("Are you sure you want to remove");
  String get fromthegroup => _langProvider.textTranslate("from the group");
  String get remove => _langProvider.textTranslate("Remove");
  String get removedfromgroup =>
      _langProvider.textTranslate("removed from group");
  String get failedtoremove => _langProvider.textTranslate("Failed to remove");
  String get youarenotamemberofthisgroup =>
      _langProvider.textTranslate("You are not a member of this group");
  String get group => _langProvider.textTranslate("Group");
  String get member => _langProvider.textTranslate("member");
  String get removeAdmin => _langProvider.textTranslate("Remove Admin");
  String get removeRights => _langProvider.textTranslate(
    "Are you sure you want to remove admin rights from",
  );
  String get isNowAnRemoveAsAdmin =>
      _langProvider.textTranslate("is now an remove as admin");
}

class SettingStrigs {
  final LanguageProvider _langProvider;
  SettingStrigs(this._langProvider);

  String get settings => _langProvider.textTranslate("Settings");
  String get profile => _langProvider.textTranslate("Profile");
  String get starredMessages => _langProvider.textTranslate("Starred Messages");
  String get blockContacts => _langProvider.textTranslate("Block Contacts");
  String get appLanguage => _langProvider.textTranslate("App Language");
  String get about => _langProvider.textTranslate("About");
  String get feedback => _langProvider.textTranslate("Feedback");
  String get termsConditions =>
      _langProvider.textTranslate("Terms & Conditions");
  String get privacyPolicy => _langProvider.textTranslate("Privacy Policy");
  String get logout => _langProvider.textTranslate("Logout");
  String get logoutAsk1 =>
      _langProvider.textTranslate("Are you sure you want to Logout?");
  String get logoutAsk => _langProvider.textTranslate(
    "Are you sure you want to Logout your Account?",
  );
  String get deleteAccount => _langProvider.textTranslate("Delete Account");
  String get deleteAsk1 =>
      _langProvider.textTranslate("Are you sure you want to Delete Account?");
  String get deleteAsk => _langProvider.textTranslate(
    "Are you sure you want to Delete your Account?",
  );
  String get editProfile => _langProvider.textTranslate("Edit Profile");
  String get update => _langProvider.textTranslate("Update");
  String get blockList => _langProvider.textTranslate("Block list");
  String get block => _langProvider.textTranslate("Block");
  String get unblock => _langProvider.textTranslate("Unblock");
  String get status => _langProvider.textTranslate("Status");
  //** Do Not Translate below final String text used in status bio screen **//
  final String available = "Available";
  final String atWork = "At work";
  final String atOffice = "At Office";
  final String batteryAboutToDie = "Battery about to die";
  final String intAMetting = "In a metting";
  final String atTheGym = "At the gym";
  final String sleepin = "Sleeping";
  String get profilePhoto => _langProvider.textTranslate("Profile Photo");
  String get camera => _langProvider.textTranslate("Camera");
  String get gellery => _langProvider.textTranslate("Gallery");
  String get delete => _langProvider.textTranslate("Delete");
  String get selectAvatar => _langProvider.textTranslate("Select Avatar");
  String get currentlySetTo => _langProvider.textTranslate("Currently set to");
  String get selectYourAbout =>
      _langProvider.textTranslate("Select your About");
  String get edit => _langProvider.textTranslate("Edit");
  String get writeSomething => _langProvider.textTranslate("Write Something");
  String get selected => _langProvider.textTranslate("selected");
  String get unstarMessage => _langProvider.textTranslate("Unstar Message");
  String get areYouSureYouWantToUnstarThisMessage => _langProvider
      .textTranslate("Are you sure you want to unstar this message?");
  String get unstar => _langProvider.textTranslate("Unstar");
  // *
  String get chatcolor => _langProvider.textTranslate("Chat color");
  String get resetToDefault => _langProvider.textTranslate("Reset to Default");
  String get apply => _langProvider.textTranslate("Apply");
  String get themeColorUpdated =>
      _langProvider.textTranslate("Theme color updated successfully");
  String get themeResetToDefault =>
      _langProvider.textTranslate("Theme reset to default");
  String get editAndManageYourProfile =>
      _langProvider.textTranslate("Edit and manage your profile information");
  String get updateYourAbout =>
      _langProvider.textTranslate("Update your About to reflect your work");
  String get keepsSavedMessage =>
      _langProvider.textTranslate("Keep saved messages for quick access");
  String get yourBlocked =>
      _langProvider.textTranslate("Your blocked contacts appear here");
  String get selectYourlanguage =>
      _langProvider.textTranslate("Select your preferred app language");
  String get customizeColor =>
      _langProvider.textTranslate("Customize your chat theme color");
  String get switchBetween =>
      _langProvider.textTranslate("Switch between light and dark theme");
  String get readOurTerms =>
      _langProvider.textTranslate("Read our terms and conditions");
  String get readOurPolicy =>
      _langProvider.textTranslate("Read our privacy policy");
  String get securlyLogOut =>
      _langProvider.textTranslate("Securely log out from this device");
  String get custom => _langProvider.textTranslate("Custom");
  String get loggingOut => _langProvider.textTranslate("loggingOut...");
}

class ChatBubbleStrings {
  final LanguageProvider _langProvider;
  ChatBubbleStrings(this._langProvider);

  String get copy => _langProvider.textTranslate("Copy");
  String get reply => _langProvider.textTranslate("Reply");
  String get forward => _langProvider.textTranslate("Forward");
  String get delete => _langProvider.textTranslate("Delete");
  String get edit => _langProvider.textTranslate("Edit");
  String get starMessage => _langProvider.textTranslate("Star Message");
  String get report => _langProvider.textTranslate("Report");
}

class StoryStrings {
  final LanguageProvider _langProvider;
  StoryStrings(this._langProvider);

  String get status => _langProvider.textTranslate("Status");
  String get myStatus => _langProvider.textTranslate("My Status");
  String get tapToAddYourStory =>
      _langProvider.textTranslate("Tap to add your story");
  String get recentUpdates => _langProvider.textTranslate("Recent Updates");
  String get viewedStatus => _langProvider.textTranslate("Viewed Status");
  String get upload => _langProvider.textTranslate("Upload");
  String get addCaption => _langProvider.textTranslate("Add Caption.....");
  String get typeReply => _langProvider.textTranslate('Type reply.......');
  String get viewedBy => _langProvider.textTranslate("Viewed by");
  String get deleteStatus => _langProvider.textTranslate("Delete Status");
  String get areYouSureYouWantToDelet => _langProvider.textTranslate(
    "Are you sure you want to Delete your status?",
  );
  // *
  String get areYouSureYouWantTo =>
      _langProvider.textTranslate("Are you sure you want to Delete?");
}

class OnboardingStrings {
  final LanguageProvider _langProvider;
  OnboardingStrings(this._langProvider);
  //Notification Preferences
  String get configureNotifications =>
      _langProvider.textTranslate("Configure Notifications");
  String get chooseWhat => _langProvider.textTranslate(
    "Choose what matters the most to you We promise not to spam you",
  );
  String get notificationPreferences =>
      _langProvider.textTranslate("Notification Preferences");
  String get allNewMessages => _langProvider.textTranslate("All New Messages");
  String get userWillReceive => _langProvider.textTranslate(
    "User will receive the notification for all the messages they receive.",
  );
  String get messagesInGroup =>
      _langProvider.textTranslate("Messages in Group");
  String get userWillGroup => _langProvider.textTranslate(
    "User will receive the notification for all the messages they receive in the group.",
  );
  String get audioCall => _langProvider.textTranslate("Audio Call");
  String get userWillAudioCall => _langProvider.textTranslate(
    "User will receive the notification for the audio call when the opposite person calls you.",
  );
  String get videoCall => _langProvider.textTranslate("Video Call");
  String get userWillVideCall => _langProvider.textTranslate(
    "User will receive the notification for the video call when the opposite person calls you.",
  );
  String get toReceiveNotification => _langProvider.textTranslate(
    "To receive the notification all notification should be on, so the application work without interruption.",
  );
  String get ifYouWantToDisable => _langProvider.textTranslate(
    "If you want to disable notification then you can go to settings and disable it.",
  );
  //Location Permission Preferences
  String get configurePermission =>
      _langProvider.textTranslate("Configure Permission");
  String get locationPrefe =>
      _langProvider.textTranslate("Location Permission Preferences");
  String get shareLocation => _langProvider.textTranslate("Share Location");
  String get viewTheSharedLocation =>
      _langProvider.textTranslate("View the shared location");
  String get toAccessLocation => _langProvider.textTranslate(
    "To access location permission then it should be on, or else location won’t be accessible.",
  );
  //Contact Permission Preferences
  String get contactPermission =>
      _langProvider.textTranslate("Contact Permission Preferences");
  String get canViewAllContacts =>
      _langProvider.textTranslate("Can View All Contacts");
  String get oneNotification => _langProvider.textTranslate(
    "Once Notification on so user can view all the contacts from their phone.",
  );
  String get shareTheContact =>
      _langProvider.textTranslate("Share The Contact");
  String get whileAllowingThis => _langProvider.textTranslate(
    "While allowing this permission user can share the contact of each other in the chat.",
  );
  String get toAccessContact => _langProvider.textTranslate(
    "To access contact permission then it should be on, or else contact won’t be accessible.",
  );
  //Gallery Notification Preferences
  String get galleryNotifi =>
      _langProvider.textTranslate("Gallery Notification Preferences");
  String get photoAccess =>
      _langProvider.textTranslate("Photo Access Permission");
  String get userNeedToAllow => _langProvider.textTranslate(
    "User need to allow this notification so that the user can share the photo in the chat.",
  );
  String get videoAccess =>
      _langProvider.textTranslate("Video Access Permission");
  String get userNeedToVideo => _langProvider.textTranslate(
    "User need to allow this notification so that the user can share the video in the chat.",
  );
  String get viewAccessPermission =>
      _langProvider.textTranslate("View Access Permission");
  String get userAllowDownload => _langProvider.textTranslate(
    "User need to allow this notification so that the user can view or download the photo/video in the chat.",
  );
  String get toAccessGalley => _langProvider.textTranslate(
    "To access gallery permission then it should be on, or else gallery won’t be accessible.",
  );
}

class BlockUserStrings {
  final LanguageProvider _langProvider;
  BlockUserStrings(this._langProvider);

  String get blockU => _langProvider.textTranslate("Block");
  String get blockS => _langProvider.textTranslate("block");
  String get unblockU => _langProvider.textTranslate("Unblock");
  String get unblockS => _langProvider.textTranslate("unblock");
  String get unbolockUser => _langProvider.textTranslate("Unblock User");
  String get blockUser => _langProvider.textTranslate("Block User");
  String get areYouSureYouWantToUnblock =>
      _langProvider.textTranslate("Are you sure you want to unblock");
  String get youWillBeAbleToChatWithThemAgain =>
      _langProvider.textTranslate("You will be able to chat with them again.");
  String get areYouSureYouWantToBlock =>
      _langProvider.textTranslate("Are you sure you want to block");
  String get youWillBeNotAbleToChatWithThem =>
      _langProvider.textTranslate("You will not be able to chat with them.");
  String get hasBeenUnblocked =>
      _langProvider.textTranslate("has been unblocked");
  String get hasBeenBlocked => _langProvider.textTranslate("has been blocked");
  String get failedto => _langProvider.textTranslate("Failed to");
  String get noBlockContact => _langProvider.textTranslate("No Block Contact");
  String get youdonthaveanyblockContact =>
      _langProvider.textTranslate("You don’t have any block Contact");
  String get failedToUnblock =>
      _langProvider.textTranslate("Failed to unblock");
  String get blockedByUser => _langProvider.textTranslate("Blocked by User");
}

class DeleteChatString {
  final LanguageProvider _langProvider;
  DeleteChatString(this._langProvider);

  String get deleteChat => _langProvider.textTranslate("Delete Chat");
  String get areYouSureYouWantToDeleteThis =>
      _langProvider.textTranslate("Are you sure you want to delete this");
  String get group => _langProvider.textTranslate("group");
  String get chat => _langProvider.textTranslate("chat");
  String get thisActionCannotbBeUndone =>
      _langProvider.textTranslate("This action cannot be undone.");
  String get delete => _langProvider.textTranslate("Delete");
}

class EmptyDataString {
  final LanguageProvider _langProvider;
  EmptyDataString(this._langProvider);

  String get startNewChat => _langProvider.textTranslate("Start New Chat");
  String get beginFreshConversationAnytime =>
      _langProvider.textTranslate("Begin a fresh conversation anytime.");
  String get startConversation =>
      _langProvider.textTranslate("Start Conversation");
  String get sayHIstartconversation =>
      _langProvider.textTranslate("Say \"hi\" to start conversation");
  String get noStarMessage => _langProvider.textTranslate("No Star Message");
  String get youdonthaveStarMessage =>
      _langProvider.textTranslate("You don’t have any Star Message");
  String get youdonthaveanyImage =>
      _langProvider.textTranslate("You don’t have any Image");
  String get noPhotosFound => _langProvider.textTranslate("No Photos Found");
  String get noDocumentFound =>
      _langProvider.textTranslate("No Document Found");
  String get youdonthaveanyDocuments =>
      _langProvider.textTranslate("You don’t have any Documents");
  String get noLinkFound => _langProvider.textTranslate("No Link Found");
  String get youdonthaveanyLinks =>
      _langProvider.textTranslate("You don’t have any Links");
  String get noStatusFound => _langProvider.textTranslate("No Status Found");
  String get youdonthaveanystatustoshow =>
      _langProvider.textTranslate("You don't have any status to show");
  String get noarchivedchats =>
      _langProvider.textTranslate("No archived chats");
  String get whenYouArchiveChatsTheyllAppearHere => _langProvider.textTranslate(
    "When you archive chats, they'll appear here",
  );
  String get noCall => _langProvider.textTranslate("No Call");
  String get youdonthavecalllogstoshow =>
      _langProvider.textTranslate("You don't have call logs to show");
  String get notificationNotFound =>
      _langProvider.textTranslate("Notification Not Found");
  String get youdonthaveanyNotification =>
      _langProvider.textTranslate("You don't have any Notification");
}

class ReportString {
  final LanguageProvider _langProvider;
  ReportString(this._langProvider);

  String get reportAccount => _langProvider.textTranslate("Report Account");
  String get whyAreYouReporting =>
      _langProvider.textTranslate("why are you reporting this Post?");
  String get itsSpam => _langProvider.textTranslate("Its’s Spam");
  String get ahteSpeech =>
      _langProvider.textTranslate("Hate speech or symbols");
  String get bullying => _langProvider.textTranslate("Bullying or harassment");
  String get scam => _langProvider.textTranslate("Scam or fraud");
  String get drugs => _langProvider.textTranslate("Drugs");
  String get other => _langProvider.textTranslate("Other reasons");
}

class SubscriptionStrings {
  final LanguageProvider _langProvider;
  SubscriptionStrings(this._langProvider);

  String get getVerified => _langProvider.textTranslate("Upgrade to premium");
  String get notAvailableYet =>
      _langProvider.textTranslate("Not available yet");
  String get mobileOnly => _langProvider.textTranslate(
    "Subscriptions are available only in the Android and iOS apps.",
  );
  String get becomeVerifiedTitle =>
      _langProvider.textTranslate("Become Verified and Go Ad-Free");
  String get becomeVerifiedSubtitle => _langProvider.textTranslate(
    "Show your authentic self and enjoy an uninterrupted, ad-free app experience. Join the community!",
  );
  String get blueTick => _langProvider.textTranslate("Blue Tick");
  String get blueTickDesc => _langProvider.textTranslate(
    "Displays a prestigious verification badge next to your profile name, signaling authenticity.",
  );
  String get noAds => _langProvider.textTranslate("No Ads");
  String get noAdsDesc => _langProvider.textTranslate(
    "Removes all advertisements for a completely smooth and focused usage.",
  );
  String get loadPlansError => _langProvider.textTranslate(
    "Unable to load subscription plans. Please try again.",
  );
  String get plansUnavailable => _langProvider.textTranslate(
    "Subscription plans are not available right now.",
  );
  String get bestValue => _langProvider.textTranslate("BEST VALUE");
  String savePercent(String percent) =>
      AppString.trParams("Save {percent}%", {'percent': percent});
  String get yearlyPlan => _langProvider.textTranslate("Yearly plan");
  String get monthlyPlan => _langProvider.textTranslate("Monthly plan");
  String get subscriptionActive =>
      _langProvider.textTranslate("Your subscription is active");
  String get unlockAllFeatures =>
      _langProvider.textTranslate("Unlock All Features");
  String get subscribe => _langProvider.textTranslate("Subscribe");
  String get yearly => _langProvider.textTranslate("Yearly");
  String get monthly => _langProvider.textTranslate("Monthly");
  String get year => _langProvider.textTranslate("year");
  String get month => _langProvider.textTranslate("month");
  String get restorePurchases =>
      _langProvider.textTranslate("Restore Purchases");
  String get renewalInfo => _langProvider.textTranslate(
    "Subscription renews automatically unless canceled. Payment is charged to your Google Play account, and you can manage or cancel it anytime in Google Play.",
  );
  String get renewalInfoIos => _langProvider.textTranslate(
    "Subscription renews automatically unless canceled at least 24 hours before the end of the current period. Payment is charged to your Apple ID account, and you can manage or cancel it anytime in your App Store account settings.",
  );
  String get equivalentTo => _langProvider.textTranslate("equivalent to");
  String get billedYearly => _langProvider.textTranslate("Billed once a year");
  String get billedMonthly => _langProvider.textTranslate("Billed every month");
  String get purchaseFailed => _langProvider.textTranslate(
    "Purchase could not be completed. Please try again.",
  );
  String get paymentPending => _langProvider.textTranslate(
    "Your payment is pending. You will be subscribed once it is confirmed.",
  );
  String get purchaseCanceled =>
      _langProvider.textTranslate("Purchase was canceled.");
  String get subscriptionActivated =>
      _langProvider.textTranslate("Subscription activated. Thank you!");
  String get restoreFailed =>
      _langProvider.textTranslate("Unable to restore your purchase.");
  String get restoreSuccess =>
      _langProvider.textTranslate("Your subscription has been restored.");
  String get nothingToRestore =>
      _langProvider.textTranslate("No previous purchase found to restore.");
  String get goAdFree =>
      _langProvider.textTranslate("Get the blue tick and go ad-free");

  String validUntil(String date) =>
      AppString.trParams("Valid until {date}", {'date': date});
  String get manageSubscription =>
      _langProvider.textTranslate("Manage subscription");

  String get subscriptionHistory => _langProvider.textTranslate("Subscription history");
  String get noSubscriptionHistory => _langProvider.textTranslate("No subscription history yet");
  String get loadHistoryError => _langProvider.textTranslate("Unable to load subscription history. Please try again.");
  String get statusActive => _langProvider.textTranslate("Active");
  String get statusExpired => _langProvider.textTranslate("Expired");
  String get statusRevoked => _langProvider.textTranslate("Revoked");
  String get statusPending => _langProvider.textTranslate("Pending");
  String purchasedOn(String date) =>
      AppString.trParams("Purchased on {date}", {'date': date});
  String endsOn(String date) =>
      AppString.trParams("Ends on {date}", {'date': date});

  String get currentPlan => _langProvider.textTranslate("Active Plan");
  String get currentPlanActive => _langProvider.textTranslate("Current Plan Active");
  String get upgradeToYearly => _langProvider.textTranslate("Upgrade to Yearly");

  String activeRenews(String date) =>
      AppString.trParams('Active • Renews {date}', {'date': date});

  String linkedElsewhere(String store) => AppString.trParams(
    'This {store} account already has an active subscription linked to another account. Log in with that account, or use a different {store} account to subscribe.',
    {'store': store},
  );
}


class ProfileStrings {
  final LanguageProvider _langProvider;
  ProfileStrings(this._langProvider);

  String get edit => _langProvider.textTranslate("Edit");
  String get editProfile => _langProvider.textTranslate("Edit Profile");
  String get catalogue => _langProvider.textTranslate("Catalogue");
  String get manage => _langProvider.textTranslate("Manage");
  String get noCatalogAvailable =>
      _langProvider.textTranslate("No catalog items available");
  String get businessHours => _langProvider.textTranslate("Business hours");
  String get softwareCompany => _langProvider.textTranslate("Software Company");
  String get description => _langProvider.textTranslate("Description");
  String get businessAccount => _langProvider.textTranslate("Business Account");
  String get thisAccountUses => _langProvider.textTranslate("This account was");
  String get location => _langProvider.textTranslate("Location");
  String get noCoverimage => _langProvider.textTranslate("No cover image");
  String get editBusinessProfile =>
      _langProvider.textTranslate("Edit Business Profile");
  String get save => _langProvider.textTranslate("Save");
  String get tapToAddCoverImage =>
      _langProvider.textTranslate("Tap to add cover image");
  String get change => _langProvider.textTranslate("Change");
  String get businessInformation =>
      _langProvider.textTranslate("Business Information");
  String get locationContact =>
      _langProvider.textTranslate("Location & Contact");
  String get socialMediaLinks =>
      _langProvider.textTranslate("Social Media Links");
  String get businessName => _langProvider.textTranslate("Business Name");
  String get enterYourbusinessName =>
      _langProvider.textTranslate("Enter your business name");
  String get pleaseEnterBusinessName =>
      _langProvider.textTranslate("Please enter business name");
  String get enterDescription =>
      _langProvider.textTranslate("Enter business description...");
  String get pleaseDescription =>
      _langProvider.textTranslate("Please enter business description");
  String get category => _langProvider.textTranslate("Category");
  String get loadingCategories =>
      _langProvider.textTranslate("Loading categories...");
  String get noCategories =>
      _langProvider.textTranslate("No categories available");
  String get pleaseSelectCategory =>
      _langProvider.textTranslate("Please select a category");
  String get selectCategory => _langProvider.textTranslate("Select a category");
  String get selectcategory => _langProvider.textTranslate("Select Category");
  String get hours => _langProvider.textTranslate("Hours");
  String get appointmentsOnly =>
      _langProvider.textTranslate("Appointments Only");
  String get yourBusineesOperates => _langProvider.textTranslate(
    "Your business operates by appointments only.",
  );
  String get customersWillNeedTo => _langProvider.textTranslate(
    "Customers will need to book appointments to visit.",
  );
  String get enterBusinessLocation =>
      _langProvider.textTranslate("Enter business location");
  String get pleaseEnterLocation =>
      _langProvider.textTranslate("Please enter location");
  String get contact => _langProvider.textTranslate("Contact");
  String get enterMobileNumber =>
      _langProvider.textTranslate("Enter mobile number");
  String get yourMobileCannot =>
      _langProvider.textTranslate("Your mobile number cannot be changed.");
  String get yourEmailCannot =>
      _langProvider.textTranslate("Your Email Address cannot be changed.");
  String get website => _langProvider.textTranslate("Website");
  String get enterWebsite =>
      _langProvider.textTranslate("Enter website URL (optional)");
  String get enterFacebookUrl =>
      _langProvider.textTranslate("Enter Facebook profile URL");
  String get enterInstagramUrl =>
      _langProvider.textTranslate("Enter Instagram profile URL");
  String get enterLinkedInUrl =>
      _langProvider.textTranslate("Enter LinkedIn profile URL");
  String get enterYoutubUrl =>
      _langProvider.textTranslate("Enter YouTube channel URL");
  String get enterVKUrl => _langProvider.textTranslate("Enter VK profile URL");
  String get businessLocation =>
      _langProvider.textTranslate("Business Location");
  String get locationPermissionRequired =>
      _langProvider.textTranslate("Location Permission Required");
  String get locationPermissionNeeded => _langProvider.textTranslate(
    "Location permission is needed to use your current location. You can still search for a location manually.",
  );
  String get locationAccessNeeded => _langProvider.textTranslate(
    "Location access is needed to use your current location. You can still search for a location manually, or enable location access in Settings.",
  );
  String get selectBusinessLocation =>
      _langProvider.textTranslate("Select Business Location");
  String get searchForYourBusinessAddress =>
      _langProvider.textTranslate("Search for your business address...");
  String get selectedLocation =>
      _langProvider.textTranslate("Selected Location:");
  String get confirmLocation => _langProvider.textTranslate("Confirm Location");
  String get businessTools => _langProvider.textTranslate("Business Tools");
  String get whatsappCatalog => _langProvider.textTranslate("WA Catalog");
  String get tools => _langProvider.textTranslate("Tools");
  String get lastDaysPerformance =>
      _langProvider.textTranslate("Last 7 Days Performance");
  String get conversationsStarted =>
      _langProvider.textTranslate("Conversations");
  String get catalogViews => _langProvider.textTranslate("Catalog Views");
  String get statusViews => _langProvider.textTranslate("Status Views");
  String get growYourBusiness =>
      _langProvider.textTranslate("Grow Your Business");
  String get catalog => _langProvider.textTranslate("Catalog");
  String get showProducts =>
      _langProvider.textTranslate("Show products and Services");
  String get labels => _langProvider.textTranslate("Labels");
  String get organizeChatsWithCustomlabels =>
      _langProvider.textTranslate("Organize chats with custom labels");
  String get greetingMessages =>
      _langProvider.textTranslate("Greeting Messages");
  String get setAutomaticGreetingForNewCustomers =>
      _langProvider.textTranslate("Set automatic greeting for new customers");
  String get awayMessage => _langProvider.textTranslate("Away Message");
  String get setMessageWhenYou =>
      _langProvider.textTranslate("Set message when you're away or busy");
  String get catalogManager => _langProvider.textTranslate("Catalog Manager");
  String get add => _langProvider.textTranslate("Add");
  String get noCatalogYet => _langProvider.textTranslate("No Catalogs Yet");
  String get startShowCasingYour => _langProvider.textTranslate(
    "Start showcasing your products and services by adding your first catalog item.",
  );
  String get addFirstCatalog =>
      _langProvider.textTranslate("Add First Catalog");
  String get noCatalogsAvailable =>
      _langProvider.textTranslate("No catalogs available");
  String get priceCannotExceed =>
      _langProvider.textTranslate("Price cannot exceed");
  String get priceCannotBeNegative =>
      _langProvider.textTranslate("Price cannot be negative");
  String get pleaseEnterValidPrice =>
      _langProvider.textTranslate("Please enter a valid price");
  String get enterPrice => _langProvider.textTranslate("Enter Price");
  String get price => _langProvider.textTranslate("Price");
  String get descriptionMustBe10 =>
      _langProvider.textTranslate("Description must be at least 10 characters");
  String get pleaseEnterProductDescription =>
      _langProvider.textTranslate("Please enter product description");
  String get descriptionStar => _langProvider.textTranslate("Description*");
  String get productTitleMustBe => _langProvider.textTranslate(
    "Product title must be at least 3 characters",
  );
  String get pleaseEnterProductTitle =>
      _langProvider.textTranslate("Please enter product title");
  String get enterTitle => _langProvider.textTranslate("Enter Title");
  String get title => _langProvider.textTranslate("Title*");
  String get addCatalogue => _langProvider.textTranslate("Add Catalogue");
  String get pleaseSelectOne =>
      _langProvider.textTranslate("Please select at least one product image");
  String get images => _langProvider.textTranslate("Images");
  String get productImages => _langProvider.textTranslate("Product Images");
  String get image => _langProvider.textTranslate("Image");
  String get uploadedImage => _langProvider.textTranslate("Uploaded image");
  String get newImage => _langProvider.textTranslate("New image");
  String get addMoreImages => _langProvider.textTranslate("Add More Images");
  String get noImagesAvailable =>
      _langProvider.textTranslate("No Images Available");
  String get addProductImages =>
      _langProvider.textTranslate("Add Product Images");
  String get youCanSelectMultiple => _langProvider.textTranslate(
    "You can select multiple images to showcase your catalog",
  );
  String get titlee => _langProvider.textTranslate("Title");
  String get enterCatalog => _langProvider.textTranslate("Enter catalog title");
  String get titleIsRequired =>
      _langProvider.textTranslate("Title is required");
  String get priceIsRequired =>
      _langProvider.textTranslate("Price is required");
  String get invalidPrice => _langProvider.textTranslate("Invalid price");
  String get priceMustBePositive =>
      _langProvider.textTranslate("Price must be positive");
  String get enterCatalogDescription =>
      _langProvider.textTranslate("Enter catalog description...");
  String get descriptionIsRequired =>
      _langProvider.textTranslate("Description is required");
  String get update => _langProvider.textTranslate("Update");
  String get removeImage => _langProvider.textTranslate("Remove Image");
  String get areYouSureYouWantTo => _langProvider.textTranslate(
    "Are you sure you want to remove this image? This action cannot be undone.",
  );
  String get imageRemovedSuccessfully =>
      _langProvider.textTranslate("Image removed successfully");
  String get failedToRemoveImage =>
      _langProvider.textTranslate("Failed to remove image");
  String get removing => _langProvider.textTranslate("Removing...");
  String get remove => _langProvider.textTranslate("Remove");
  String get labelAdded =>
      _langProvider.textTranslate("Label added successfully");
  String get labelUpdated =>
      _langProvider.textTranslate("Label updated successfully");
  String get deleteLabel => _langProvider.textTranslate("Delete Label");
  String get areYouSureDelete =>
      _langProvider.textTranslate("Are you sure you want to delete");
  String get thisActionCannotBeUndone =>
      _langProvider.textTranslate("This action cannot be undone.");
  String get labelManager => _langProvider.textTranslate("Label Manager");
  String get retry => _langProvider.textTranslate("Retry");
  String get noLabelsYet => _langProvider.textTranslate("No labels yet");
  String get createYouFirst => _langProvider.textTranslate(
    "Create your first label to organize your chats.\nTap to edit, long press to delete.",
  );
  String get createLabel => _langProvider.textTranslate("Create Label");
  String get editLabel => _langProvider.textTranslate("Edit Label");
  String get addNewLabel => _langProvider.textTranslate("Add New Label");
  String get labelText => _langProvider.textTranslate("Label Text");
  String get enterLabelName => _langProvider.textTranslate("Enter label name");
  String get labelTextIsRequired =>
      _langProvider.textTranslate("Label text is required");
  String get labelTextMustBe =>
      _langProvider.textTranslate("Label text must be at least 2 characters");
  String get labelColor => _langProvider.textTranslate("Label Color");
  String get create => _langProvider.textTranslate("Create");
  String get greetingMessage => _langProvider.textTranslate("Greeting Message");
  String get loadingGreetingMessageSettings =>
      _langProvider.textTranslate("Loading greeting message settings...");
  String get failedToLoad => _langProvider.textTranslate("Failed to Load");
  String get automaticGreeting =>
      _langProvider.textTranslate("Automatic Greeting");
  String get sendAnAutomaticGretting => _langProvider.textTranslate(
    "Send an automatic greeting when customers first contact you",
  );
  String get enableGreetingMessage =>
      _langProvider.textTranslate("Enable greeting message");
  String get enterYourGreetingMessage =>
      _langProvider.textTranslate("Enter your greeting message...");
  String get enableGrattingMessage =>
      _langProvider.textTranslate("Enable greeting message to edit");
  String get saveGreetingMessage =>
      _langProvider.textTranslate("Save Greeting Message");
  String get awayMessageCannotBe =>
      _langProvider.textTranslate("Away message cannot be empty when enabled");
  String get awayMessageSavedSuccessfully =>
      _langProvider.textTranslate("Away message saved successfully");
  String get failedToSaveAwayMessage =>
      _langProvider.textTranslate("Failed to save away message:");
  String get loadingAwayMessage =>
      _langProvider.textTranslate("Loading away message settings...");
  String get automaticAwayMessage =>
      _langProvider.textTranslate("Automatic Away Message");
  String get sendAnAutomaticAwayMessage => _langProvider.textTranslate(
    "Send an automatic away message when customers contact you",
  );
  String get enableAwayMessage =>
      _langProvider.textTranslate("Enable away message");
  String get enterYourAwayMessage =>
      _langProvider.textTranslate("Enter your away message...");
  String get enableAwayMessageToEdit =>
      _langProvider.textTranslate("Enable away message to edit");
  String get saveAwayMessage =>
      _langProvider.textTranslate("Save Away Message");
  String get myBusinessProfile =>
      _langProvider.textTranslate("My Business Profile");
  String get updateLabels => _langProvider.textTranslate("Update Labels");
}
