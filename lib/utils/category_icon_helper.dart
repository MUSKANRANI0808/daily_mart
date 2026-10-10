import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CategoryPresetItem {
  final String key;
  final String label;
  final IconData icon;

  const CategoryPresetItem({
    required this.key,
    required this.label,
    required this.icon,
  });
}

class CategoryIconHelper {
  static const List<CategoryPresetItem> presets = [
    CategoryPresetItem(key: 'beauty', label: 'Beauty', icon: Icons.face_retouching_natural_outlined),
    CategoryPresetItem(key: 'gifting', label: 'Gifting', icon: Icons.card_giftcard_outlined),
    CategoryPresetItem(key: 'decor', label: 'Decor', icon: Icons.light_outlined),
    CategoryPresetItem(key: 'kids', label: 'Kids', icon: Icons.child_care_outlined),
    CategoryPresetItem(key: 'imported', label: 'Imported', icon: Icons.shopping_cart_outlined),
    CategoryPresetItem(key: 'grocery', label: 'Grocery', icon: Icons.shopping_basket_outlined),
    CategoryPresetItem(key: 'snacks', label: 'Snacks', icon: Icons.cookie_outlined),
    CategoryPresetItem(key: 'dairy', label: 'Dairy', icon: Icons.water_drop_outlined),
    CategoryPresetItem(key: 'oil_spices', label: 'Oil & Spices', icon: Icons.soup_kitchen_outlined),
    CategoryPresetItem(key: 'fruits_veg', label: 'Fruits & Veg', icon: Icons.eco_outlined),
    CategoryPresetItem(key: 'home_care', label: 'Home Care', icon: Icons.cleaning_services_outlined),
    CategoryPresetItem(key: 'drinks', label: 'Cold Drinks', icon: Icons.local_drink_outlined),
    CategoryPresetItem(key: 'bakery', label: 'Bakery', icon: Icons.bakery_dining_outlined),
    CategoryPresetItem(key: 'sweets', label: 'Sweets', icon: Icons.cake_outlined),
    CategoryPresetItem(key: 'meat_fish', label: 'Meat & Fish', icon: Icons.set_meal_outlined),
    CategoryPresetItem(key: 'tea_coffee', label: 'Tea & Coffee', icon: Icons.emoji_food_beverage_outlined),
    CategoryPresetItem(key: 'instant_food', label: 'Instant Food', icon: Icons.fastfood_outlined),
    CategoryPresetItem(key: 'pharma', label: 'Pharma', icon: Icons.medication_outlined),
    CategoryPresetItem(key: 'personal_care', label: 'Personal Care', icon: Icons.soap_outlined),
    CategoryPresetItem(key: 'baby_care', label: 'Baby Care', icon: Icons.baby_changing_station_outlined),
    CategoryPresetItem(key: 'pet_care', label: 'Pet Care', icon: Icons.pets_outlined),
    CategoryPresetItem(key: 'fashion', label: 'Fashion', icon: Icons.checkroom_outlined),
    CategoryPresetItem(key: 'electronics', label: 'Electronics', icon: Icons.devices_outlined),
    CategoryPresetItem(key: 'stationery', label: 'Stationery', icon: Icons.menu_book_outlined),
    CategoryPresetItem(key: 'offers', label: 'Offers', icon: Icons.local_offer_outlined),
    CategoryPresetItem(key: 'special', label: 'Special', icon: Icons.star_outline_rounded),
    CategoryPresetItem(key: 'frozen', label: 'Frozen Food', icon: Icons.ac_unit_outlined),
    CategoryPresetItem(key: 'fitness', label: 'Health & Fit', icon: Icons.fitness_center_outlined),
  ];

