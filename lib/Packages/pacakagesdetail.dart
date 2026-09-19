import 'package:flutter/material.dart';
import 'package:uktalhybird/Packages/purchase.dart';

class PackageDetailsScreen extends StatelessWidget {
  const PackageDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Center(
          child: Text(
            'Package Details',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 22,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: const Color(0xFF0000FF),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(w * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---- Package Info Card ----
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(w * 0.05),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Elite Platinum Package \$1,200/mo',
                      style: TextStyle(
                        fontSize: w * 0.055,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: h * 0.01),
                    Text(
                      '\$99 One-Time Activation',
                      style: TextStyle(
                        fontSize: w * 0.04,
                        color: Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: h * 0.02),

            // ---- Description Card ----
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 3,
              child: Padding(
                padding: EdgeInsets.all(w * 0.05),
                child: Text(
                  'Gain access to premium features, advanced analytics, and priority support. '
                  'This package is tailored for ambitious individuals aiming for rapid portfolio '
                  'expansion and significant passive income streams. Enjoy exclusive invites to '
                  'investor webinars and early access to new investment opportunities.',
                  style: TextStyle(fontSize: w * 0.04, height: 1.5),
                  textAlign: TextAlign.justify,
                ),
              ),
            ),

            SizedBox(height: h * 0.02),

            // ---- ROI Card ----
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 3,
              child: Padding(
                padding: EdgeInsets.all(w * 0.05),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ROI Options',
                      style: TextStyle(
                        fontSize: w * 0.05,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: h * 0.01),
                    _buildROIOption('7% 2X Return on Investment', w),
                    _buildROIOption(
                      '7% 3X Return on Investment (for holding longer than 12 months)',
                      w,
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: h * 0.02),

            // ---- Passive Income Card ----
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 3,
              child: Padding(
                padding: EdgeInsets.all(w * 0.05),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Passive Income Distribution',
                      style: TextStyle(
                        fontSize: w * 0.05,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: h * 0.02),
                    _buildIncomeDistributionTable(w),
                  ],
                ),
              ),
            ),

            SizedBox(height: h * 0.03),

            // ---- Buy Now Button ----
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const Purchase()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF0000FF),
                  padding: EdgeInsets.symmetric(vertical: h * 0.02),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Buy Now',
                  style: TextStyle(fontSize: w * 0.045, color: Colors.white),
                ),
              ),
            ),
            SizedBox(height: h * 0.02),
          ],
        ),
      ),
    );
  }

  // ROI Option Builder
  static Widget _buildROIOption(String text, double w) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: w * 0.015),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4.0, right: 8.0),
            child: Icon(Icons.circle, size: 8),
          ),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: w * 0.04)),
          ),
        ],
      ),
    );
  }

  // Passive Income Distribution Table
  static Widget _buildIncomeDistributionTable(double w) {
    return Table(
      columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(2)},
      children: [
        TableRow(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: w * 0.025),
              child: Text(
                'Monthly',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: w * 0.04,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: w * 0.025),
              child: Text(
                '(every 10th of the month)',
                style: TextStyle(fontSize: w * 0.038, color: Colors.grey[700]),
              ),
            ),
          ],
        ),
        TableRow(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: w * 0.025),
              child: Text(
                'Payouts',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: w * 0.04,
                ),
              ),
            ),
            const SizedBox(),
          ],
        ),
        TableRow(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: w * 0.03),
              child: Text(
                'Quarterly Bonus Distributions',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: w * 0.04,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: w * 0.03),
              child: Text(
                '(March, June, September, December)',
                style: TextStyle(fontSize: w * 0.038, color: Colors.grey[700]),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
