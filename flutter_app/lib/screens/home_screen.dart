// BoxRFID – Filament Tag Manager
//
// Author: Tinkerbarn
// License: CC BY-NC-SA 4.0 (SPDX-License-Identifier: CC-BY-NC-SA-4.0)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/defaults.dart';
import '../data/translations.dart';
import '../providers/app_provider.dart';
import '../services/nfc_service.dart';
import '../widgets/color_grid_widget.dart';
import '../widgets/tag_info_dialog.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _nfcAvailable = false;
  bool _nfcChecked = false;

  @override
  void initState() {
    super.initState();
    _checkNfc();
  }

  Future<void> _checkNfc() async {
    final available = await NfcService.instance.isAvailable();
    if (mounted) {
      setState(() {
        _nfcAvailable = available;
        _nfcChecked = true;
      });
    }
  }

  // ── Background colour helpers ─────────────────────────────────────────────

  static Color _hexToFlutterColor(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    final value = int.tryParse('FF$cleaned', radix: 16);
    return value != null ? Color(value) : Colors.grey;
  }

  static Color _bgLight(String? hex) {
    const base = Color(0xFFF4F6FB);
    if (hex == null) return base;
    return Color.lerp(base, _hexToFlutterColor(hex), 0.20)!;
  }

  static Color _bgDark(String? hex) {
    const base = Color(0xFFE6EAF4);
    if (hex == null) return base;
    return Color.lerp(base, _hexToFlutterColor(hex), 0.38)!;
  }

  static Color _onBg(String? hex) {
    final mid = Color.lerp(_bgLight(hex), _bgDark(hex), 0.5)!;
    return mid.computeLuminance() > 0.45
        ? const Color(0xFF1C1C2E)
        : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final lang = provider.settings.language;
        final hex = provider.selectedColorHex;
        final onBg = _onBg(hex);

        return Scaffold(
          extendBodyBehindAppBar: true,
          extendBody: true,
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            title: Text(
              tr(lang, 'appTitle'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: onBg,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Center(
                  child: _NfcStatusDot(available: _nfcChecked && _nfcAvailable),
                ),
              ),
              IconButton(
                icon: Icon(Icons.settings_rounded, color: onBg),
                onPressed: () => _openSettings(context),
                tooltip: tr(lang, 'setupTitle'),
              ),
            ],
          ),
          body: Stack(
            children: [
              // Full-screen animated gradient — always fills the whole window
              AnimatedContainer(
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeInOut,
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_bgLight(hex), _bgDark(hex)],
                  ),
                ),
              ),
              // Scrollable content on top of the gradient
              SafeArea(
                bottom: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 8, 16, 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // NFC unavailable warning
                      if (_nfcChecked && !_nfcAvailable)
                        _WarningBanner(message: tr(lang, 'nfcNotAvailable')),
                      // Manufacturer selector (optional)
                      if (provider.settings.useManufacturer)
                        _GlassCard(
                          title: tr(lang, 'manufacturerLabel'),
                          child: _ManufacturerDropdown(lang: lang),
                        ),
                      // Material selector
                      _GlassCard(
                        title: tr(lang, 'materialLabel'),
                        child: _MaterialDropdown(lang: lang),
                      ),
                      // Color selector
                      _GlassCard(
                        title: tr(lang, 'colorLabel'),
                        child: ColorGridWidget(
                          colors: kDefaultColors,
                          selectedHex: provider.selectedColorHex,
                          language: lang,
                          onColorSelected: (h) => provider.selectColor(h),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Write button
                      _ActionButton(
                        label: tr(lang, 'writeBtn'),
                        color: const Color(0xFF4CAF50),
                        onPressed: provider.isBusy
                            ? null
                            : () => _writeTag(context, provider, lang),
                      ),
                      const SizedBox(height: 10),
                      // Read button
                      _ActionButton(
                        label: tr(lang, 'readBtn'),
                        color: const Color(0xFF2196F3),
                        onPressed: provider.isBusy
                            ? null
                            : () => _readTag(context, provider, lang),
                      ),
                      const SizedBox(height: 10),
                      // Auto-detect toggle
                      Center(child: _AutoDetectButton(lang: lang)),
                      const SizedBox(height: 16),
                      // Loading indicator
                      if (provider.isBusy)
                        Center(
                          child: Column(
                            children: [
                              const CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF667eea),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                tr(lang, 'loadingText'),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      // Status message
                      if (!provider.isBusy && provider.statusMessageKey != null)
                        _StatusMessage(lang: lang),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  Future<void> _writeTag(
      BuildContext context, AppProvider provider, String lang) async {
    // Validate selections
    if (provider.selectedMaterialCode == null) {
      provider.setStatus(
          messageKey: 'selectMaterialError', isError: true);
      return;
    }
    if (provider.settings.useManufacturer &&
        provider.selectedManufacturerCode == null) {
      provider.setStatus(
          messageKey: 'selectManufacturerError', isError: true);
      return;
    }
    if (provider.selectedColorHex == null) {
      provider.setStatus(messageKey: 'selectColorError', isError: true);
      return;
    }

    final colorCode =
        kDefaultColors[provider.selectedColorHex!] ?? 0;
    final mfgCode =
        provider.settings.useManufacturer ? (provider.selectedManufacturerCode ?? kDefaultManufacturerCode) : kDefaultManufacturerCode;

    provider.setBusy(true);
    provider.clearStatus();

    // Show a bottom sheet telling the user to scan
    if (context.mounted) {
      _showScanSheet(context, lang);
    }

    try {
      await NfcService.instance.writeTag(
        materialCode: provider.selectedMaterialCode!,
        colorCode: colorCode,
        manufacturerCode: mfgCode,
      );
      if (context.mounted) Navigator.of(context).pop(); // close sheet
      provider.setStatus(messageKey: 'writeSuccess', isSuccess: true);
    } on NfcException catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      provider.setStatus(
        messageKey: e.messageKey,
        details: e.details,
        isError: true,
      );
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      provider.setStatus(
        messageKey: 'unknownError',
        details: e.toString(),
        isError: true,
      );
    } finally {
      provider.setBusy(false);
    }
  }

  Future<void> _readTag(
      BuildContext context, AppProvider provider, String lang) async {
    provider.setBusy(true);
    provider.clearStatus();

    if (context.mounted) {
      _showScanSheet(context, lang);
    }

    try {
      final tagData = await NfcService.instance.readTag();
      if (context.mounted) Navigator.of(context).pop(); // close sheet
      provider.setLastReadTagData(tagData);
      provider.setStatus(messageKey: 'readSuccess', isSuccess: true);
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (_) => TagInfoDialog(
            tagData: tagData,
            materials: provider.materials,
            manufacturers: provider.manufacturers,
            language: lang,
          ),
        );
      }
    } on NfcException catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      provider.setStatus(
        messageKey: e.messageKey,
        details: e.details,
        isError: true,
      );
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      provider.setStatus(
        messageKey: 'unknownError',
        details: e.toString(),
        isError: true,
      );
    } finally {
      provider.setBusy(false);
    }
  }

  /// Shows a bottom sheet instructing the user to hold a tag to the device.
  void _showScanSheet(BuildContext context, String lang) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScanBottomSheet(lang: lang),
    ).then((_) {
      // If the sheet was dismissed by the user, cancel any active NFC session
      final provider = context.read<AppProvider>();
      if (provider.isBusy) {
        NfcService.instance.cancelSession();
        provider.setBusy(false);
        provider.setStatus(messageKey: 'nfcSessionCancelled');
      }
    });
  }
}

