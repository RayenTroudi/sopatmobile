import 'package:cross_file/cross_file.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// Levée quand le fichier image sélectionné est vide ou illisible — on
/// l'attrape côté client au lieu de laisser le backend répondre
/// « Empty upload ».
class EmptyImageException implements Exception {
  const EmptyImageException();
}

/// Construit la partie multipart `image` à partir des OCTETS du fichier.
///
/// Utilise `XFile` (image_picker) plutôt que `dart:io File` : `File` n'existe
/// pas sur Flutter Web (l'image du picker n'est qu'un blob navigateur), donc
/// tout code qui l'instancie plante au runtime en web. `XFile.readAsBytes()`
/// fonctionne identiquement sur Web, Android et iOS.
Future<http.MultipartFile> imagePart(XFile image, {String field = 'image'}) async {
  final bytes = await image.readAsBytes();
  if (bytes.isEmpty) throw const EmptyImageException();

  final ext = image.name.split('.').last.toLowerCase();
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
