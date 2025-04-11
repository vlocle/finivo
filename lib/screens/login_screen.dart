import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
    setState(() => _isLoading = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đăng nhập bằng Google thành công')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đăng nhập bằng Google thành công')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _buttonScaleAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.95), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 0.95, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Khu vực phía trên: Hình ảnh minh họa (chiếm hơn 50% chiều cao) với bo góc
          Expanded(
            flex: 7, // Chiếm khoảng 60% chiều cao màn hình
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(50), // Bo góc dưới bên trái
                bottomRight: Radius.circular(50), // Bo góc dưới bên phải
              ),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/finance_illustration.jpg'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Khu vực phía dưới: Nền trắng, chứa nút đăng nhập
          Expanded(
            flex: 3, // Chiếm khoảng 40% chiều cao màn hình
            child: Container(
              color: Colors.white, // Nền trắng theo yêu cầu
              child: SafeArea(
                top: false, // Chỉ áp dụng SafeArea cho phần dưới
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start, // Đẩy nút lên trên cùng của khu vực trắng
                  children: [
                    // Nút đăng nhập với Google (giữ thiết kế từ mã gốc)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0), // Giảm vertical để nút sát khu vực hình ảnh
                      child: ScaleTransition(
                        scale: _buttonScaleAnimation,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF42A5F5), // Màu nền xanh từ mã gốc
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          onPressed: _isLoading
                              ? null
                              : () {
                            _controller.reset();
                            _controller.forward();
                            _signInWithGoogle(context);
                          },
                          icon: _isLoading
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                              : Image.asset(
                            'assets/google_logo.png',
                            height: 20,
                          ),
                          label: const Text(
                            "Đăng nhập với Google",
                            style: TextStyle(color: Colors.white, fontSize: 16), // Chữ trắng từ mã gốc
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