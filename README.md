# Gestor de tareas con SQLite (Flutter + Drift)

Aplicación Flutter que administra tareas en una **base de datos SQLite local**, sin servidor ni conexión a internet.
Un solo código base para Android, iOS, Windows, Linux, macOS y web. Práctica de *Programación de Dispositivos Móviles*, UAA.

## Funcionalidades

| ID | Funcionalidad | Implementación |
|----|---------------|----------------|
| F1 | Alta | `insertarTarea()`: `INSERT`. Rechaza títulos vacíos o de solo espacios (`validarTitulo`). |
| F2 | Consulta | `watchTareas()`: `SELECT ... ORDER BY id`, consulta reactiva (`Stream`). |
| F3 | Edición del título | `actualizarTitulo()`: `UPDATE ... WHERE id = ?` |
| F4 | Completada / pendiente | `actualizarEstado()`: `UPDATE ... WHERE id = ?` |
| F5 | Eliminación por id | `eliminarTarea()`: `DELETE ... WHERE id = ?` (pide confirmación) |
| F6 | Sin conexión | SQLite local; no hay peticiones HTTP. |
| F7 | Multiplataforma | `drift_flutter` (`driftDatabase`): nativo con `sqlite3`, web con WebAssembly. |
| F8 | Calidad | Errores mostrados con SnackBar. La consulta se crea en `initState`, no en `build()`. La base se cierra en `dispose()`. |

## Tecnología elegida y por qué

- **[Drift](https://drift.simonbinder.eu/)**: ORM sobre SQLite con consultas tipadas y *streams* reactivos, y soporte nativo + web.
- **[drift_flutter](https://pub.dev/packages/drift_flutter)**: con `driftDatabase(name: ...)` elige la ubicación correcta del archivo en cada plataforma y configura web (WASM + worker).
- **build_runner / drift_dev**: generan `lib/data/database.g.dart` (clases `Task`, `TasksCompanion`, etc.) a partir de la definición de la tabla.

Se descartó `sqflite` porque no funciona en web ni en escritorio sin paquetes extra.

## Estructura

```
lib/
  main.dart                 # Arranque; abre la base y la cierra en dispose()
  models/tarea.dart         # Modelo de UI (independiente de Drift)
  data/database.dart        # Tabla, conexión y operaciones CRUD + validación
  data/database.g.dart      # Generado por build_runner (no editar)
  screens/tareas_page.dart  # Interfaz
test/
  database_test.dart        # Validación, CRUD y persistencia en archivo
  widget_test.dart          # Pruebas de interfaz con base en memoria
tool/drift_worker.dart      # Fuente del worker web (se compila a web/drift_worker.js)
web/sqlite3.wasm            # SQLite compilado a WebAssembly
web/drift_worker.js         # Worker de Drift
```

### Esquema de la tabla `tasks`

| Columna | Tipo SQLite | Restricciones |
|---------|-------------|---------------|
| `id` | INTEGER | PRIMARY KEY AUTOINCREMENT |
| `title` | TEXT | NOT NULL (validado: 1–200 caracteres, sin espacios sobrantes) |
| `completed` | INTEGER (booleano 0/1) | NOT NULL DEFAULT 0, CHECK (completed IN (0,1)) |

## Cómo ejecutar

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # solo si cambias la tabla
flutter analyze
flutter test
flutter run -d chrome      # o: -d windows, -d <id de flutter devices>
```

> **Nota sobre la persistencia en web:** `flutter run -d chrome` abre Chrome con un **perfil temporal nuevo** en cada ejecución,
> así que los datos no se conservan entre dos `flutter run`. Recargar la pestaña (F5) sí los conserva.
> Para probar el cierre y la apertura del navegador hay que fijar el puerto y el perfil, por ejemplo:
> `flutter run -d chrome --web-port 8080 --web-browser-flag="--user-data-dir=C:/tmp/perfil-tareas"`,
> o compilar con `flutter build web` y servir `build/web` desde un puerto fijo.

### Recursos web (`web/sqlite3.wasm` y `web/drift_worker.js`)

Tienen que coincidir con las versiones de `pubspec.lock` (drift 2.35.4, sqlite3 3.5.2):

```bash
# Worker compilado con la misma versión de drift instalada:
dart compile js -O4 tool/drift_worker.dart -o web/drift_worker.js
# sqlite3.wasm de la versión del paquete sqlite3:
curl -L -o web/sqlite3.wasm https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-3.5.2/sqlite3.wasm
```

## Pruebas automatizadas (`flutter test`: 13 pruebas)

- `test/database_test.dart`
  - Validación: rechaza vacío o solo espacios (P5), rechaza títulos demasiado largos, recorta espacios.
  - CRUD en memoria: INSERT/SELECT ordenado, no inserta vacíos, UPDATE de título y estado, UPDATE inválido no modifica, DELETE e ids inexistentes, el *stream* reemite tras cada escritura.
  - **Persistencia real en archivo**: abre, escribe, cierra y reabre el mismo archivo `.sqlite` tres veces (P1–P4).
- `test/widget_test.dart`: pantalla inicial; título vacío no se registra (P5); flujo completo en la UI (agregar, completar, editar, eliminar) verificado contra la base.

## Plataformas

| Plataforma | Estado |
|------------|--------|
| Web (Chrome 157) | **Probada**: P1–P6 superadas. Drift usa `WasmStorageImplementation.sharedIndexedDb`. |
| Windows (escritorio) | Prevista. La misma capa SQLite nativa está cubierta por `flutter test`, que usa sqlite3 nativo en Windows. |
| Android, iOS, Linux, macOS | Previstas (mismo código). iOS y macOS requieren una Mac con Xcode; Linux requiere Linux. |

### Comprobación manual P1–P6 (web)

| ID | Acción | Resultado |
|----|--------|-----------|
| P1 | Agregar 3 tareas, cerrar Chrome y abrirlo | Permanecen las 3 ✔ |
| P2 | Marcar una como completada y recargar | Se conserva el estado ✔ |
| P3 | Cambiar un título, cerrar y abrir | Aparece el nuevo título ✔ |
| P4 | Eliminar una tarea, cerrar y abrir | No reaparece ✔ |
| P5 | Agregar un título vacío | No se registra; aparece un mensaje ✔ |
| P6 | Recargar y cerrar/abrir la pestaña (mismo origen y perfil) | Los datos permanecen ✔ |

## Dónde se guardan los datos

- **Android/iOS:** directorio de documentos/soporte de la app (`gestor_tareas.sqlite`). Se borra al desinstalar.
- **Escritorio:** directorio de soporte de la aplicación del usuario (vía `path_provider`).
- **Web:** almacenamiento del navegador (IndexedDB u OPFS) asociado al origen y al perfil. Se pierde al borrar los datos del sitio o al cerrar una ventana privada.
