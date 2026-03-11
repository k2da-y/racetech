import 'package:flutter/material.dart';
import 'package:racetechph/pages/signup_page.dart';
import '../widgets/header.dart';
import '../widgets/footer.dart';

class SignUpPage2 extends StatelessWidget {

  final String firstName;
  final String lastName;
  final String gender;
  final String birthday;

  const SignUpPage2({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.birthday,
  });

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: Column(
        children: [
          const Header(),
          const Spacer(),

          const Text(
            "Account Details",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              children: [

                const TextField(
                  decoration: InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 15),

                const TextField(
                  decoration: InputDecoration(
                    labelText: "Username",
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 15),

                const TextField(
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: "Password",
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 20),

                const TextField(
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: "Re-enter Password",
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SignUpPage(),
                      ),
                    );
                  },
                  child: const Text("Back"),
                ),

                ElevatedButton(
                  onPressed: () {},
                  child: const Text("Create Account"),
                ),

              ],
            ),
          ),

          const Spacer(),
          const Footer()
        ],
      ),
    );
  }
}