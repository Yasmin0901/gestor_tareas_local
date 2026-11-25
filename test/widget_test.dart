import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_tareas_local/data/database.dart';
import 'package:gestor_tareas_local/main.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;

  setUp(() {
    // closeStreamsSynchronously evita temporizadores pendientes al terminar
    // cada prueba de widgets.
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });

  tearDown(() => db.close());

  Future<void> abrirApp(WidgetTester tester) async {
    await tester.pumpWidget(GestorTareasApp(database: db));
    await tester.pumpAndSettle();
  }

  testWidgets('La pantalla inicial se muestra sin errores', (tester) async {
    await abrirApp(tester);

    expect(find.text('Gestor de tareas'), findsOneWidget);
    expect(find.text('Agregar tarea'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Todavía no hay tareas guardadas'), findsOneWidget);
  });

  testWidgets('Un título vacío no se registra (P5)', (tester) async {
    await abrirApp(tester);

    await tester.enterText(find.byType(TextField), '    ');
    await tester.tap(find.text('Agregar tarea'));
    await tester.pumpAndSettle();

    expect(
      find.text('El título no puede estar vacío ni contener solo espacios'),
      findsOneWidget,
    );
    expect(await db.obtenerTareas(), isEmpty);
  });

  testWidgets('Agregar, completar, editar y eliminar desde la interfaz', (
    tester,
  ) async {
    await abrirApp(tester);

    // Alta
    await tester.enterText(find.byType(TextField), 'Comprar pan');
    await tester.tap(find.text('Agregar tarea'));
    await tester.pumpAndSettle();
    expect(find.text('Comprar pan'), findsOneWidget);
    expect((await db.obtenerTareas()).single.titulo, 'Comprar pan');

    // Estado
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect((await db.obtenerTareas()).single.completada, isTrue);
    expect(find.textContaining('Completada'), findsOneWidget);

    // Edición
    await tester.tap(find.byTooltip('Editar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Comprar pan integral',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Comprar pan integral'), findsOneWidget);
    expect((await db.obtenerTareas()).single.titulo, 'Comprar pan integral');

    // Eliminación
    await tester.tap(find.byTooltip('Eliminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();
    expect(find.text('Todavía no hay tareas guardadas'), findsOneWidget);
    expect(await db.obtenerTareas(), isEmpty);
  });
}
