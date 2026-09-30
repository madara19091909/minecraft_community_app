import 'package:flutter/material.dart';

void main() {
  runApp(const MinecraftApp());
}

class MinecraftApp extends StatelessWidget {
  const MinecraftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Minecraft Community',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('مجتمع ماين كرافت'),
          centerTitle: true,
          backgroundColor: Colors.green,
        ),
        body: const Center(
          child: Text(
            'أهلاً بك في تطبيق مجتمع ماين كرافت!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
