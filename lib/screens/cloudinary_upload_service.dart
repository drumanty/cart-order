import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class CloudinaryUploadException implements Exception {
  const CloudinaryUploadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CloudinaryUploadService {
  CloudinaryUploadService._();

  static const _cloudName = 'csgustoc';
  static const categoryPreset = 'cartorder_categories';
  static const productPreset = 'cartorder_products';
  static const profilePreset = 'cartorder_profiles';
  static const _maxImageBytes = 5 * 1024 * 1024;

  static Future<String> uploadImage({
    required XFile image,
    required String uploadPreset,
  }) async {
    final bytes = await image.readAsBytes();

    if (bytes.isEmpty) {
      throw const CloudinaryUploadException('The selected image is empty.');
    }
    if (bytes.length > _maxImageBytes) {
      throw const CloudinaryUploadException(
        'Please select an image smaller than 5 MB.',
      );
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload'),
    );
    request.fields['upload_preset'] = uploadPreset;
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: image.name),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    dynamic body;
    try {
      body = jsonDecode(response.body);
    } catch (_) {
      body = null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Cloudinary could not upload the image.';

      if (body is Map<String, dynamic>) {
        final error = body['error'];
        if (error is Map<String, dynamic>) {
          final cloudinaryMessage = error['message']?.toString();
          if (cloudinaryMessage != null && cloudinaryMessage.isNotEmpty) {
            message = cloudinaryMessage;
          }
        }
      }

      throw CloudinaryUploadException(message);
    }

    if (body is! Map<String, dynamic>) {
      throw const CloudinaryUploadException(
        'Cloudinary returned an invalid upload response.',
      );
    }

    final secureUrl = body['secure_url']?.toString() ?? '';
    if (secureUrl.isEmpty) {
      throw const CloudinaryUploadException(
        'Cloudinary did not return an image URL.',
      );
    }

    return secureUrl;
  }
}
