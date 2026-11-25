import 'package:flutter/material.dart';

import '../data/database.dart';
import '../models/tarea.dart';

class TareasPage extends StatefulWidget {
  final AppDatabase database;

  const TareasPage({super.key, required this.database});

  @override
  State<TareasPage> createState() => _TareasPageState();
}

class _TareasPageState extends State<TareasPage> {
  final TextEditingController _tituloController = TextEditingController();
  final FocusNode _tituloFocus = FocusNode();

  /// Consulta reactiva creada UNA sola vez (no dentro de build()).
  late final Stream<List<Tarea>> _tareas;

  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _tareas = widget.database.watchTareas();
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _tituloFocus.dispose();
    super.dispose();
  }

  // ALTA
  Future<void> _agregarTarea() async {
    if (_guardando) return;

    final String titulo;
    try {
      titulo = validarTitulo(_tituloController.text);
    } on TituloInvalidoException catch (e) {
      _mensaje(e.mensaje);
      return;
    }

    // Se limpia ANTES de esperar la escritura: si el usuario escribe la
    // siguiente tarea mientras se guarda, no se le borra el texto.
    _tituloController.clear();
    setState(() => _guardando = true);
    try {
      await widget.database.insertarTarea(titulo);
      _mensaje('Tarea agregada');
    } catch (e) {
      if (_tituloController.text.isEmpty) _tituloController.text = titulo;
      _mensaje('No se pudo guardar la tarea: $e');
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
        _tituloFocus.requestFocus(); // permite capturar varias seguidas
      }
    }
  }

  // ESTADO
  Future<void> _alternarCompletada(Tarea tarea, bool completada) async {
    try {
      final ok = await widget.database.actualizarEstado(tarea.id, completada);
      if (!ok) _mensaje('La tarea ya no existe');
    } catch (e) {
      _mensaje('No se pudo actualizar la tarea: $e');
    }
  }

  // EDICIÓN
  Future<void> _editarTarea(Tarea tarea) async {
    final nuevoTitulo = await showDialog<String>(
      context: context,
      builder: (_) => _EditarTareaDialog(tituloInicial: tarea.titulo),
    );
    if (nuevoTitulo == null || nuevoTitulo == tarea.titulo) return;

    try {
      final ok = await widget.database.actualizarTitulo(tarea.id, nuevoTitulo);
      _mensaje(ok ? 'Tarea modificada' : 'La tarea ya no existe');
    } on TituloInvalidoException catch (e) {
      _mensaje(e.mensaje);
    } catch (e) {
      _mensaje('No se pudo editar la tarea: $e');
    }
  }

  // ELIMINACIÓN
  Future<void> _eliminarTarea(Tarea tarea) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar tarea'),
        content: Text('¿Deseas eliminar "${tarea.titulo}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      final ok = await widget.database.eliminarTarea(tarea.id);
      _mensaje(ok ? 'Tarea eliminada' : 'La tarea ya no existe');
    } catch (e) {
      _mensaje('No se pudo eliminar la tarea: $e');
    }
  }

  void _mensaje(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestor de tareas')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _tituloController,
              focusNode: _tituloFocus,
              maxLength: maxLongitudTitulo,
              decoration: const InputDecoration(
                labelText: 'Nueva tarea',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _agregarTarea(),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _guardando ? null : _agregarTarea,
              icon: const Icon(Icons.add),
              label: const Text('Agregar tarea'),
            ),
            const SizedBox(height: 12),
            const Text('Mis tareas', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<Tarea>>(
                stream: _tareas,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error al consultar las tareas:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final tareas = snapshot.data!;
                  if (tareas.isEmpty) {
                    return const Center(
                      child: Text('Todavía no hay tareas guardadas'),
                    );
                  }

                  return ListView.builder(
                    itemCount: tareas.length,
                    itemBuilder: (context, index) {
                      final tarea = tareas[index];
                      return Card(
                        key: ValueKey(tarea.id),
                        child: ListTile(
                          leading: Checkbox(
                            value: tarea.completada,
                            onChanged: (valor) {
                              if (valor != null) {
                                _alternarCompletada(tarea, valor);
                              }
                            },
                          ),
                          title: Text(
                            tarea.titulo,
                            style: TextStyle(
                              decoration: tarea.completada
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                          subtitle: Text(
                            'ID: ${tarea.id} · '
                            '${tarea.completada ? 'Completada' : 'Pendiente'}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Editar',
                                icon: const Icon(Icons.edit),
                                onPressed: () => _editarTarea(tarea),
                              ),
                              IconButton(
                                tooltip: 'Eliminar',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _eliminarTarea(tarea),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo de edición. Es dueño de su controlador y lo libera en dispose(),
/// después de que termina la animación de cierre.
class _EditarTareaDialog extends StatefulWidget {
  final String tituloInicial;

  const _EditarTareaDialog({required this.tituloInicial});

  @override
  State<_EditarTareaDialog> createState() => _EditarTareaDialogState();
}

class _EditarTareaDialogState extends State<_EditarTareaDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.tituloInicial);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _guardar() {
    try {
      Navigator.pop(context, validarTitulo(_controller.text));
    } on TituloInvalidoException catch (e) {
      setState(() => _error = e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar tarea'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: maxLongitudTitulo,
        decoration: InputDecoration(
          labelText: 'Nuevo título',
          border: const OutlineInputBorder(),
          errorText: _error,
        ),
        onSubmitted: (_) => _guardar(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}
