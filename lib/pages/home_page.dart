import 'package:flutter/material.dart';
import '../widgets/serial_bar.dart';
import '../widgets/midi_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EDA 电子琴'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: const [
          SerialBar(),
          SizedBox(height: 12),
          MidiCard(),
        ],
      ),
    );
  }
}
