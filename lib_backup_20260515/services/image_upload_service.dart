import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Image Upload Service — Centralized image validation for courier uploads.
//
// Consolidates all image-picking and validation logic that was previously
// duplicated across `vehicle_screen.dart` and `kifiya_screen.dart`.
//
// Usage:
//   final result = await ImageUploadService.pickAndValidate();
//   result.when(success: (file) => ..., failure: (msg) => ...);
//
//   final batch = await ImageUploadService.validateBatch(paths);
//   if (!batch.hasValid) { /* block payment */ }
// ─────────────────────────────────────────────────────────────────────────────

/// Result of a single image validation.
///
/// Either holds a validated [File] on success, or an error [message] + [type]
/// on failure. Never both.
class ImageValidationResult {
  final File? file;
  final String? message;
  final ImageValidationError? type;

  const ImageValidationResult._({this.file, this.message, this.type});

  /// Successful validation — [file] is guaranteed non-null.
  factory ImageValidationResult.success(File file) =>
      ImageValidationResult._(file: file);

  /// Failed validation — [message] is user-facing, [type] is programmatic.
  factory ImageValidationResult.failure(
    String message,
    ImageValidationError type,
  ) => ImageValidationResult._(message: message, type: type);

  bool get isSuccess => file != null;
  bool get isFailure => !isSuccess;

  /// Pattern-match style convenience.
  T when<T>({
    required T Function(File file) success,
    required T Function(String message, ImageValidationError type) failure,
  }) {
    if (isSuccess) return success(file!);
    return failure(message!, type!);
  }
}

/// Categorization of image validation failures.
enum ImageValidationError {
  cancelled,
  permissionDenied,
  notFound,
  unsupportedFormat,
  empty,
  tooLarge,
  corrupted,
  unreadable,
  unknown,
}

/// Result of validating a batch of image paths.
///
/// Separates paths into [validPaths] and categorized [issues].
/// This replaces the inline 4-bucket logic that was duplicated in
/// `_validateCourierImagesBeforePayment()` and `createCourierOrder()`.
class BatchValidationResult {
  final List<String> validPaths;
  final List<BatchIssue> issues;

  const BatchValidationResult({required this.validPaths, required this.issues});

  bool get hasValid => validPaths.isNotEmpty;
  bool get hasIssues => issues.isNotEmpty;
  bool get allFailed => validPaths.isEmpty && issues.isNotEmpty;

  /// Human-readable summary for SnackBar / error display.
  ///
  /// Groups issues by type and returns a message like:
  /// "1 image(s) missing or deleted; 1 image(s) exceed the 10 MB limit"
  String get summary {
    final Map<ImageValidationError, int> counts = {};
    for (final issue in issues) {
      counts[issue.type] = (counts[issue.type] ?? 0) + 1;
    }

    final List<String> parts = [];
    counts.forEach((type, count) {
      parts.add('$count image(s) ${_labelForError(type)}');
    });

    return parts.join('; ');
  }

  static String _labelForError(ImageValidationError type) {
    switch (type) {
      case ImageValidationError.notFound:
        return 'missing or deleted';
      case ImageValidationError.unsupportedFormat:
        return 'have unsupported format';
      case ImageValidationError.tooLarge:
        return 'exceed the ${ImageUploadService.maxImageSizeMB} MB limit';
      case ImageValidationError.empty:
      case ImageValidationError.corrupted:
      case ImageValidationError.unreadable:
        return 'are corrupted or unreadable';
      default:
        return 'could not be validated';
    }
  }
}

/// A single issue found during batch validation.
class BatchIssue {
  final String path;
  final String fileName;
  final ImageValidationError type;

  const BatchIssue({
    required this.path,
    required this.fileName,
    required this.type,
  });

  /// Short label for upload-time logging, e.g. "Missing: photo.jpg"
  String get label {
    switch (type) {
      case ImageValidationError.notFound:
        return 'Missing: $fileName';
      case ImageValidationError.unsupportedFormat:
        return 'Unsupported format: $fileName';
      case ImageValidationError.tooLarge:
        return 'Too large: $fileName';
      case ImageValidationError.empty:
        return 'Empty file: $fileName';
      case ImageValidationError.corrupted:
      case ImageValidationError.unreadable:
        return 'Corrupted: $fileName';
      default:
        return 'Unreadable: $fileName';
    }
  }
}

