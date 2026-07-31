import 'package:flutter/material.dart';
import '../../models/user_model.dart';

class SellerComplaintScreen extends StatefulWidget {
  final UserModel seller;

  const SellerComplaintScreen({super.key, required this.seller});

  @override
  State<SellerComplaintScreen> createState() => _SellerComplaintScreenState();
}

class _SellerComplaintScreenState extends State<SellerComplaintScreen> {
  final List<Map<String, dynamic>> _complaints = [
    {
      'ticket': 'TKT-9012',
      'subject': 'Delay in order delivery',
      'customer': '+91 7480976513',
      'status': 'Open',
      'statusColor': const Color(0xFFEF4444),
      'date': '26/07/2026',
      'details': 'Order was supposed to arrive by 10 AM, but seller has not responded.',
    },
    {
      'ticket': 'TKT-8840',
      'subject': 'Wrong item delivered',
      'customer': '+91 8128859990',
      'status': 'Resolved',
      'statusColor': const Color(0xFF10B981),
      'date': '22/07/2026',
      'details': 'Received tea instead of coffee. Refund processed by seller.',
    },
  ];

  void _resolveComplaint(int idx) {
    setState(() {
      _complaints[idx]['status'] = 'Resolved';
      _complaints[idx]['statusColor'] = const Color(0xFF10B981);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Complaint marked as Resolved! Customer notified.')),
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
            Icon(Icons.report_problem_rounded, color: Color(0xFF8B5CF6)),
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
            const Text(
              'Assigned Complaints',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _complaints.length,
              itemBuilder: (ctx, idx) {
                final comp = _complaints[idx];
                final isOpen = comp['status'] == 'Open';

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
                            const Icon(Icons.person_rounded, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text('Customer: ${comp['customer']}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                            const Spacer(),
                            Text(comp['date'], style: const TextStyle(color: Colors.black45, fontSize: 11)),
                          ],
                        ),
                        if (isOpen) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8B5CF6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
                              label: const Text('Mark Issue as Resolved', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              onPressed: () => _resolveComplaint(idx),
                            ),
                          ),
                        ],
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
