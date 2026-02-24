# Análisis de vulnerabilidades - APV Backend & Frontend

**Fecha:** 2026  
**Alcance:** Backend FastAPI, Frontend Flutter, configuración y dependencias.

---

## Resumen ejecutivo

| Severidad | Cantidad | Descripción |
|-----------|----------|-------------|
| Alta      | 1        | CORS permisivo en producción |
| Media     | 3        | Sin rate limiting, URL API en claro, posibles DoS por inputs |
| Baja      | 2        | Límites de validación, logging de datos |

---

## 1. CORS demasiado permisivo (Alta)

**Ubicación:** `app/main.py`

```python
cors_origins = os.environ.get("CORS_ORIGINS", "*")
allow_origins = [o.strip() for o in cors_origins.split(",")] if cors_origins != "*" else ["*"]
# ...
allow_credentials=True,
allow_methods=["*"],
allow_headers=["*"],
```

**Riesgo:** Si `CORS_ORIGINS` no se configura en producción, cualquier origen (`*`) puede hacer peticiones con credenciales. Eso facilita ataques desde sitios maliciosos que suplantan al usuario.

**Recomendación:**
- En producción, **no** usar `*`. Definir explícitamente los orígenes permitidos (ej. `https://tu-dominio.com`).
- Ajustar `allow_methods` y `allow_headers` al mínimo necesario.

---

## 2. Sin rate limiting (Media)

**Ubicación:** Todos los endpoints en `app/api/routes.py`

**Riesgo:** Un atacante puede enviar muchas peticiones por segundo (p. ej. a `/simulate/apv` o `/parametros`) y provocar:
- Consumo excesivo de CPU/memoria.
- Abuso del servicio externo mindicador.cl (en `refresh_indicadores`).
- Degradación del servicio para usuarios legítimos.

**Recomendación:**
- Añadir rate limiting (p. ej. `slowapi` o middleware con Redis) por IP y/o por usuario si hubiera autenticación.
- Límites distintos para endpoints pesados (simulación) y ligeros (parametros).

---

## 3. URL del API en claro en el frontend (Media)

**Ubicación:** `frontend/lib/core/api_client.dart`

```dart
const _baseUrl = 'http://127.0.0.1:8000/api/v1';
```

**Riesgo:**
- En producción la app debe apuntar al backend real; si se despliega sin cambiar la URL, la app no funcionará o seguirá usando desarrollo.
- Uso de `http://` (no HTTPS) en producción implica tráfico sin cifrar y exposición de datos (p. ej. montos, edades).

**Recomendación:**
- Usar variables de entorno o build flavors (p. ej. `--dart-define=API_BASE=https://api.tudominio.com`) para la URL base.
- En producción usar siempre `https://` y certificados válidos.

---

## 4. Posible DoS por inputs extremos (Media)

**Ubicación:** `app/models/schemas.py`, `app/services/proyeccion.py`

**Observaciones:**
- `UserInput.sueldo_bruto_mensual`: `gt=0`, sin tope. Valores muy grandes (p. ej. 1e15) no provocan fallo pero generan respuestas grandes y más uso de CPU.
- `UserInput.ahorro_mensual_apv` y `ahorro_mensual_normal`: `ge=0`, sin tope.
- `ProyeccionRequest.meses`: limitado a `le=600` (50 años), lo cual es razonable.
- `proyectar_jubilacion_anual`: el número de años es `edad_jubilacion - edad_actual` (máx. 62 con rangos 18–80). Tamaño de lista acotado.

**Riesgo:** Menor que un DoS clásico, pero inputs muy grandes pueden aumentar tiempo de respuesta y tamaño de JSON (p. ej. en `/simulate/apv`).

**Recomendación:**
- Añadir límites superiores realistas (p. ej. sueldo ≤ 500 M, aportes ≤ 50 M) en los schemas de Pydantic.
- Opcional: limitar tamaño del body (FastAPI/Starlette) y tiempo máximo de respuesta.

---

## 5. Validación de coherencia edad (Baja)

**Ubicación:** `app/models/schemas.py` – `UserInput`

**Riesgo:** Se permite `edad_jubilacion <= edad_actual` (p. ej. jubilación 60, edad actual 65). La lógica devuelve listas vacías o cero meses; no hay fallo, pero la API podría rechazar con un mensaje claro.

**Recomendación:** Añadir un validador de Pydantic: `edad_jubilacion > edad_actual`.

---

## 6. Dependencias (Baja)

**Ubicación:** `requirements.txt`

**Observación:** No se fijan versiones exactas (p. ej. `fastapi>=0.100`). Dependencias actualizadas pueden introducir vulnerabilidades conocidas.

**Recomendación:**
- Revisar periódicamente con `pip audit` o `safety check`.
- Fijar versiones en producción (lock file o `pip freeze`) y actualizar de forma controlada.

---

## 7. Servicio externo mindicador.cl (Baja)

**Ubicación:** `app/services/indicadores.py`

**Observaciones:**
- URL fija a `https://mindicador.cl/api`; no hay inyección de URL.
- Timeout de 10 s y manejo de excepciones; fallback a valores por defecto.
- No se reenvían datos de usuario a mindicador; solo se pide UF/UTM.

**Riesgo:** Si mindicador.cl fuera comprometido o devolviera datos maliciosos, el único impacto sería UF/UTM incorrectos en cálculos. No hay ejecución de código ni exposición de datos sensibles.

**Recomendación:** Mantener timeout y fallback; opcionalmente validar rango razonable de UF/UTM antes de actualizar la caché.

---

## 8. Ausencia de autenticación y datos sensibles

**Estado actual:** La API es pública; no hay login ni tokens. Los datos enviados (sueldo, edad, aportes) son sensibles pero no se persisten.

**Riesgo:** Cualquier persona que tenga acceso al backend (o al tráfico si no hay HTTPS) puede ver o enviar simulaciones. No hay confidencialidad por usuario.

**Recomendación:** Si en el futuro se almacenan datos o se asocian a usuarios, añadir autenticación (JWT, OAuth, etc.) y autorización, y seguir usando HTTPS.

---

## Checklist de mitigación

- [x] Configurar `CORS_ORIGINS` en producción con orígenes concretos (no `*`). Si `ENV=production` y no se define, no se acepta ningún origen.
- [x] Añadir rate limiting a la API (slowapi: 20/min en simulate, 30/min en parametros, 40/min en el resto; health/ready exentos).
- [x] Definir URL del API en el frontend por entorno (HTTPS en producción). Usar `--dart-define=API_BASE=https://api.tudominio.com/api/v1` en build/run.
- [ ] Añadir topes a `sueldo_bruto_mensual`, `ahorro_mensual_apv` y `ahorro_mensual_normal` en Pydantic.
- [ ] Validar `edad_jubilacion > edad_actual` en `UserInput`.
- [ ] Ejecutar `pip audit` / `safety` de forma periódica y fijar dependencias en producción.
