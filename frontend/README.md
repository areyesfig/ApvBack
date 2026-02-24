# Simulador APV Chile (Flutter)

App Flutter que consume el backend APV para simular ahorro previsional voluntario (Régimen A, B, Mix) y proyecciones a jubilación.

## Requisitos

- Flutter SDK ^3.5
- Backend corriendo en `http://127.0.0.1:8000` (o configurar `ApiClient` en `lib/core/api_client.dart`)

## Ejecutar

```bash
cd frontend
flutter pub get
flutter run
```

En dispositivo físico o producción, define la URL del API:

- **Desarrollo (mismo equipo):** por defecto usa `http://127.0.0.1:8000/api/v1`.
- **Dispositivo en red local:**  
  `flutter run --dart-define=API_BASE=http://192.168.1.x:8000/api/v1`
- **Producción (HTTPS):**  
  `flutter build apk --dart-define=API_BASE=https://api.tudominio.com/api/v1`

## Estructura

- **Paso 3.1**: `lib/state/simulation_provider.dart` — Riverpod + `SimulationNotifier` con debounce (500 ms).
- **Paso 3.2**: `lib/screens/input_screen.dart` — Sliders y selector de perfil de riesgo (Conservador 4%, Moderado 7%, Agresivo 10%).
- **Paso 3.3**: `lib/screens/chart_screen.dart` — Gráfico fl_chart: Colchón, ETF sin APV, APV.
- **Paso 3.4**: `lib/screens/fiscal_screen.dart` — Recibo “Operación Renta” y barras de progreso (600 UF, 6 UTM).
