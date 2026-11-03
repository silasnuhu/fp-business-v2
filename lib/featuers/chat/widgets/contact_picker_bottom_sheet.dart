import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/chat/widgets/contact_send_preview.dart';
import 'package:whoxa/featuers/contacts/data/model/contact_model.dart';
import 'package:whoxa/featuers/contacts/provider/contact_provider.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/widgets/global.dart';

class ContactPickerBottomSheet extends StatefulWidget {
  const ContactPickerBottomSheet({super.key});

  @override
  State<ContactPickerBottomSheet> createState() =>
      _ContactPickerBottomSheetState();
}

class _ContactPickerBottomSheetState extends State<ContactPickerBottomSheet> {
  final TextEditingController searchController = TextEditingController();
  List<ContactModel> filteredContacts = [];
  bool _isLoadingContacts = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    try {
      final contactProvider = Provider.of<ContactListProvider>(
        context,
        listen: false,
      );
      await contactProvider.loadContacts();

      setState(() {
        // ✅ UPDATED: Use chatContacts which now handles demo mode automatically
        // For demo accounts: returns all contacts (registered + unregistered)
        // For regular accounts: returns only registered contacts
        if (isDemo) {
          // Demo mode: chatContacts already includes all contacts
          filteredContacts = contactProvider.chatContacts;
          debugPrint('📱 Contact Picker - DEMO MODE: Showing ${filteredContacts.length} total contacts');
        } else {
          // Regular mode: Show registered contacts + unregistered for invite
          final registeredContacts = contactProvider.chatContacts;
          final unregisteredContacts = contactProvider.inviteContacts;
          filteredContacts = [...registeredContacts, ...unregisteredContacts];
          debugPrint('👤 Contact Picker - REGULAR MODE: ${registeredContacts.length} registered + ${unregisteredContacts.length} unregistered');
        }
        _isLoadingContacts = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingContacts = false;
      });
    }
  }

  void _filterContacts(String query) {
    final contactProvider = Provider.of<ContactListProvider>(
      context,
      listen: false,
    );
    setState(() {
      // ✅ UPDATED: Use chatContacts which handles demo mode automatically
      if (isDemo) {
        // Demo mode: chatContacts already includes all contacts
        filteredContacts = contactProvider.chatContacts.where((contact) {
          return contact.name.toLowerCase().contains(query.toLowerCase()) ||
              contact.phoneNumber.contains(query);
        }).toList();
      } else {
        // Regular mode: Filter from both lists
        final registeredContacts =
            contactProvider.chatContacts.where((contact) {
              return contact.name.toLowerCase().contains(query.toLowerCase()) ||
                  contact.phoneNumber.contains(query);
            }).toList();

        final unregisteredContacts =
            contactProvider.inviteContacts.where((contact) {
              return contact.name.toLowerCase().contains(query.toLowerCase()) ||
                  contact.phoneNumber.contains(query);
            }).toList();

        // Combine with registered first
        filteredContacts = [...registeredContacts, ...unregisteredContacts];
      }
    });
  }

  Future<void> _selectContact(ContactModel contact, bool isRegistered) async {
    // Let the user re-check the contact before sharing; cancel keeps them in
    // the picker to choose again.
    final send = await showContactSendPreview(
      context,
      contact: contact,
      isRegistered: isRegistered,
    );
    if (!send || !mounted) return;
    Navigator.of(context).pop(contact);
  }

  // Build contacts list with sections
  Widget _buildContactsListWithSections() {
    final contactProvider = Provider.of<ContactListProvider>(
      context,
      listen: false,
    );

    // Get filtered registered and unregistered contacts
    final registeredContacts =
        filteredContacts
            .where(
              (contact) => contactProvider.chatContacts.any(
                (c) => c.phoneNumber == contact.phoneNumber,
              ),
            )
            .toList();

    final unregisteredContacts =
        filteredContacts
            .where(
              (contact) => contactProvider.inviteContacts.any(
                (c) => c.phoneNumber == contact.phoneNumber,
              ),
            )
            .toList();

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Registered contacts section
        if (registeredContacts.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Registered Contacts (${registeredContacts.length})',
                  style: AppTypography.captionText(
                    context,
                  ).copyWith(fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ],
            ),
          ),
          ...registeredContacts.map(
            (contact) => _buildContactItem(contact, true),
          ),
        ],

        // Unregistered contacts section
        if (unregisteredContacts.isNotEmpty) ...[
          if (registeredContacts.isNotEmpty) SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Other Contacts (${unregisteredContacts.length})',
                  style: AppTypography.captionText(
                    context,
                  ).copyWith(fontWeight: FontWeight.bold, color: Colors.orange),
                ),
              ],
            ),
          ),
          ...unregisteredContacts.map(
            (contact) => _buildContactItem(contact, false),
          ),
        ],
      ],
    );
  }

  // Build individual contact item
  Widget _buildContactItem(ContactModel contact, bool isRegistered) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppThemeManage.appTheme.borderColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isRegistered
                  ? AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.3)
                  : AppThemeManage.appTheme.borderColor,
          width: isRegistered ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            Hero(
              tag: 'contact_${contact.phoneNumber}',
              child: CircleAvatar(
                radius: 24,
                backgroundColor:
                    isRegistered
                        ? AppColors.appPriSecColor.primaryColor
                        : Colors.grey[600],
                // Use backend profile picture if available for registered users
                backgroundImage:
                    isRegistered &&
                            contact.profilePicUrl != null &&
                            contact.profilePicUrl!.isNotEmpty
                        ? NetworkImage(contact.profilePicUrl!)
                        : null,
                child:
                    contact.profilePicUrl == null ||
                            contact.profilePicUrl!.isEmpty
                        ? Text(
                          contact.initials,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        )
                        : null,
              ),
            ),
            // Badge for registered users
            if (isRegistered)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppThemeManage.appTheme.darkGreyColor,
                      width: 2,
                    ),
                  ),
                  child: Icon(Icons.check, color: Colors.white, size: 10),
                ),
              ),
          ],
        ),
        title: Text(
          contact.name,
          style: AppTypography.mediumText(context).copyWith(
            fontWeight: isRegistered ? FontWeight.w600 : FontWeight.w500,
            color: isRegistered ? null : Colors.grey[400],
          ),
        ),
        subtitle: Text(
          contact.formattedPhoneNumber,
          style: AppTypography.captionText(
            context,
          ).copyWith(color: isRegistered ? Colors.grey[600] : Colors.grey[500]),
        ),
        trailing: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.send_rounded,
            color: AppColors.appPriSecColor.primaryColor,
            size: 20,
          ),
        ),
        onTap: () => _selectContact(contact, isRegistered),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppThemeManage.appTheme.darkGreyColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppThemeManage.appTheme.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Contact',
                  style: AppTypography.h3(
                    context,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: Colors.grey[600]),
                  style: IconButton.styleFrom(
                    backgroundColor: AppThemeManage.appTheme.borderColor,
                    shape: CircleBorder(),
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: AppThemeManage.appTheme.borderColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: searchController,
                onChanged: _filterContacts,
                decoration: InputDecoration(
                  hintText: 'Search contacts...',
                  prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  hintStyle: TextStyle(color: Colors.grey[500]),
                ),
              ),
            ),
          ),

          SizedBox(height: 16),

          // Contact list
          Expanded(
            child:
                _isLoadingContacts
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          commonLoading(),
                          SizedBox(height: 16),
                          Text(
                            'Loading contacts...',
                            style: AppTypography.mediumText(
                              context,
                            ).copyWith(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                    : filteredContacts.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.contacts_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            searchController.text.isNotEmpty
                                ? 'No contacts found'
                                : 'No contacts available',
                            style: AppTypography.mediumText(
                              context,
                            ).copyWith(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                    : _buildContactsListWithSections(),
          ),

          // Safe area padding at bottom
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
