import 'package:flutter/material.dart';

class WithdrawScreen extends StatelessWidget {
  const WithdrawScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final primaryBlue = const Color(0xFF0000FF);
    final lightBlue = const Color(0xFFE6E6FF);
    final darkBlue = const Color(0xFF0000CC);

    return Scaffold(
      backgroundColor: Colors.grey[100],
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Balance Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [lightBlue, Colors.white],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Text(
                          "Available Balance",
                          style: TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "\$1,250.00",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              // Handle withdraw all
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryBlue.withOpacity(0.1),
                              foregroundColor: primaryBlue,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: primaryBlue, width: 1),
                              ),
                            ),
                            child: const Text(
                              "Withdraw All",
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // _buildSectionCard(
              //   title: "Withdrawal Amount",
              //   subtitle:
              //       "", // Empty subtitle to remove the minimum withdrawal text
              //   child: Column(
              //     children: [
              //       TextFormField(
              //         keyboardType: TextInputType.number,
              //         decoration: InputDecoration(
              //           hintText: '0.00',
              //           border: OutlineInputBorder(
              //             borderRadius: BorderRadius.circular(12),
              //             borderSide: BorderSide(color: primaryBlue),
              //           ),
              //           focusedBorder: OutlineInputBorder(
              //             borderRadius: BorderRadius.circular(12),
              //             borderSide: BorderSide(color: primaryBlue, width: 2),
              //           ),
              //           contentPadding: const EdgeInsets.symmetric(
              //             horizontal: 16,
              //             vertical: 14,
              //           ),
              //           prefixIcon: const Icon(Icons.attach_money),
              //           prefixIconColor: primaryBlue,
              //         ),
              //       ),
              //       const SizedBox(height: 12),
              //       Row(
              //         children: [
              //           _buildAmountChip("\$50", primaryBlue),
              //           const SizedBox(width: 8),
              //           _buildAmountChip("\$100", primaryBlue),
              //           const SizedBox(width: 8),
              //           _buildAmountChip("\$200", primaryBlue),
              //           const SizedBox(width: 8),
              //           _buildAmountChip("\$500", primaryBlue),
              //         ],
              //       ),
              //     ],
              //   ),
              //   primaryBlue: primaryBlue,
              //   lightBlue: lightBlue,
              // ),

              // const SizedBox(height: 20),
              _buildSectionCard(
                title: "BEP20 Wallet Address",
                subtitle: "Enter your BEP20 compatible wallet address",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'e.g. 0xAbc123...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: primaryBlue),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: primaryBlue, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange[700],
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "Double check your wallet address",
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Note: A 10% fee will be applied to all withdrawals. Network fees may apply.",
                      style: TextStyle(
                        color: darkBlue,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                primaryBlue: primaryBlue,
                lightBlue: lightBlue,
              ),

              const SizedBox(height: 20),

              // Fee Information Card
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: lightBlue.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryBlue.withOpacity(0.2)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Withdrawal Summary",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildFeeRow("Amount", "\$0.00"),
                        _buildFeeRow("Withdrawal Fee (10%)", "\$0.00"),
                        _buildFeeRow("Network Fee", "\$1.50"),
                        const Divider(height: 20),
                        _buildFeeRow(
                          "Total You'll Receive",
                          "\$0.00",
                          isTotal: true,
                          primaryBlue: primaryBlue,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(height: size.height * 0.05),
            ],
          ),
        ),
      ),

      // 🔹 Sticky Withdraw Button
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              // Handle withdrawal
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              shadowColor: primaryBlue.withOpacity(0.5),
              elevation: 5,
            ),
            child: const Text(
              "Withdraw Now",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  // 🔹 Reusable Card Section
  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
    required Color primaryBlue,
    required Color lightBlue,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryBlue.withOpacity(0.1)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryBlue,
                ),
              ),
              // Only show subtitle if it's not empty
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(color: Color(0xFF0000CC), fontSize: 13),
                ),
              ],
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }

  // 🔹 Amount Chip
  Widget _buildAmountChip(String amount, Color primaryBlue) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          // Handle amount selection
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: primaryBlue.withOpacity(0.3)),
          ),
          child: Text(
            amount,
            textAlign: TextAlign.center,
            style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }

  // 🔹 Fee Row
  Widget _buildFeeRow(
    String label,
    String value, {
    bool isTotal = false,
    Color? primaryBlue,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: isTotal ? primaryBlue : Colors.grey[700],
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
