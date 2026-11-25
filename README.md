# Gestor de tareas con SQLite

Práctica de la materia de Programación de Dispositivos Móviles.

## Descripción

Esta aplicación fue desarrollada en Flutter y permite administrar tareas utilizando una base de datos local SQLite con Drift. El objetivo de la práctica es que los datos se mantengan guardados incluso después de cerrar la aplicación.

## Funcionalidades

- Agregar tareas.
- Consultar las tareas registradas.
- Editar tareas.
- Marcar tareas como completadas.
- Eliminar tareas.
- Guardar los datos de manera local.

## Tecnologías utilizadas

- Flutter
- Dart
- SQLite
- Drift

## Ejecución del proyecto

Primero se deben instalar las dependencias:

```
flutter pub get
```

Para ejecutar la aplicación en web:

```
flutter run -d chrome
```

Para ejecutar en escritorio:

```
flutter run -d windows
```

Para ejecutar en un dispositivo móvil:

```
flutter devices
flutter run
```

## Pruebas

Para ejecutar las pruebas del proyecto:

```
flutter test
```

## Conclusión

Con esta práctica se busca comprender cómo implementar una base de datos local en Flutter, realizar las operaciones CRUD y mantener la información guardada después de cerrar la aplicación.

Durante el desarrollo se utilizó asistencia de IA como herramienta de apoyo.
