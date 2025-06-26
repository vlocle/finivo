import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import '/screens/firestore_service.dart';
import '/screens/device_utils.dart';

import '../state/app_state.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _buttonScaleAnimation;
  bool _isLoading = false;

  Future<void> _signInWithGoogle(BuildContext context) async {
    // Nắm bắt context hiện tại để sử dụng an toàn trong các hàm bất đồng bộ
    final currentContext = context;
    if (!mounted) return; // Kiểm tra mounted ở đầu
    setState(() => _isLoading = true);

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn(); // [cite: 334]

      if (googleUser == null) {
        if (mounted) setState(() => _isLoading = false); // [cite: 335]
        return; // [cite: 335]
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication; // [cite: 336]
      final credential = GoogleAuthProvider.credential( // [cite: 336]
        accessToken: googleAuth.accessToken, // [cite: 337]
        idToken: googleAuth.idToken, // [cite: 337]
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        final deviceId = await getDeviceId();
        // GỌI HÀM LƯU THÔNG TIN VÀO FIRESTORE
        await FirestoreService().saveUserInfoToFirestore(user, deviceId);

        if (mounted) {
          //Provider.of<AppState>(context, listen: false).setUserId(user.uid);
          //Navigator.pushReplacement(
          //  context,
          //  MaterialPageRoute(builder: (context) => MainScreen()),
          //);
        }
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(content: Text('Đăng nhập bằng Google thất bại: $e')), // Sửa thông báo lỗi [cite: 339, 340]
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false); // [cite: 341]
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController( // [cite: 343]
      duration: const Duration(milliseconds: 700), // [cite: 343]
      vsync: this, // [cite: 343]
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0) // [cite: 344]
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn)); // [cite: 344]
    _buttonScaleAnimation = TweenSequence([ // [cite: 345]
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.95), weight: 50), // [cite: 345]
      TweenSequenceItem(tween: Tween<double>(begin: 0.95, end: 1.0), weight: 50), // [cite: 345]
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)); // [cite: 345]
    _controller.forward(); // [cite: 346]
  }

  @override
  void dispose() {
    _controller.dispose(); // [cite: 346]
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            flex: 7, // [cite: 347]
            child: ClipRRect(
              borderRadius: const BorderRadius.only( // [cite: 348]
                bottomLeft: Radius.circular(50), // [cite: 348]
                bottomRight: Radius.circular(50), // [cite: 348]
              ),
              child: FadeTransition(
                opacity: _fadeAnimation, // [cite: 349]
                child: Container(
                  width: double.infinity, // [cite: 349]
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/finance_illustration.jpg'), // [cite: 350]
                      fit: BoxFit.cover, // [cite: 350]
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3, // [cite: 351]
            child: Container(
              color: Colors.white, // [cite: 351, 352]
              child: SafeArea(
                top: false, // [cite: 352]
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start, // [cite: 352]
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0), // [cite: 353]
                      child: ScaleTransition(
                        scale: _buttonScaleAnimation, // [cite: 354]
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom( // [cite: 355]
                            backgroundColor: const Color(0xFF42A5F5), // [cite: 355]
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12), // [cite: 355]
                            ),
                            minimumSize: const Size(double.infinity, 50), // [cite: 356, 357]
                          ),
                          onPressed: _isLoading // [cite: 357]
                              ? null // [cite: 358]
                              : () {
                            _controller.reset(); // [cite: 358]
                            _controller.forward(); // [cite: 359]
                            _signInWithGoogle(context); // [cite: 359]
                          },
                          icon: _isLoading // [cite: 359]
                              ? const SizedBox( // [cite: 360]
                            width: 20, // [cite: 360]
                            height: 20, // [cite: 360]
                            child: CircularProgressIndicator( // [cite: 360]
                              strokeWidth: 2, // [cite: 361]
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white), // [cite: 361]
                            ),
                          )
                              : Image.asset( // [cite: 362]
                            'assets/google_logo.png', // [cite: 362]
                            height: 20, // [cite: 362]
                          ),
                          label: const Text( // [cite: 363]
                            "Đăng nhập với Google", // [cite: 363]
                            style: TextStyle(color: Colors.white, fontSize: 16), // [cite: 364]
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}