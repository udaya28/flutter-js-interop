import 'package:flutter/material.dart';

import 'interop/chart_interop.dart';
import 'view/chart_root.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(ChartApp(chartInterop: ChartInterop()));
}

class ChartApp extends StatefulWidget {
  const ChartApp({super.key, required this.chartInterop});

  final ChartInterop chartInterop;

  @override
  State<ChartApp> createState() => _ChartAppState();
}

class _ChartAppState extends State<ChartApp> {
  @override
  void initState() {
    super.initState();
    widget.chartInterop.bootstrap();
  }

  @override
  void dispose() {
    widget.chartInterop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Chart',
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(child: ChartRoot(interop: widget.chartInterop)),
      ),
    );
  }
}
