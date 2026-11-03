import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/core/error/app_error.dart';
import 'package:whoxa/design/fp_components.dart';
import 'package:whoxa/design/fp_tokens.dart';
import 'package:whoxa/featuers/provider/theme_provider.dart';
import 'package:whoxa/featuers/business/data/models/auto_replies_model.dart';
import 'package:whoxa/featuers/business/data/repositories/business_repository.dart';
import 'package:whoxa/widgets/global.dart';

/// Greeting + Away message settings (`/business/auto-replies`). The server
/// sends the messages; this screen only edits the settings.
///
/// Rebuilt on the Flickpitch design system: the stock AppBar/card/switch kit
/// was the last old-design surface in the business tools stack.
class AutoRepliesScreen extends StatefulWidget {
  const AutoRepliesScreen({super.key});

  @override
  State<AutoRepliesScreen> createState() => _AutoRepliesScreenState();
}

class _AutoRepliesScreenState extends State<AutoRepliesScreen> {
  final BusinessRepository _repository = GetIt.instance<BusinessRepository>();
  final _greetingController = TextEditingController();
  final _awayController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  bool _greetingEnabled = false;
  bool _awayEnabled = false;
  String _awayMode = AutoReplies.modeOutsideHours;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _greetingController.dispose();
    _awayController.dispose();
    super.dispose();
  }

  String _msg(Object e) => e is AppError ? e.message : e.toString();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final r = await _repository.getAutoReplies();
      _greetingEnabled = r.greetingEnabled;
      _greetingController.text = r.greetingMessage;
      _awayEnabled = r.awayEnabled;
      _awayController.text = r.awayMessage;
      _awayMode = r.awayMode;
    } catch (e) {
      _loadError = _msg(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _snack(String text, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text), backgroundColor: color));
  }

  Future<void> _save() async {
    if (checkDemoMode(context)) return;
    final greeting = _greetingController.text.trim();
    final away = _awayController.text.trim();
    if (_greetingEnabled && greeting.isEmpty) {
      _snack('Greeting message is required', Fp.danger);
      return;
    }
    if (_awayEnabled && away.isEmpty) {
      _snack('Away message is required', Fp.danger);
      return;
    }

    setState(() => _saving = true);
    try {
      await _repository.saveAutoReplies(
        AutoReplies(
          greetingEnabled: _greetingEnabled,
          greetingMessage: greeting,
          awayEnabled: _awayEnabled,
          awayMessage: away,
          awayMode: _awayMode,
        ).toJson(),
      );
      if (mounted) FocusScope.of(context).unfocus();
      _snack('Auto-reply settings saved', Fp.mint);
    } catch (e) {
      _snack(_msg(e), Fp.danger);
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    // Theme dependency: Fp tokens are static, so repaint on theme change.
    context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: Fp.ink,
      body: FpCanvas(
        child: _loading
            ? Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Fp.violet),
                ),
              )
            : _loadError != null
            ? _errorState()
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  Fp.s20,
                  Fp.s12,
                  Fp.s20,
                  Fp.s40,
                ),
                children: [
                  _header(),
                  const SizedBox(height: Fp.s16),
                  Text(
                    'Reply automatically, so a customer never waits in silence.',
                    style: Fp.body.copyWith(color: Fp.textMuted),
                  ),
                  const SizedBox(height: Fp.s24),
                  _replyCard(
                    title: 'Automatic greeting',
                    description:
                        'Sent when a customer writes to you for the first time, '
                        'or after a quiet period.',
                    enabled: _greetingEnabled,
                    onToggle: (v) => setState(() => _greetingEnabled = v),
                    controller: _greetingController,
                    hint: 'Enter your greeting message…',
                    extra: const SizedBox.shrink(),
                  ),
                  const SizedBox(height: Fp.s16),
                  _replyCard(
                    title: 'Away message',
                    description:
                        'Sent to a customer at most once every 24 hours.',
                    enabled: _awayEnabled,
                    onToggle: (v) => setState(() => _awayEnabled = v),
                    controller: _awayController,
                    hint: 'Enter your away message…',
                    extra: Padding(
                      padding: const EdgeInsets.only(top: Fp.s12),
                      child: FpSurface(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Fp.s12,
                          vertical: Fp.s4,
                        ),
                        child: RadioGroup<String>(
                          groupValue: _awayMode,
                          onChanged: (v) {
                            if (_awayEnabled && v != null) {
                              setState(() => _awayMode = v);
                            }
                          },
                          child: Column(
                            children: [
                              RadioListTile<String>(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                activeColor: Fp.violet,
                                enabled: _awayEnabled,
                                title: Text(
                                  'Outside business hours',
                                  style: Fp.bodyStrong,
                                ),
                                subtitle: Text(
                                  'Needs business hours set; not sent for '
                                  'always-open or appointment-only.',
                                  style: Fp.caption.copyWith(
                                    color: Fp.textMuted,
                                  ),
                                ),
                                value: AutoReplies.modeOutsideHours,
                              ),
                              RadioListTile<String>(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                activeColor: Fp.violet,
                                enabled: _awayEnabled,
                                title: Text('Always', style: Fp.bodyStrong),
                                value: AutoReplies.modeAlways,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Fp.s24),
                  if (_saving)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: Fp.s8),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Fp.violet),
                        ),
                      ),
                    )
                  else
                    FpPrimaryButton(
                      label: 'Save changes',
                      icon: Icons.check_rounded,
                      expand: true,
                      onPressed: _save,
                    ),
                ],
              ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded),
          color: Fp.text,
        ),
        const SizedBox(width: Fp.s4),
        Expanded(child: Text('Greeting & away', style: Fp.display)),
      ],
    );
  }

  Widget _errorState() {
    return Padding(
      padding: const EdgeInsets.all(Fp.s20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, size: 34, color: Fp.textFaint),
          const SizedBox(height: Fp.s12),
          Text(
            _loadError!,
            textAlign: TextAlign.center,
            style: Fp.body.copyWith(color: Fp.textMuted),
          ),
          const SizedBox(height: Fp.s16),
          FpPrimaryButton(
            label: 'Try again',
            expand: false,
            onPressed: _load,
          ),
        ],
      ),
    );
  }

  Widget _replyCard({
    required String title,
    required String description,
    required bool enabled,
    required ValueChanged<bool> onToggle,
    required TextEditingController controller,
    required String hint,
    required Widget extra,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Fp.rSm),
      borderSide: BorderSide(color: Fp.hairlineStrong),
    );
    return FpSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: Fp.bodyStrong)),
              Switch(
                value: enabled,
                onChanged: onToggle,
                activeThumbColor: Colors.white,
                activeTrackColor: Fp.violet,
              ),
            ],
          ),
          const SizedBox(height: Fp.s4),
          Text(
            description,
            style: Fp.caption.copyWith(color: Fp.textMuted, height: 1.45),
          ),
          const SizedBox(height: Fp.s12),
          TextField(
            controller: controller,
            enabled: enabled,
            maxLines: 4,
            maxLength: 1000,
            style: Fp.body,
            cursorColor: Fp.violet,
            decoration: InputDecoration(
              hintText: enabled ? hint : 'Turn on to edit',
              hintStyle: Fp.body.copyWith(color: Fp.textFaint),
              counterStyle: Fp.caption.copyWith(color: Fp.textFaint),
              filled: true,
              fillColor: enabled ? Fp.inkRaised : Fp.inkSoft,
              border: border,
              enabledBorder: border,
              disabledBorder: border,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Fp.rSm),
                borderSide: BorderSide(color: Fp.violet, width: 1.4),
              ),
            ),
          ),
          extra,
        ],
      ),
    );
  }
}
