import 'package:flutter/material.dart';
import '../../models/user_model.dart';

class CustomerComplaintScreen extends StatefulWidget {
  final UserModel customer;

  const CustomerComplaintScreen({super.key, required this.customer});

  @override
  State<CustomerComplaintScreen> createState() => _CustomerComplaintScreenState();
}

class _CustomerComplaintScreenState extends State<CustomerComplaintScreen> {
  final List<Map<String, dynamic>> _complaints = [
    {
      'ticket': 'TKT-9012',
      'subject': 'Delay in order delivery',
      'seller': 'Ram Traders',
      'status': 'Under Investigation',
      'statusColor': const Color(0xFFF59E0B),
      'date': '26/07/2026',
      'details': 'Order was supposed to arrive by 10 AM, but seller has not responded.',
    },
    {
      'ticket': 'TKT-8840',
      'subject': 'Wrong item delivered',
      'seller': 'Krishna General Store',
      'status': 'Resolved',
      'statusColor': const Color(0xFF10B981),
      'date': '22/07/2026',
      'details': 'Received tea instead of coffee. Refund processed by seller.',
    },
  ];

  void _showFileComplaintModal() {
    final sellerController = TextEditingController();
    final subjectController = TextEditingController();
    final detailsController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('File a Complaint', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: sellerController,
                  decoration: const InputDecoration(
                    labelText: 'Seller Name / Mobile',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subjectController,
                  decoration: const InputDecoration(
                    labelText: 'Complaint Subject',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: detailsController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Describe your issue in detail',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
              onPressed: () {
                if (subjectController.text.isNotEmpty && detailsController.text.isNotEmpty) {
                  setState(() {
                    _complaints.insert(0, {
                      'ticket': 'TKT-${9013 + _complaints.length}',
                      'subject': subjectController.text.trim(),
                      'seller': sellerController.text.trim().isEmpty ? 'General Support' : sellerController.text.trim(),
                      'status': 'Open & Pending',
                      'statusColor': const Color(0xFFEF4444),
                      'date': 'Just now',
                      'details': detailsController.text.trim(),
                    });
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Complaint registered successfully! Support team notified.')),
                  );
                }
              },
              child: const Text('Submit Complaint', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 1,
        title: const Row(
          children: [
            Icon(Icons.report_problem_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 10),
            Text('Customer Complaints', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Help Banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFFEF2F2),
                    radius: 22,
                    child: Icon(Icons.support_agent_rounded, color: Color(0xFFEF4444), size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Need Help or Facing Issues?',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Lodge a complaint for quick resolution by support.',
                          style: TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onPressed: _showFileComplaintModal,
                    child: const Text('+ File Issue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'My Registered Complaints',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _complaints.length,
              itemBuilder: (ctx, idx) {
                final comp = _complaints[idx];
                return Card(
                  elevation: 1.5,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              comp['ticket'],
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54, fontSize: 12),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (comp['statusColor'] as Color).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                comp['status'],
                                style: TextStyle(
                                  color: comp['statusColor'],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          comp['subject'],
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          comp['details'],
                          style: const TextStyle(color: Colors.black87, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.storefront_rounded, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text('Seller: ${comp['seller']}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                            const Spacer(),
                            Text(comp['date'], style: const TextStyle(color: Colors.black45, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
