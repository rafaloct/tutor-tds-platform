import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/cartilha.dart';
import '../../analytics/app_telemetry_service.dart';
import '../application/course_pdf_controller.dart';

class CoursePdfButton extends StatefulWidget {
  const CoursePdfButton({super.key, required this.course, this.controller});

  final Cartilha course;
  final CoursePdfController? controller;

  @override
  State<CoursePdfButton> createState() => _CoursePdfButtonState();
}

class _CoursePdfButtonState extends State<CoursePdfButton> {
  late final CoursePdfController _controller =
      widget.controller ?? CoursePdfController();
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    final result = await _controller.open(
      url: widget.course.downloadUrl,
      courseId: widget.course.id,
      telemetry: context.read<AppTelemetryService?>(),
    );
    if (!mounted) return;
    setState(() => _opening = false);
    if (result == CoursePdfResult.invalidLink ||
        result == CoursePdfResult.unavailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result == CoursePdfResult.invalidLink
                ? 'O link desta cartilha está indisponível.'
                : 'Não foi possível abrir o PDF. Tente novamente.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    icon: const Icon(Icons.picture_as_pdf, size: 14),
    label: const Text('PDF', style: TextStyle(fontSize: 12)),
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xFF093AF4),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    onPressed: _opening ? null : _open,
  );
}
