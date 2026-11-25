// Fuente del worker web de Drift. Se compila con la MISMA versión de drift
// que usa la app (pubspec.lock) para garantizar compatibilidad:
//
//   dart compile js -O4 tool/drift_worker.dart -o web/drift_worker.js
//
// Ver https://drift.simonbinder.eu/platforms/web/
import 'package:drift/wasm.dart';

void main() => WasmDatabase.workerMainForOpen();
