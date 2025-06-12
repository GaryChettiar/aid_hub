import 'package:finance_manager/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = new TextEditingController();
  final TextEditingController _passwordController = new TextEditingController();

  bool showPassword=false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      body: DecoratedBox(
        decoration: BoxDecoration(
          image: DecorationImage(image: AssetImage('login_bg.jpg'),fit: BoxFit.cover),
          
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xffadb5bd),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 48, color: Colors.black),
                  const SizedBox(height: 8),
                  Text(
                    "AOB Finance",
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Welcome back",
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                 
                 
                  const SizedBox(height: 20),
                  _inputField(label: "Email", hintText: "m@example.com",controller: _emailController),
                  const SizedBox(height: 16),
                  
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Row(
          children: [
            Text(
              "Password",
              style: GoogleFonts.inter(color: Colors.black),
            ),
            const Spacer(),
            
          ],
        ),
        const SizedBox(height: 6),
                      TextField(
                        controller: _passwordController,
                          obscureText: !showPassword,
                          style: const TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            suffixIcon: IconButton(onPressed: (){
                              setState(() {
                                showPassword=!showPassword;
                              });
                            }, icon:Icon(showPassword ?Icons.visibility:Icons.visibility_off) ),
                            hintText: "Password",
                            hintStyle: const TextStyle(color: Colors.black),
                            filled: true,
                            fillColor:  const Color.fromARGB(255, 241, 239, 239),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: Colors.grey.shade700),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: Colors.grey.shade700),
                            ),
                          ),
                        ),
                    ],
                  ),
                 
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                     onPressed: () async {
  final email = _emailController.text.trim();
  final password = _passwordController.text;

  if (email.isEmpty || password.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please enter both email and password')),
    );
    return;
  }

  try {
    // Attempt Firebase login
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Navigate to Dashboard if successful
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) =>  Dashboard()),
    );
  } on FirebaseAuthException catch (e) {
    // Show error messages for known errors
    String message = 'Login failed. Please try again.';
    if (e.code == 'user-not-found') {
      message = 'No user found for that email.';
    } else if (e.code == 'wrong-password') {
      message = 'Incorrect password.';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  } catch (e) {
    // Handle unknown errors
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
},
                      child: const Text("Login"),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Text.rich(
                  //   TextSpan(
                  //     text: "Don't have an account? ",
                  //     style: GoogleFonts.inter(color: Colors.black),
                  //     children: [
                  //       TextSpan(
                  //         text: "Sign up",
                  //         style: const TextStyle(
                  //           color: Colors.white,
                  //           decoration: TextDecoration.underline,
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                  // ),
                  // const SizedBox(height: 24),
                  
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _socialLoginButton(String text, IconData icon) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: Icon(icon, color: Colors.white),
        label: Text(
          text,
          style: GoogleFonts.inter(color: Colors.white),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade700),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: () {},
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    bool isPassword = false,
    Widget? trailing,
  }) {
    bool showPwd=false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(color: Colors.black),
            ),
            const Spacer(),
            if (trailing != null) trailing,
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: isPassword,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            suffixIcon: isPassword? IconButton(onPressed: (){
              showPwd=!showPwd;
            }, icon:Icon(showPwd?Icons.visibility:Icons.visibility_off) ):null,
            hintText: hintText,
            hintStyle: const TextStyle(color: Colors.black),
            filled: true,
            fillColor:  const Color.fromARGB(255, 241, 239, 239),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey.shade700),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey.shade700),
            ),
          ),
        ),
      ],
    );
  }
}
