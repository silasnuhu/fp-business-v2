import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';

enum PinDialogMode { unlock, setPin, confirmPin, removePin }

class PinDialog extends StatefulWidget {
  final PinDialogMode mode;
  final String chatName;

  /// Used ONLY for local comparison (legacy / change-pin old-pin step).
  /// Leave null when using [onValidatePin] instead.
  final String? correctPin;

  /// Async validator called when mode == unlock and correctPin is null.
  /// Return true if the PIN is accepted by the server, false otherwise.
  final Future<bool> Function(String pin)? onValidatePin;

  final VoidCallback? onSuccess;
  final void Function(String pin)? onPinSet;

  const PinDialog({
    super.key,
    required this.mode,
    required this.chatName,
    this.correctPin,
    this.onValidatePin,
    this.onSuccess,
    this.onPinSet,
  });

  @override
  State<PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<PinDialog>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  bool _hasError = false;
  String _errorMsg = '';
  bool _isValidating = false; // loading state during API call

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  String get _title {
    switch (widget.mode) {
      case PinDialogMode.unlock:
        return AppString.chatLockStrings.enterPin;
      case PinDialogMode.removePin:
        return AppString.chatLockStrings.removeLock; // "Remove Lock"
      case PinDialogMode.confirmPin:
        return AppString.chatLockStrings.confirmPin;
      case PinDialogMode.setPin:
        return _isConfirming
            ? AppString.chatLockStrings.confirmPin
            : AppString.chatLockStrings.setPin;
    }
  }

  String get _subtitle {
    switch (widget.mode) {
      case PinDialogMode.unlock:
        return '${AppString.chatLockStrings.enterYour4DigitPINFor}\n${widget.chatName}';
      case PinDialogMode.removePin:
        return AppString.chatLockStrings.removeLockConfirmMessage;
      // e.g. "Are you sure you want to remove the lock from this chat?"
      case PinDialogMode.confirmPin:
        return AppString.chatLockStrings.reenterYourPINToConfirm;
      case PinDialogMode.setPin:
        return _isConfirming
            ? AppString.chatLockStrings.reenterYourPINToConfirm
            : '${AppString.chatLockStrings.createa4DigitPIN}\n${widget.chatName}';
    }
  }

  void _onKeyPress(String digit) {
    if (_isValidating) return; // block input while API is in flight
    final current = _isConfirming ? _confirmPin : _pin;
    if (current.length >= 4) return;

    setState(() {
      _hasError = false;
      _errorMsg = '';
      if (_isConfirming) {
        _confirmPin += digit;
      } else {
        _pin += digit;
      }
    });

    final updated = _isConfirming ? _confirmPin : _pin;
    if (updated.length == 4) {
      Future.delayed(const Duration(milliseconds: 150), _onPinComplete);
    }
  }

  void _onDelete() {
    if (_isValidating) return;
    setState(() {
      _hasError = false;
      if (_isConfirming && _confirmPin.isNotEmpty) {
        _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
      } else if (!_isConfirming && _pin.isNotEmpty) {
        _pin = _pin.substring(0, _pin.length - 1);
      }
    });
  }

  Future<void> _onPinComplete() async {
    if (widget.mode == PinDialogMode.unlock) {
      // --- API-based validation (new flow) ---
      if (widget.onValidatePin != null) {
        setState(() => _isValidating = true);
        final ok = await widget.onValidatePin!(_pin);
        if (!mounted) return;
        setState(() => _isValidating = false);
        if (ok) {
          Navigator.of(context).pop();
          widget.onSuccess?.call();
        } else {
          _showError(AppString.chatLockStrings.incorrectPin);
          setState(() => _pin = '');
        }
        return;
      }
      // --- Local comparison (fallback / legacy) ---
      if (_pin == widget.correctPin) {
        Navigator.of(context).pop();
        widget.onSuccess?.call();
      } else {
        _showError(AppString.chatLockStrings.incorrectPin);
        setState(() => _pin = '');
      }
    } else {
      // setPin mode — two-step local confirmation, no API here
      if (!_isConfirming) {
        setState(() => _isConfirming = true);
      } else {
        if (_pin == _confirmPin) {
          Navigator.of(context).pop();
          widget.onPinSet?.call(_pin);
        } else {
          _showError(AppString.chatLockStrings.pinsDoNotMatch);
          setState(() {
            _pin = '';
            _confirmPin = '';
            _isConfirming = false;
          });
        }
      }
    }
  }

