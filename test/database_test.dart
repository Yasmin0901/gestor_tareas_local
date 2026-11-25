import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_tareas_local/data/database.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('validarTitulo', () {
    test('rechaza títulos vacíos o solo con espacios (P5)', () {
      expect(() => validarTitulo(''), throwsA(isA<TituloInvalidoException>()));
      expect(
        () => validarTitulo('   \t  '),
        throwsA(isA<TituloInvalidoException>()),
      );
    });

    test('rechaza títulos demasiado largos', () {
      expect(
        () => validarTitulo('a' * (maxLongitudTitulo + 1)),
        throwsA(isA<TituloInvalidoException>()),
      );
    });

    test('elimina espacios al inicio y al final', () {
      expect(validarTitulo('  Estudiar  '), 'Estudiar');
    });
  });

  group('CRUD en SQLite (memoria)', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('INSERT y SELECT devuelven las tareas en orden de id', () async {
      final id1 = await db.insertarTarea('Uno');
      final id2 = await db.insertarTarea('  Dos  ');

      final tareas = await db.obtenerTareas();
      expect(tareas.map((t) => t.id), [id1, id2]);
      expect(tareas.map((t) => t.titulo), ['Uno', 'Dos']);
      expect(tareas.every((t) => !t.completada), isTrue);
    });

    test('no inserta un título vacío', () async {
      await expectLater(
        db.insertarTarea('   '),
        throwsA(isA<TituloInvalidoException>()),
      );
      expect(await db.obtenerTareas(), isEmpty);
    });

    test('UPDATE de título y de estado', () async {
      final id = await db.insertarTarea('Original');

      expect(await db.actualizarTitulo(id, 'Editada'), isTrue);
      expect(await db.actualizarEstado(id, true), isTrue);

      final tarea = (await db.obtenerTareas()).single;
      expect(tarea.titulo, 'Editada');
      expect(tarea.completada, isTrue);

      expect(await db.actualizarEstado(id, false), isTrue);
      expect((await db.obtenerTareas()).single.completada, isFalse);
    });

    test('UPDATE con título vacío no modifica la tarea', () async {
      final id = await db.insertarTarea('Original');
      await expectLater(
        db.actualizarTitulo(id, '  '),
        throwsA(isA<TituloInvalidoException>()),
      );
      expect((await db.obtenerTareas()).single.titulo, 'Original');
    });

    test('DELETE por id y operaciones sobre ids inexistentes', () async {
      final id1 = await db.insertarTarea('Borrar');
      final id2 = await db.insertarTarea('Conservar');

      expect(await db.eliminarTarea(id1), isTrue);
      expect((await db.obtenerTareas()).map((t) => t.id), [id2]);

      expect(await db.eliminarTarea(id1), isFalse);
      expect(await db.actualizarTitulo(id1, 'X'), isFalse);
      expect(await db.actualizarEstado(id1, true), isFalse);
    });

    test('watchTareas emite de nuevo después de cada escritura', () async {
      final emisiones = db.watchTareas().map((l) => l.length);
      final esperado = expectLater(emisiones, emitsInOrder([0, 1, 0]));

      // Esperamos la primera emisión antes de escribir.
      await db.watchTareas().first;
      final id = await db.insertarTarea('Reactiva');
      await Future<void>.delayed(Duration.zero);
      await db.eliminarTarea(id);

      await esperado;
    });
  });

  group('Persistencia en archivo (simula cerrar y reabrir la app)', () {
    late Directory dir;
    late File archivo;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('gestor_tareas_test');
      archivo = File('${dir.path}${Platform.pathSeparator}tareas.sqlite');
    });

    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('P1–P4: los cambios sobreviven al cierre de la base', () async {
      // Primera "ejecución": agregar tres, completar, renombrar y borrar.
      var db = AppDatabase(NativeDatabase(archivo));
      final a = await db.insertarTarea('Tarea A');
      final b = await db.insertarTarea('Tarea B');
      final c = await db.insertarTarea('Tarea C');
      await db.close();

      // Segunda "ejecución": permanecen las tres (P1).
      db = AppDatabase(NativeDatabase(archivo));
      expect((await db.obtenerTareas()).map((t) => t.titulo), [
        'Tarea A',
        'Tarea B',
        'Tarea C',
      ]);
      await db.actualizarEstado(a, true);
      await db.actualizarTitulo(b, 'Tarea B editada');
      await db.eliminarTarea(c);
      await db.close();

      // Tercera "ejecución": estado (P2), título (P3) y borrado (P4).
      db = AppDatabase(NativeDatabase(archivo));
      final tareas = await db.obtenerTareas();
      await db.close();

      expect(tareas.map((t) => t.id), [a, b]);
      expect(tareas[0].completada, isTrue);
      expect(tareas[1].titulo, 'Tarea B editada');
      expect(tareas[1].completada, isFalse);
    });
  });
}