// ─── Supporting widgets ────────────────────────────────────────────────────

const Color _kSuccessGreen = Color(0xFF28a745);
const Color _kDangerRed = Color(0xFFdc3545);

class _NfcStatusDot extends StatelessWidget {
  final bool available;
  const _NfcStatusDot({required this.available});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: available ? _kSuccessGreen : _kDangerRed,
        boxShadow: available
            ? [
                BoxShadow(
                  color: _kSuccessGreen.withOpacity(0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  final String message;
  const _WarningBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD54F).withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFF59E0B), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF92400E), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _GlassCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF8A8FA8),
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _MaterialDropdown extends StatelessWidget {
  final String lang;
  const _MaterialDropdown({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final sortedEntries = provider.materials.entries.toList()
          ..sort((a, b) => a.value.compareTo(b.value));

        return DropdownButtonFormField<int>(
          value: provider.selectedMaterialCode,
          isExpanded: true,
          decoration: _inputDecoration(),
          hint: Text(tr(lang, 'materialPlaceholder')),
          items: [
            ...sortedEntries.map(
              (e) => DropdownMenuItem(
                value: e.key,
                child: Text('${e.value}  (${e.key})'),
              ),
            ),
          ],
          onChanged: (val) => provider.selectMaterial(val),
        );
      },
    );
  }
}

class _ManufacturerDropdown extends StatelessWidget {
  final String lang;
  const _ManufacturerDropdown({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final sortedEntries = provider.manufacturers.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));

