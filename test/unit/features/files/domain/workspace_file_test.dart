import 'package:zedu/features/features.dart';

import '../../../../helpers/helpers.dart';

void main() {
  group('WorkspaceFile.fromJson file type (#4132)', () {
    String typeOf(String fileType, String name) => WorkspaceFile.fromJson({
      'id': 'f-1',
      'file_name': name,
      'file_type': fileType,
    }).fileType;

    test('a short MIME subtype is the type', () {
      expect(typeOf('image/png', 'logo.png'), 'png');
      expect(typeOf('IMAGE/JPEG', 'photo'), 'jpeg');
    });

    test('a bare extension is kept', () {
      expect(typeOf('pdf', 'report'), 'pdf');
    });

    test('a long or compound subtype falls back to the name extension', () {
      expect(typeOf('image/svg+xml', 'a.svg'), 'svg');
      expect(
        typeOf(
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          'r.docx',
        ),
        'docx',
      );
      expect(typeOf('text/x-markdown', 'README.MD'), 'md');
    });

    test('is empty when neither the subtype nor the name gives one', () {
      expect(typeOf('image/svg+xml', 'vector'), '');
    });

    test('an svg MIME type is previewed as svg', () {
      final file = WorkspaceFile.fromJson({
        'id': 'f-1',
        'file_name': 'a.svg',
        'file_type': 'image/svg+xml',
      });
      expect(FilePreviewKind.of(file), FilePreviewKind.svg);
    });
  });
}
