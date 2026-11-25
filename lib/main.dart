import 'package:flutter/material.dart';

import 'data/database.dart';
import 'screens/tareas_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GestorTareasApp());
}

/// Raíz de la aplicación.
///
/// Si no recibe [database], abre la base persistente y la cierra al
/// destruirse. Las pruebas inyectan una base en memoria.
class GestorTareasApp extends StatefulWidget {
  final AppDatabase? database;

  const GestorTareasApp({super.key, this.database});

  @override
  State<GestorTareasApp> createState() => _GestorTareasAppState();
}

class _GestorTareasAppState extends State<GestorTareasApp> {
  late final AppDatabase _database;
  late final bool _esPropia;

  @override
  void initState() {
    super.initState();
    _esPropia = widget.database == null;
    _database = widget.database ?? AppDatabase();
  }

  @override
  void dispose() {
    // Solo cerramos la base que abrimos nosotros.
    if (_esPropia) {
      _database.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestor de tareas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: TareasPage(database: _database),
    );
  }
}
