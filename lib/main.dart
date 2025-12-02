

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  await Supabase.initialize(
    url: 'https://tksxstwnsqgrioedqify.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRrc3hzdHduc3FncmlvZWRxaWZ5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQ0NTM1NjQsImV4cCI6MjA2MDAyOTU2NH0.Vts1q7iNTbbkv5anmTN7e-JxM1_A7ofbqMsCfZHetQA',
  );
  runApp(const MaterialApp(home: PathDrawingApp()));
}

class PathDrawingApp extends StatefulWidget {
  const PathDrawingApp({super.key});

  @override
  State<PathDrawingApp> createState() => _PathDrawingAppState();
}

class _PathDrawingAppState extends State<PathDrawingApp> {
  final List<DataBlock> _blocks = [DataBlock(position: Offset.zero, value: null)];
  List<dynamic> _fetchedData = [];
  Direction _direction = Direction.up;
  late DateTime _sessionStartTime;

  @override
  void initState() {
    super.initState();
    _sessionStartTime = DateTime.now().toUtc();
    _fetchSupabaseData();

    Supabase.instance.client
        .from('dht')
        .stream(primaryKey: ['id'])
        .listen((data) {
          print('Stream received: $data');
          _fetchSupabaseData();
});

  }

  Offset _offsetFromDirection(Direction dir) {
    switch (dir) {
      case Direction.up:
        return const Offset(0, -1);
      case Direction.down:
        return const Offset(0, 1);
      case Direction.left:
        return const Offset(-1, 0);
      case Direction.right:
        return const Offset(1, 0);
    }
  }

  Direction _turnRight(Direction dir) {
    switch (dir) {
      case Direction.up:
        return Direction.right;
      case Direction.right:
        return Direction.down;
      case Direction.down:
        return Direction.left;
      case Direction.left:
        return Direction.up;
    }
  }

  Direction _turnLeft(Direction dir) {
    switch (dir) {
      case Direction.up:
        return Direction.left;
      case Direction.left:
        return Direction.down;
      case Direction.down:
        return Direction.right;
      case Direction.right:
        return Direction.up;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor Path Mapper'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _fetchedData.length,
                itemBuilder: (context, index) {
                  final row = _fetchedData[index];
                  return Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('ID: ${row['id']}'),
                        Text('Value: ${row['temp']}'),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const double blockSize = 45.0;
                  double minX = 0, maxX = 0, minY = 0, maxY = 0;
                  for (final block in _blocks) {
                    if (block.position.dx < minX) minX = block.position.dx;
                    if (block.position.dx > maxX) maxX = block.position.dx;
                    if (block.position.dy < minY) minY = block.position.dy;
                    if (block.position.dy > maxY) maxY = block.position.dy;
                  }
                  final double width = (maxX - minX + 1) * blockSize;
                  final double height = (maxY - minY + 1) * blockSize;

                  return InteractiveViewer(
                    boundaryMargin: const EdgeInsets.all(1000),
                    minScale: 0.5,
                    maxScale: 2.5,
                    child: Center(
                      child: SizedBox(
                        width: width,
                        height: height,
                        child: CustomPaint(
                          painter: SensorPainter(_blocks, blockSize, minX, minY),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchSupabaseData() async {
    try {
      final List data = await Supabase.instance.client
          .from('dht')
          .select()
          .gte('created_at', _sessionStartTime.toIso8601String())
          .order('id', ascending: true);

      final List<DataBlock> newBlocks = [];
      Offset current = Offset.zero;
      Direction currentDirection = Direction.up;

      for (final row in data) {
        final String? command = row['movement'];
        final double? value = _safeParseTemp(row['temp']);

        if (command != null) {
          switch (command.toUpperCase()) {
            case 'F':
              current += _offsetFromDirection(currentDirection);
              newBlocks.add(DataBlock(position: current, value: value));
              break;
            case 'R':
              currentDirection = _turnRight(currentDirection);
              current += _offsetFromDirection(currentDirection);
              newBlocks.add(DataBlock(position: current, value: value));
              break;
            case 'L':
              currentDirection = _turnLeft(currentDirection);
              current += _offsetFromDirection(currentDirection);
              newBlocks.add(DataBlock(position: current, value: value));
              break;
            case 'B':
              currentDirection = _turnRight(_turnRight(currentDirection));
              current += _offsetFromDirection(currentDirection);
              newBlocks.add(DataBlock(position: current, value: value));
              break;
          }
        }
      }

      setState(() {
        _fetchedData = data;
        _blocks
          ..clear()
          ..add(DataBlock(position: Offset.zero, value: null))
          ..addAll(newBlocks);
      });
    } catch (e) {
      print('Error fetching data: $e');
    }
  }

  double? _safeParseTemp(dynamic temp) {
  if (temp == null) return null;
  if (temp is int) return temp.toDouble();
  if (temp is double) return temp;

  try {
    return double.parse(temp.toString());
  } catch (e) {
    print("Invalid temp value skipped: $temp");
    return null;
  }
}

}

enum Direction { up, right, down, left }

class DataBlock {
  final Offset position;
  final double? value;

  DataBlock({required this.position, this.value});
}

class SensorPainter extends CustomPainter {
  final List<DataBlock> blocks;
  final double blockSize;
  final double minX, minY;

  SensorPainter(this.blocks, this.blockSize, this.minX, this.minY);

  @override
  void paint(Canvas canvas, Size size) {
    for (final block in blocks) {
      final Offset pixelOffset = Offset(
        (block.position.dx - minX) * blockSize,
        (block.position.dy - minY) * blockSize,
      );

      final Paint fillPaint = Paint()
        ..color = _getColor(block.value)
        ..style = PaintingStyle.fill;

      final Paint borderPaint = Paint()
        ..color = const Color.fromARGB(255, 0, 0, 0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;

      final rect = Rect.fromLTWH(
        pixelOffset.dx,
        pixelOffset.dy,
        blockSize,
        blockSize,
      );

      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, borderPaint);
    }
  }

  Color _getColor(double? value) {
  if (value == null) return Colors.grey;
  if (value > 70.0) return const Color.fromARGB(255, 192, 13, 1);
  if (value > 50.0) return const Color.fromARGB(255, 249, 111, 12);
  return Colors.green;
}


  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}



