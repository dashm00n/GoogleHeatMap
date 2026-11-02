// Minimaler Webserver für den PC-Test: liefert build/web aus.
//
//   flutter build web && dart run tool/serve_web.dart [port] [--lan]
//
// Ohne --lan nur vom PC selbst erreichbar. Mit --lan auch von anderen Geräten
// im selben WLAN (z. B. dem Handy). Nur für erfundene Probedaten verwenden!
import 'dart:io';

const _types = {
  'html': 'text/html; charset=utf-8',
  'js': 'text/javascript',
  'mjs': 'text/javascript',
  'json': 'application/json',
  'wasm': 'application/wasm',
  'css': 'text/css',
  'png': 'image/png',
  'ico': 'image/x-icon',
  'ttf': 'font/ttf',
  'otf': 'font/otf',
};

Future<void> main(List<String> args) async {
  final lan = args.contains('--lan');
  final portArg = args.where((a) => !a.startsWith('--'));
  final port = portArg.isEmpty ? 8080 : int.parse(portArg.first);
  final root = Directory('build/web').absolute.path;
  final server =
      await HttpServer.bind(lan ? InternetAddress.anyIPv4 : InternetAddress.loopbackIPv4, port);
  stdout.writeln('Serving $root on http://localhost:$port');
  if (lan) {
    for (final iface in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
      for (final addr in iface.addresses) {
        stdout.writeln('  im Heimnetz (${iface.name}): http://${addr.address}:$port');
      }
    }
  }
  await for (final req in server) {
    var path = Uri.decodeComponent(req.uri.path);
    if (path.endsWith('/')) path += 'index.html';
    final file = File('$root$path');
    // Kein Zugriff außerhalb von build/web.
    if (!file.absolute.path.startsWith(root) || !await file.exists()) {
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
      continue;
    }
    final ext = path.split('.').last;
    req.response.headers.contentType = ContentType.parse(_types[ext] ?? 'application/octet-stream');
    await req.response.addStream(file.openRead());
    await req.response.close();
  }
}
