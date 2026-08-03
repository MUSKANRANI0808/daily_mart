import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import 'customer_main_nav_screen.dart';

class SearchSellerScreen extends StatefulWidget {
  final UserModel customer;
  const SearchSellerScreen({super.key, required this.customer});

  @override
  State<SearchSellerScreen> createState() => _SearchSellerScreenState();
}

class _SearchSellerScreenState extends State<SearchSellerScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  void _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    final results = await AuthService.searchSellersByMobile(query);

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Sleek Light Grey Slate Background
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A), // Dark Black Header Contrast
        elevation: 1,
        title: const Text('Find Seller by Mobile / Location', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search Bar Container
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: Color(0xFF10B981), size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      keyboardType: TextInputType.text, // Allows letters (location/name) and numbers (mobile)
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.w600),
                      decoration: const InputDecoration(
                        hintText: 'Enter Mobile Number or Location...',
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _performSearch(),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _performSearch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Search', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Results List
            if (_isSearching)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFF10B981))))
            else if (_hasSearched && _searchResults.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Column(
                  children: [
                    Icon(Icons.search_off_rounded, size: 48, color: Colors.grey),
                    SizedBox(height: 10),
                    Text(
                      'No seller found matching your mobile number or location search.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black87, fontSize: 14),
                    ),
                  ],
                ),
              )
            else if (_searchResults.isNotEmpty)
              Expanded(
                child: ListView.separated(
                  itemCount: _searchResults.length,
                  separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
                  itemBuilder: (ctx, idx) {
                    final seller = _searchResults[idx];
                    final name = seller['name'] ?? 'Seller Store';
                    final username = seller['username'] ?? '';
                    final mobile = seller['mobile'] ?? '';
                    final location = (seller['location'] ?? seller['seller_location'] ?? '').toString();

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFF10B981),
                          child: Icon(Icons.storefront_rounded, color: Colors.white),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Mobile: +91 $mobile  •  ID: @$username',
                              style: const TextStyle(color: Colors.black54, fontSize: 12),
                            ),
                            if (location.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.location_on_rounded, size: 13, color: Color(0xFF10B981)),
                                  const SizedBox(width: 3),
                                  Text(
                                    location,
                                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                        trailing: ElevatedButton.icon(
                          onPressed: () async {
                            final String custMob = widget.customer.mobile ?? '';
                            await AuthService.unmarkDeletedSeller(
                              sellerUsername: username,
                              customerMobile: custMob,
                            );
                            await AuthService.saveLastSelectedSeller(
                              username: username,
                              name: name,
                              mobile: mobile.toString(),
                              customerMobile: custMob,
                            );
                            if (!context.mounted) return;
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CustomerMainNavScreen(customer: widget.customer),
                              ),
                              (route) => false,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          icon: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 16),
                          label: const Text('View Orders', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