/// Centralized image validation service for courier image uploads.
///
/// **Responsibilities:**
/// - Pick images from gallery with platform-error handling
/// - Validate single files (format, size, corruption)
/// - Validate batches of file paths (pre-payment & upload gates)
///
/// **Design:**
/// - All methods are static — no instance state, matches `Service` pattern
/// - Constants exposed as static for UI display (e.g., size limit messages)
/// - Returns typed result objects instead of throwing, so callers handle UI
class ImageUploadService {
  ImageUploadService._(); // prevent instantiation

  // ─── Constants ───────────────────────────────────────────────────────

  /// Maximum allowed image file size in bytes (10 MB).
  static const int maxImageSizeBytes = 10 * 1024 * 1024;

  /// Maximum allowed image file size in megabytes (convenience).
  static const int maxImageSizeMB = 10;

  /// Allowed image file extensions. Server accepts these formats.
  static const List<String> allowedExtensions = [
    '.jpg',
    '.jpeg',
    '.png',
    '.heic',
    '.heif',
    '.webp',
  ];

  /// Image quality used when picking from gallery (0–100).
  /// Compresses at pick time to reduce upload size.
  static const int pickImageQuality = 80;

  // ─── Single Image: Pick + Validate ───────────────────────────────────

  /// Pick an image from gallery and validate it.
  ///
  /// Returns [ImageValidationResult.success] with the validated file, or
  /// [ImageValidationResult.failure] with a user-facing reason.
  ///
  /// Handles:
  /// - User cancellation (returns `cancelled` type)
  /// - iOS/Android permission denial (`permissionDenied`)
  /// - File not found, bad format, too large, corrupted
  static Future<ImageValidationResult> pickAndValidate() async {
    final ImagePicker picker = ImagePicker();

    try {
      final XFile? xFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: pickImageQuality,
      );

      // User cancelled the picker
      if (xFile == null) {
        return ImageValidationResult.failure(
          '',
          ImageValidationError.cancelled,
        );
      }

      return validateFile(File(xFile.path), fileName: xFile.name);
    } on PlatformException catch (e) {
      if (e.code == 'photo_access_denied' ||
          e.code == 'camera_access_denied' ||
          e.message?.toLowerCase().contains('permission') == true) {
        return ImageValidationResult.failure(
          'Photo library access was denied.\n'
          'Please enable it in your device Settings → ZMall → Photos.',
          ImageValidationError.permissionDenied,
        );
      }
      return ImageValidationResult.failure(
        'Could not access images: ${e.message}',
        ImageValidationError.unknown,
      );
    } catch (_) {
      return ImageValidationResult.failure(
        'An unexpected error occurred while selecting the image.',
        ImageValidationError.unknown,
      );
    }
  }

  // ─── Single Image: Validate Existing File ────────────────────────────

  /// Validate an already-selected file (existence, format, size, corruption).
  ///
  /// [fileName] is used for extension checking. If not provided, it is
  /// extracted from [file.path].
  static Future<ImageValidationResult> validateFile(
    File file, {
    String? fileName,
  }) async {
    final String name =
        fileName ?? file.path.split(Platform.pathSeparator).last;

    // --- Existence ---
    if (!await file.exists()) {
      return ImageValidationResult.failure(
        'Selected file could not be found. Please try again.',
        ImageValidationError.notFound,
      );
    }

    // --- Extension ---
    final String ext = name.contains('.')
        ? '.${name.split('.').last.toLowerCase()}'
        : '';
    if (ext.isEmpty || !allowedExtensions.contains(ext)) {
      return ImageValidationResult.failure(
        'Unsupported image format ($ext).\n'
        'Please select a JPG, PNG, HEIC, or WebP image.',
        ImageValidationError.unsupportedFormat,
      );
    }

    // --- Size ---
    final int fileSize;
    try {
      fileSize = await file.length();
    } catch (_) {
      return ImageValidationResult.failure(
        'Unable to read the selected image. The file may be corrupted.',
        ImageValidationError.unreadable,
      );
    }

    if (fileSize == 0) {
      return ImageValidationResult.failure(
        'The selected image is empty or corrupted.',
        ImageValidationError.empty,
      );
    }
    if (fileSize > maxImageSizeBytes) {
      final double sizeMB = fileSize / (1024 * 1024);
      return ImageValidationResult.failure(
        'Image is too large (${sizeMB.toStringAsFixed(1)} MB).\n'
        'Maximum allowed size is $maxImageSizeMB MB.',
        ImageValidationError.tooLarge,
      );
    }

    // --- Corruption (decode check) ---
    try {
      final bytes = await file.readAsBytes();
      final ui.Image decoded = await _decodeImage(bytes);
      if (decoded.width == 0 || decoded.height == 0) {
        return ImageValidationResult.failure(
          'The selected image appears to be corrupted.',
          ImageValidationError.corrupted,
        );
      }
    } catch (_) {
      return ImageValidationResult.failure(
        'Unable to read the selected image. The file may be corrupted.',
        ImageValidationError.corrupted,
      );
    }

    return ImageValidationResult.success(file);
  }

  // ─── Batch: Validate Multiple Paths ──────────────────────────────────

  /// Validate a list of image paths. Used before payment and at upload time.
  ///
  /// Returns a [BatchValidationResult] with separated valid paths and issues.
  /// Uses lightweight checks (no decode) for speed — suitable for pre-payment
  /// and upload-time gates where images have already passed full validation
  /// during selection.
  ///
  /// Set [fullDecode] to `true` to also run the corruption decode check
  /// (slower, but catches files corrupted after selection).
  static Future<BatchValidationResult> validateBatch(
    List<String> paths, {
    bool fullDecode = false,
  }) async {
    final List<String> validPaths = [];
    final List<BatchIssue> issues = [];

    for (final path in paths) {
      final String fileName = path.split('/').last.split('\\').last;
      final File file = File(path);

      // Existence
      if (!await file.exists()) {
        issues.add(
          BatchIssue(
            path: path,
            fileName: fileName,
            type: ImageValidationError.notFound,
          ),
        );
        continue;
      }

      // Extension
      final String ext = path.contains('.')
          ? '.${path.split('.').last.toLowerCase()}'
          : '';
      if (ext.isEmpty || !allowedExtensions.contains(ext)) {
        issues.add(
          BatchIssue(
            path: path,
            fileName: fileName,
            type: ImageValidationError.unsupportedFormat,
          ),
        );
        continue;
      }

      // Size
      try {
        final int fileSize = await file.length();
        if (fileSize == 0) {
          issues.add(
            BatchIssue(
              path: path,
              fileName: fileName,
              type: ImageValidationError.empty,
            ),
          );
          continue;
        }
        if (fileSize > maxImageSizeBytes) {
          issues.add(
            BatchIssue(
              path: path,
              fileName: fileName,
              type: ImageValidationError.tooLarge,
            ),
          );
          continue;
        }
      } catch (_) {
        issues.add(
          BatchIssue(
            path: path,
            fileName: fileName,
            type: ImageValidationError.unreadable,
          ),
        );
        continue;
      }

      // Readability (fast: just read bytes, no decode)
      try {
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) {
          issues.add(
            BatchIssue(
              path: path,
              fileName: fileName,
              type: ImageValidationError.corrupted,
            ),
          );
          continue;
        }

        // Optional full decode
        if (fullDecode) {
          final ui.Image decoded = await _decodeImage(bytes);
          if (decoded.width == 0 || decoded.height == 0) {
            issues.add(
              BatchIssue(
                path: path,
                fileName: fileName,
                type: ImageValidationError.corrupted,
              ),
            );
            continue;
          }
        }
      } catch (_) {
        issues.add(
          BatchIssue(
            path: path,
            fileName: fileName,
            type: ImageValidationError.corrupted,
          ),
        );
        continue;
      }

      validPaths.add(path);
    }

    return BatchValidationResult(validPaths: validPaths, issues: issues);
  }

  // ─── Helpers ─────────────────────────────────────────────────────────

  /// Build a user-facing permission-denied message.
  ///
  /// Called from UI layer when [ImageValidationError.permissionDenied] is
  /// returned, to give platform-appropriate guidance.
  static String get permissionDeniedMessage =>
      'Photo library access was denied.\n'
      'Please enable it in your device Settings → ZMall → Photos.';

  // ─── Internal ────────────────────────────────────────────────────────

  /// Decode image bytes to verify the file is a valid image.
  ///
  /// Wraps [ui.decodeImageFromList] (which uses a callback) into a Future.
  static Future<ui.Image> _decodeImage(Uint8List bytes) {
    final Completer<ui.Image> completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, (ui.Image image) {
      completer.complete(image);
    });
    return completer.future;
  }
}