  static IconData getOutlineIcon(String catName, [String? iconUrl]) {
    final cleanIcon = (iconUrl ?? '').trim();
    if (cleanIcon.startsWith('preset:')) {
      final key = cleanIcon.replaceFirst('preset:', '').trim().toLowerCase();
      for (final p in presets) {
        if (p.key.toLowerCase() == key) return p.icon;
      }
    }

    final s = catName.toLowerCase().trim();
    if (s.contains('beauty') || s.contains('cosmetic') || s.contains('makeup') || s.contains('lipstick') || s.contains('cream') || s.contains('face')) {
      return Icons.face_retouching_natural_outlined;
    }
    if (s.contains('gift') || s.contains('box') || s.contains('hamper')) {
      return Icons.card_giftcard_outlined;
    }
    if (s.contains('decor') || s.contains('home decor') || s.contains('lamp') || s.contains('furnish') || s.contains('light')) {
      return Icons.light_outlined;
    }
    if (s.contains('kid') || s.contains('baby') || s.contains('toy') || s.contains('child') || s.contains('diaper')) {
      return Icons.child_care_outlined;
    }
    if (s.contains('import') || s.contains('special') || s.contains('global')) {
      return Icons.shopping_cart_outlined;
    }
    if (s.contains('snack') || s.contains('chip') || s.contains('biscuit') || s.contains('cookie') || s.contains('namkeen') || s.contains('munch') || s.contains('puff')) {
      return Icons.cookie_outlined;
    }
    if (s.contains('oil') || s.contains('ghee') || s.contains('masala') || s.contains('spice') || s.contains('kitchen')) {
      return Icons.soup_kitchen_outlined;
    }
    if (s.contains('dairy') || s.contains('milk') || s.contains('paneer') || s.contains('cheese') || s.contains('butter') || s.contains('curd') || s.contains('dahi')) {
      return Icons.water_drop_outlined;
    }
    if (s.contains('fruit') || s.contains('veg') || s.contains('sabzi') || s.contains('kisan') || s.contains('organic')) {
      return Icons.eco_outlined;
    }
    if (s.contains('clean') || s.contains('wash') || s.contains('detergent') || s.contains('surf') || s.contains('care') || s.contains('home care')) {
      return Icons.cleaning_services_outlined;
    }
    if (s.contains('drink') || s.contains('beverage') || s.contains('juice') || s.contains('soda') || s.contains('cola') || s.contains('cold')) {
      return Icons.local_drink_outlined;
    }
    if (s.contains('tea') || s.contains('chai') || s.contains('coffee')) {
      return Icons.emoji_food_beverage_outlined;
    }
    if (s.contains('sweet') || s.contains('mithai') || s.contains('choco') || s.contains('candy') || s.contains('cake') || s.contains('dessert')) {
      return Icons.cake_outlined;
    }
    if (s.contains('bread') || s.contains('bakery') || s.contains('toast') || s.contains('bun') || s.contains('roti')) {
      return Icons.bakery_dining_outlined;
    }
    if (s.contains('meat') || s.contains('chicken') || s.contains('fish') || s.contains('egg') || s.contains('mutton')) {
      return Icons.set_meal_outlined;
    }
    if (s.contains('med') || s.contains('pharma') || s.contains('health') || s.contains('tablet') || s.contains('doctor')) {
      return Icons.medication_outlined;
    }
    if (s.contains('cloth') || s.contains('fashion') || s.contains('wear') || s.contains('shirt') || s.contains('dress')) {
      return Icons.checkroom_outlined;
    }
    if (s.contains('phone') || s.contains('electr') || s.contains('gadget') || s.contains('device') || s.contains('mobile')) {
      return Icons.devices_outlined;
    }
    if (s.contains('pet') || s.contains('dog') || s.contains('cat')) {
      return Icons.pets_outlined;
    }
    if (s.contains('book') || s.contains('stationery') || s.contains('pen') || s.contains('pencil')) {
      return Icons.menu_book_outlined;
    }
    if (s.contains('offer') || s.contains('discount') || s.contains('deal') || s.contains('sale')) {
      return Icons.local_offer_outlined;
    }

    return Icons.shopping_basket_outlined;
  }

  static Widget buildHeaderCategoryIcon(
    String iconStr,
    String catName, {
    double size = 24,
    Color color = Colors.white,
  }) {
    final clean = iconStr.trim();
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return Image.network(
        clean,
        width: size,
        height: size,
        fit: BoxFit.contain,
        color: color,
        colorBlendMode: BlendMode.srcIn,
        errorBuilder: (_, __, ___) => Icon(getOutlineIcon(catName, clean), color: color, size: size),
      );
    }

    if (clean.startsWith('data:image')) {
      try {
        final base64Part = clean.split(',').last.trim();
        return Image.memory(
          base64Decode(base64Part),
          width: size,
          height: size,
          fit: BoxFit.contain,
          color: color,
          colorBlendMode: BlendMode.srcIn,
          errorBuilder: (_, __, ___) => Icon(getOutlineIcon(catName, clean), color: color, size: size),
        );
      } catch (_) {}
    }

    if (clean.isNotEmpty && clean != '🏷️' && !clean.startsWith('preset:') && clean.length <= 4) {
      return Text(clean, style: TextStyle(fontSize: size * 0.9));
    }

    return Icon(getOutlineIcon(catName, clean), color: color, size: size);
  }

  static Future<String?> showIconPickerDialog(BuildContext context, {String currentIcon = ''}) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 18,
            right: 18,
            top: 14,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xFFFEF2F2),
                    child: Icon(Icons.stars_rounded, color: Color(0xFFDC2626), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Category Header Icon 🏷️',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Shown under search bar in white outline style',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 22),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Upload custom icon from gallery button
              InkWell(
                onTap: () async {
                  try {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 300);
                    if (picked != null) {
                      final bytes = await picked.readAsBytes();
                      final base64Str = 'data:image/png;base64,${base64Encode(bytes)}';
                      Navigator.pop(ctx, base64Str);
                    }
                  } catch (_) {}
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.file_upload_outlined, color: Color(0xFF0284C7), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Upload Custom Icon from Gallery (PNG / Vector)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0284C7)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              const Text(
                'Or choose from popular outline presets:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 10),

              // Grid of presets
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.42),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 0.95,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: presets.length,
                  itemBuilder: (context, idx) {
                    final p = presets[idx];
                    final isSel = currentIcon == 'preset:${p.key}';
                    return InkWell(
                      onTap: () => Navigator.pop(ctx, 'preset:${p.key}'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFFDC2626) : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSel ? Colors.amber : const Color(0xFF334155),
                            width: isSel ? 2 : 1,
                          ),
                          boxShadow: isSel
                              ? [BoxShadow(color: const Color(0xFFDC2626).withValues(alpha: 0.4), blurRadius: 6)]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(p.icon, color: Colors.white, size: 26),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: Text(
                                p.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              if (currentIcon.isNotEmpty) ...[
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () => Navigator.pop(ctx, ''),
                  icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF64748B)),
                  label: const Text('Reset to Smart Name Auto-Detect', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
