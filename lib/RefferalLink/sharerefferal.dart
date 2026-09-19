import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class Sharinglink extends StatefulWidget {
  const Sharinglink({super.key});

  @override
  State<Sharinglink> createState() => _SharinglinkState();
}

class _SharinglinkState extends State<Sharinglink> {
  final String referralLink = "https://cashflowhub.com/ref/user123";

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.blue, size: w * 0.05),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Share Your Link',
          style: TextStyle(color: Colors.black, fontSize: w * 0.045),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: w * 0.05,
            vertical: h * 0.02,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Referral Link Title
              Text(
                'Your Referral Link',
                style: TextStyle(
                  fontSize: w * 0.035,
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: h * 0.01),

              // Referral Link Box
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: w * 0.03,
                  vertical: h * 0.015,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 6,
                      spreadRadius: 2,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        referralLink,
                        style: TextStyle(
                          fontSize: w * 0.035,
                          color: Colors.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.content_copy,
                        color: Colors.grey,
                        size: w * 0.05,
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: referralLink));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Link copied to clipboard'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: h * 0.02),

              // Copy Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: referralLink));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copied to clipboard')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromRGBO(41, 98, 255, 1),
                    padding: EdgeInsets.symmetric(vertical: h * 0.02),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Copy Link',
                    style: TextStyle(color: Colors.white, fontSize: w * 0.04),
                  ),
                ),
              ),
              SizedBox(height: h * 0.04),

              // Social Media Sharing
              Text(
                'Share via Social Media',
                style: TextStyle(
                  fontSize: w * 0.035,
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: h * 0.02),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSocialButton(
                    'assets/whatsapp.png',
                    'WhatsApp',
                    w,
                    () {},
                  ),
                  _buildSocialButton(
                    'assets/facebook.png',
                    'Facebook',
                    w,
                    () {},
                  ),
                  _buildSocialButton('assets/twitter.png', 'Twitter', w, () {}),
                ],
              ),
              SizedBox(height: h * 0.05),

              // QR Code Section
              Text(
                'QR Code',
                style: TextStyle(
                  fontSize: w * 0.04,
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: h * 0.02),

              Center(
                child: QrImageView(
                  data: referralLink,
                  version: QrVersions.auto,
                  size: w * 0.6, // responsive size
                  gapless: false,
                ),
              ),
              SizedBox(height: h * 0.02),

              Center(
                child: TextButton.icon(
                  onPressed: () {
                    // TODO: Implement QR download
                  },
                  icon: Icon(
                    Icons.download,
                    color: Colors.grey,
                    size: w * 0.05,
                  ),
                  label: Text(
                    'Download QR Code',
                    style: TextStyle(color: Colors.black, fontSize: w * 0.035),
                  ),
                ),
              ),
              SizedBox(height: h * 0.05),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton(
    String asset,
    String label,
    double w,
    VoidCallback onTap,
  ) {
    return Column(
      children: [
        IconButton(
          icon: Image.asset(asset, width: w * 0.12, height: w * 0.12),
          onPressed: onTap,
        ),
        Text(
          label,
          style: TextStyle(fontSize: w * 0.03, color: Colors.grey),
        ),
      ],
    );
  }
}