        return DropdownButtonFormField<int>(
          value: provider.selectedManufacturerCode,
          isExpanded: true,
          decoration: _inputDecoration(),
          hint: Text(tr(lang, 'manufacturerPlaceholder')),
          items: sortedEntries
              .map(
                (e) => DropdownMenuItem(
                  value: e.key,
                  child: Text('${e.value}  (${e.key})'),
                ),
              )
              .toList(),
          onChanged: (val) => provider.selectManufacturer(val),
        );
      },
    );
  }
}

InputDecoration _inputDecoration() {
  return InputDecoration(
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
    ),
    filled: true,
    fillColor: Colors.white,
  );
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.label,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[300],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: onPressed != null ? 3 : 0,
          shadowColor: color.withOpacity(0.45),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        child: Text(label.toUpperCase()),
      ),
    );
  }
}

class _AutoDetectButton extends StatelessWidget {
  final String lang;
  const _AutoDetectButton({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final active = provider.autoReadActive;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: active
                ? _kSuccessGreen.withOpacity(0.12)
                : Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: active
                  ? _kSuccessGreen.withOpacity(0.4)
                  : Colors.grey.withOpacity(0.3),
            ),
          ),
          child: TextButton.icon(
            onPressed: () => _toggleAutoRead(context, provider, lang),
            icon: Icon(
              active ? Icons.sensors : Icons.sensors_off,
              size: 18,
              color: active ? _kSuccessGreen : Colors.grey[600],
            ),
            label: Text(
              tr(lang, 'auto_detect'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? _kSuccessGreen : Colors.grey[700],
              ),
            ),
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleAutoRead(
      BuildContext context, AppProvider provider, String lang) async {
    final newState = !provider.autoReadActive;
    provider.setAutoReadActive(newState);

    if (newState) {
      // Start continuous read loop
      provider.clearStatus();
      _autoReadLoop(context, provider, lang);
    } else {
      await NfcService.instance.cancelSession();
      provider.clearStatus();
    }
  }

  Future<void> _autoReadLoop(
      BuildContext context, AppProvider provider, String lang) async {
    while (provider.autoReadActive && context.mounted) {
      try {
        provider.setBusy(true);
        final tagData = await NfcService.instance.readTag();
        if (!context.mounted) break;
        provider.setBusy(false);
        provider.setLastReadTagData(tagData);
        provider.setStatus(messageKey: 'readSuccess', isSuccess: true);
        if (context.mounted) {
          await showDialog(
            context: context,
            builder: (_) => TagInfoDialog(
              tagData: tagData,
              materials: provider.materials,
              manufacturers: provider.manufacturers,
              language: lang,
            ),
          );
        }
      } on NfcException catch (e) {
        if (!context.mounted) break;
        provider.setBusy(false);
        if (e.messageKey == 'nfcSessionCancelled' ||
            !provider.autoReadActive) break;
        provider.setStatus(messageKey: e.messageKey, isError: true);
        await Future<void>.delayed(const Duration(seconds: 1));
      } catch (_) {
        if (!context.mounted) break;
        provider.setBusy(false);
        if (!provider.autoReadActive) break;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    if (context.mounted) {
      provider.setBusy(false);
      provider.setAutoReadActive(false);
    }
  }
}

class _StatusMessage extends StatelessWidget {
  final String lang;
  const _StatusMessage({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        if (provider.statusMessageKey == null) return const SizedBox.shrink();
        final key = provider.statusMessageKey!;
        final text = tr(lang, key);
        final details = provider.statusDetails;
        final full = details != null ? '$text $details' : text;
        final isError = provider.statusIsError;
        final isSuccess = provider.statusIsSuccess;

        final bgColor = isError
            ? const Color(0xFFFEE2E2)
            : isSuccess
                ? const Color(0xFFDCFCE7)
                : const Color(0xFFDBEAFE);
        final borderColor = isError
            ? const Color(0xFFFCA5A5)
            : isSuccess
                ? const Color(0xFF86EFAC)
                : const Color(0xFF93C5FD);
        final textColor = isError
            ? const Color(0xFF991B1B)
            : isSuccess
                ? const Color(0xFF166534)
                : const Color(0xFF1E40AF);
        final icon = isError
            ? Icons.error_outline_rounded
            : isSuccess
                ? Icons.check_circle_outline_rounded
                : Icons.info_outline_rounded;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: textColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  full,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ScanBottomSheet extends StatelessWidget {
  final String lang;
  const _ScanBottomSheet({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.nfc_rounded, size: 44, color: Color(0xFF667eea)),
          ),
          const SizedBox(height: 18),
          Text(
            tr(lang, 'scanTagPrompt'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C2E),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                foregroundColor: const Color(0xFF667eea),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              child: Text(tr(lang, 'cancelWarningBtn')),
            ),
          ),
        ],
      ),
    );
  }
}
