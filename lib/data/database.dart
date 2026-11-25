import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../models/tarea.dart';

part 'database.g.dart';

/// Longitud máxima permitida para el título de una tarea.
const int maxLongitudTitulo = 200;

/// Error de validación cuando el título no es aceptable.
class TituloInvalidoException implements Exception {
  final String mensaje;
  const TituloInvalidoException(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Normaliza y valida un título. Devuelve el título sin espacios
/// sobrantes o lanza [TituloInvalidoException] si está vacío o es muy largo.
String validarTitulo(String titulo) {
  final limpio = titulo.trim();
  if (limpio.isEmpty) {
    throw const TituloInvalidoException(
      'El título no puede estar vacío ni contener solo espacios',
    );
  }
  if (limpio.length > maxLongitudTitulo) {
    throw const TituloInvalidoException(
      'El título no puede superar $maxLongitudTitulo caracteres',
    );
  }
  return limpio;
}

/// Tabla `tasks` en SQLite:
///   id        INTEGER PRIMARY KEY AUTOINCREMENT
///   title     TEXT NOT NULL
///   completed INTEGER NOT NULL DEFAULT 0  (booleano 0/1, CHECK IN (0,1))
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text()();

  BoolColumn get completed => boolean().withDefault(const Constant(false))();
}

/// Base de datos de la aplicación.
///
/// Sin argumentos abre el archivo persistente `gestor_tareas` mediante
/// drift_flutter (Android, iOS, Windows, Linux, macOS y web/WASM).
/// Las pruebas pueden pasar otro [QueryExecutor], p. ej. una base en memoria.
@DriftDatabase(tables: [Tasks])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _abrirConexion());

  static QueryExecutor _abrirConexion() {
    return driftDatabase(
      name: 'gestor_tareas',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }

  @override
  int get schemaVersion => 1;

  // SELECT: consulta reactiva; se vuelve a emitir tras cada escritura.
  Stream<List<Tarea>> watchTareas() {
    final consulta = select(tasks)..orderBy([(t) => OrderingTerm.asc(t.id)]);
    return consulta.watch().map((filas) => filas.map(_aTarea).toList());
  }

  // SELECT (una sola vez): útil en pruebas.
  Future<List<Tarea>> obtenerTareas() async {
    final consulta = select(tasks)..orderBy([(t) => OrderingTerm.asc(t.id)]);
    final filas = await consulta.get();
    return filas.map(_aTarea).toList();
  }

  // INSERT: devuelve el id generado.
  Future<int> insertarTarea(String titulo) async {
    final limpio = validarTitulo(titulo);
    return into(tasks).insert(TasksCompanion.insert(title: limpio));
  }

  // UPDATE del título. Devuelve false si el id no existe.
  Future<bool> actualizarTitulo(int id, String titulo) async {
    final limpio = validarTitulo(titulo);
    final filas = await (update(tasks)..where((t) => t.id.equals(id)))
        .write(TasksCompanion(title: Value(limpio)));
    return filas > 0;
  }

  // UPDATE del estado. Devuelve false si el id no existe.
  Future<bool> actualizarEstado(int id, bool completada) async {
    final filas = await (update(tasks)..where((t) => t.id.equals(id)))
        .write(TasksCompanion(completed: Value(completada)));
    return filas > 0;
  }

  // DELETE por id. Devuelve false si el id no existe.
  Future<bool> eliminarTarea(int id) async {
    final filas = await (delete(tasks)..where((t) => t.id.equals(id))).go();
    return filas > 0;
  }

  static Tarea _aTarea(Task fila) =>
      Tarea(id: fila.id, titulo: fila.title, completada: fila.completed);
}
