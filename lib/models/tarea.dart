/// Modelo de tarea que usa la interfaz.
///
/// Es independiente de Drift: la capa de datos (lib/data/database.dart)
/// convierte cada fila de la tabla `tasks` en un objeto [Tarea].
class Tarea {
  final int id;
  final String titulo;
  final bool completada;

  const Tarea({
    required this.id,
    required this.titulo,
    required this.completada,
  });
}