  void _showError(String msg) {
    setState(() {
      _hasError = true;
      _errorMsg = msg;
    });
    HapticFeedback.vibrate();
    _shakeController.forward(from: 0);
  }

  Widget _buildDots() {
    final current = _isConfirming ? _confirmPin : _pin;
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (_, child) {
        final shake =
            _hasError
                ? (8 * (_shakeAnimation.value - 0.5)).clamp(-8.0, 8.0)
                : 0.0;
        return Transform.translate(offset: Offset(shake * 2, 0), child: child);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (i) {
          final filled = i < current.length;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 10),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  _isValidating
                      ? AppColors.appPriSecColor.primaryColor.withValues(
                        alpha: 0.4,
                      )
                      : _hasError
                      ? Colors.red
                      : filled
                      ? AppColors.appPriSecColor.primaryColor
                      : AppThemeManage.appTheme.darkGreyColor,
              border: Border.all(
                color:
                    _isValidating
                        ? AppColors.appPriSecColor.primaryColor.withValues(
                          alpha: 0.5,
                        )
                        : _hasError
                        ? Colors.red.shade300
                        : filled
                        ? AppColors.appPriSecColor.primaryColor
                        : AppThemeManage.appTheme.borderColor,
                width: 2,
              ),
              boxShadow:
                  filled && !_hasError && !_isValidating
                      ? [
                        BoxShadow(
                          color: AppColors.appPriSecColor.primaryColor
                              .withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                      : null,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildKey(String label, {Widget? icon, VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: _isValidating ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.all(6),
          height: 48,
          decoration: BoxDecoration(
            color:
                icon != null
                    ? Colors.transparent
                    : AppThemeManage.appTheme.darkGreyColor.withValues(
                      alpha: _isValidating ? 0.5 : 1.0,
                    ),
            borderRadius: BorderRadius.circular(16),
            boxShadow:
                icon != null
                    ? null
                    : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
          ),
          child: Center(
            child:
                icon ??
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppThemeManage.appTheme.textColor.withValues(
                      alpha: _isValidating ? 0.4 : 1.0,
                    ),
                  ),
                ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == PinDialogMode.removePin) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_open_rounded,
                  color: Colors.red.shade400,
                  size: 24,
                ),
              ),
              const SizedBox(height: 14),
              // Title
              Text(
                _title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppThemeManage.appTheme.textColor,
                ),
              ),
              const SizedBox(height: 10),
              // Subtitle / message
              Text(
                _subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: AppThemeManage.appTheme.borderColor,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        AppString.cancel,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade400,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onSuccess?.call();
                      },
                      child: Text(
                        AppString.chatLockStrings.removeLock,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
      alignment: Alignment.bottomCenter,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.appPriSecColor.primaryColor.withValues(
                      alpha: 0.12,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_rounded,
                    color: AppColors.appPriSecColor.primaryColor,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppThemeManage.appTheme.textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            _buildDots(),

            // Loading indicator OR error message
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child:
                  _isValidating
                      ? Padding(
                        key: const ValueKey('loading'),
                        padding: const EdgeInsets.only(top: 6),
                        child: SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.appPriSecColor.primaryColor,
                          ),
                        ),
                      )
                      : _hasError
                      ? Padding(
                        key: const ValueKey('error'),
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _errorMsg,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                      : const SizedBox(key: ValueKey('empty'), height: 16),
            ),

            ...[
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
            ].map(
              (row) => Row(
                children:
                    row
                        .map((d) => _buildKey(d, onTap: () => _onKeyPress(d)))
                        .toList(),
              ),
            ),
            Row(
              children: [
                _buildKey('', icon: const SizedBox()),
                _buildKey('0', onTap: () => _onKeyPress('0')),
                _buildKey(
                  '',
                  icon: Icon(
                    Icons.backspace_rounded,
                    color: Colors.grey.shade400,
                    size: 18,
                  ),
                  onTap: _onDelete,
                ),
              ],
            ),

            const SizedBox(height: 4),
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
              ),
              onPressed:
                  _isValidating ? null : () => Navigator.of(context).pop(),
              child: Text(
                AppString.chatLockStrings.cancel,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
