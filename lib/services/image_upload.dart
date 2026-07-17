import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// Levée quand le fichier image sélectionné est vide ou illisible — on
/// l'attrape côté client au lieu de laisser le backend répondre
/// « Empty upload ».
class EmptyImageException implements Exception {
  const EmptyImageException();
}

/// Construit la partie multipart `image` à partir des OCTETS du fichier
/// (et non d'un flux paresseux sur le chemin). Sur Android, image_picker
/// ré-encode la photo dans un fichier temporaire dont le flux paresseux
/// de `MultipartFile.fromPath` peut arriver vide au serveur ; lire les
/// octets explicitement et fixer le content-type corrige ce cas.
Future<http.MultipartFile> imagePart(File image, {String field = 'image'}) async {
  final bytes = await image.readAsBytes();
  if (bytes.isEmpty) throw const EmptyImageException();

  final ext = image.path.split('.').last.toLowerCase();
  final subtype = switch (ext) {
    'png' => 'png',
    'webp' => 'webp',
    'bmp' => 'bmp',
    'tif' || 'tiff' => 'tiff',
    'heic' || 'heif' => 'jpeg', // image_picker convertit en JPEG à l'export
    _ => 'jpeg',
  };
  final filename = 'upload.${subtype == 'jpeg' ? 'jpg' : subtype}';

  return http.MultipartFile.fromBytes(
    field,
    bytes,
    filename: filename,
    contentType: MediaType('image', subtype),
  );
}
