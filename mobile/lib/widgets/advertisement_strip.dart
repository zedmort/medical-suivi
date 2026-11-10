import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_texts.dart';
import '../services/api_service.dart';
import '../theme/medi_go_theme.dart';

class AdvertisementStrip extends StatefulWidget {
  const AdvertisementStrip({super.key, required this.placement});

  final String placement;

  @override
  State<AdvertisementStrip> createState() => _AdvertisementStripState();
}

class _AdvertisementStripState extends State<AdvertisementStrip> {
  Map<String, dynamic>? _advertisement;

  @override
  void initState() {
    super.initState();
    _loadAdvertisement();
  }

  Future<void> _loadAdvertisement() async {
    try {
      final response = await ApiService.get(
        '/advertisements?placement=${widget.placement}',
      );
      final advertisements = List<Map<String, dynamic>>.from(
        response['advertisements'] ?? [],
      );
      if (!mounted || advertisements.isEmpty) return;
      setState(() => _advertisement = advertisements.first);
      await ApiService.post(
        '/advertisements/${_advertisement!['id']}/impression',
        const {},
      );
    } on ApiException catch (error) {
      debugPrint('Advertisement load/tracking failed: ${error.message}');
    } catch (error) {
      debugPrint('Advertisement load/tracking failed: $error');
    }
  }

  Future<void> _openAdvertisement() async {
    final advertisement = _advertisement;
    if (advertisement == null) return;
    final id = advertisement['id'];
    final url = advertisement['destination_url']?.toString() ?? '';
    try {
      await ApiService.post('/advertisements/$id/click', const {});
      if (url.isNotEmpty) {
        final launched = await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppTexts.of(context, 'ad_link_unavailable')),
            ),
          );
        }
      }
    } on ApiException catch (error) {
      debugPrint('Advertisement click tracking failed: ${error.message}');
    } catch (error) {
      debugPrint('Advertisement click failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final advertisement = _advertisement;
    if (advertisement == null) return const SizedBox.shrink();
    final imageUrl = advertisement['image_url']?.toString();
    return SafeArea(
      top: false,
      child: Material(
        color: MediGoTheme.cardSurface,
        child: InkWell(
          onTap: _openAdvertisement,
          child: Container(
            height: 82,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: MediGoTheme.borderSoft)),
            ),
            child: Row(
              children: [
                if (imageUrl != null && imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      ApiService.absoluteFileUrl(imageUrl),
                      width: 76,
                      height: 62,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(
                        width: 76,
                        height: 62,
                        child: Icon(Icons.campaign_outlined),
                      ),
                    ),
                  )
                else
                  const SizedBox(
                    width: 52,
                    child: Icon(
                      Icons.campaign_outlined,
                      color: MediGoTheme.primaryBlue,
                    ),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        AppTexts.of(context, 'advertisement_label'),
                        style: const TextStyle(
                          color: MediGoTheme.primaryBlue,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        advertisement['title']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: MediGoTheme.darkNavy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if ((advertisement['description'] ?? '')
                          .toString()
                          .isNotEmpty)
                        Text(
                          advertisement['description'].toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: MediGoTheme.secondaryGrey,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                if ((advertisement['destination_url'] ?? '')
                    .toString()
                    .isNotEmpty)
                  const Icon(Icons.open_in_new, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
