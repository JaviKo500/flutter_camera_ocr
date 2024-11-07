import 'package:go_router/go_router.dart';
import 'package:ocr_camera/presentation/screens/camera_ocr.dart';

final appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(
      path: '/home',
      builder: (context, state) => const CameraOcr(),
    ),
  ]
);