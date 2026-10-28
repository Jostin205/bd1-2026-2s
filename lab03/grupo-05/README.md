# IC-4301  Bases de Datos I - Laboratorio 
### Grupo 05 — Proyecto Refugio Huellas Seguras

---

## 1. Descripción del Proceso de Negocio Seleccionado

Para este laboratorio, seleccionamos el **Subsistema de Salud y Tratamientos de Animales**, un módulo acotado y coherente derivado del proyecto *Huellas Seguras*. 

### Alcance del Subsistema
El subsistema administra el historial clínico completo desde la llegada del animal al refugio:
- **Evaluación e Historial Clínico:** Registro de la evaluación inicial y revisiones veterinarias periódicas.
- **Diagnósticos:** Asociación de diagnósticos estandarizados a cada revisión con su respectivo estado (`PROVISIONAL`, `CONFIRMADO`, `DESCARTADO`).
- **Indicaciones Médicas:** Asignación de tratamientos, medicamentos, vacunas, procedimientos o controles posteriores.
- **Aplicaciones y Sesiones:** Planificación y seguimiento de la ejecución de cada indicación médica, distinguiendo lo programado de lo efectivamente realizado.

---

## 2. Parte A — Del Modelo Lógico al Esquema Físico

### A1. Matriz de Trazabilidad

| Relación Lógica (Proyecto 1) | Tabla Física (PostgreSQL) | Clave Primaria (PK) | Claves Foráneas (FK) | Restricciones Relevantes (NN, UNIQUE, CHECK) | Justificación de Cambios / Diseño Físico |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **PERSONA** | `persona` | `id_persona` | Ninguna | `nombre_identificacion` (NULL) | Tabla maestra simplificada para registrar veterinarios y personal responsable de aplicaciones. |
| **ANIMAL** | `animal` | `codigo_interno` | Ninguna | `especie` (NN); `numero_microchip` (UQ, NULL); `edad_estimada` (CHECK >= 0) | Entidad central del refugio; conserva el código interno como PK estable a lo largo de su historia. |
| **EVALUACION_SALUD** | `evaluacion_salud` | `id_evaluacion` | `animal_codigo` ($\rightarrow$ `animal`)<br>`veterinario_id` ($\rightarrow$ `persona`) | `tipo_evaluacion` (NN, CHECK); `fecha_evaluacion` (NN); `peso` (CHECK > 0) | Agrupa evaluaciones iniciales y revisiones. Modela `veterinario_id` como FK opcional a nivel de esquema. |
| **DIAGNOSTICO** | `diagnostico` | `id_diagnostico` | Ninguna | `nombre_estandarizado` (NN, UQ) | Catálogo de condiciones médicas estandarizadas para evitar duplicidad de nombres. |
| **DIAGNOSTICO_REVISION** | `diagnostico_revision` | (`evaluacion_id`, `diagnostico_id`) | `evaluacion_id` ($\rightarrow$ `evaluacion_salud`)<br>`diagnostico_id` ($\rightarrow$ `diagnostico`) | `estado_diagnostico` (NN, CHECK: `PROVISIONAL`, `CONFIRMADO`, `DESCARTADO`) | Resuelve la relación M:N entre revisiones clínicas y diagnósticos, almacenando el estado de la condición. |
| **INDICACION** | `indicacion` | `id_indicacion` | `evaluacion_id` ($\rightarrow$ `evaluacion_salud`)<br>`indicacion_sustituida_id` ($\rightarrow$ `indicacion`) | `tipo_indicacion` (NN, CHECK); `descripcion` (NN) | Registra órdenes médicas originadas en una evaluación; permite autorreferencia para sustitución de indicaciones. |
| **APLICACION_INDICACION** | `aplicacion_indicacion` | `id_aplicacion` | `indicacion_id` ($\rightarrow$ `indicacion`)<br>`responsable_id` ($\rightarrow$ `persona`) | `fecha_planificada` (NN); `chk_aplicacion_realizada` (CHECK condicional) | Separa lo planificado de lo ejecutado. Exige fecha real, responsable y observaciones de forma conjunta al ejecutarse. |

---

### A2 & A3. Decisiones de Diseño Físico e Instrucciones de Ejecución

#### Entorno y Motor Requerido
- **Motor objetivo:** PostgreSQL 16.x.
- **Garantía de Reproducibilidad:** El script `sql/01_esquema.sql` se ejecuta sobre una base de datos totalmente vacía. No depende de objetos o tipos creados previamente de forma manual.

#### Orden de Ejecución Obligatorio
Para garantizar la integridad referencial y evitar fallos de dependencias, los scripts deben ejecutarse secuencialmente en el siguiente orden:

1. `sql/01_esquema.sql` — Creación de tablas, llaves, restricciones e índices.
2. `sql/02_datos.sql` — Carga inicial de datos ficticios de prueba.
3. `sql/04_rutinas.sql` — Creación de funciones y procedimientos PL/pgSQL.
4. `sql/03_consultas.sql` — Consultas de negocio.
5. `sql/05_pruebas.sql` — Pruebas de integridad y casos de borde.

#### Ejecución desde CLI (`psql`):
```bash
psql -U postgres -d huellas_seguras_lab3 -f sql/01_esquema.sql
psql -U postgres -d huellas_seguras_lab3 -f sql/02_datos.sql
psql -U postgres -d huellas_seguras_lab3 -f sql/04_rutinas.sql
psql -U postgres -d huellas_seguras_lab3 -f sql/03_consultas.sql
psql -U postgres -d huellas_seguras_lab3 -f sql/05_pruebas.sql
```

---

## 3. Parte B — Datos, Consultas e Integridad

### B1. Cobertura de Datos de Prueba (`02_datos.sql`)
El conjunto de datos ficticios incluye:
- **3 Personas:** Registradas para asumir roles de veterinario y personal responsable.
- **5 Animales:** Cobertura de diferentes especies, edades y microchips.
- **9 Evaluaciones de Salud:** 5 iniciales y 4 revisiones veterinarias.
- **4 Diagnósticos en Catálogo:** 6 asignaciones en `diagnostico_revision` probando estados `PROVISIONAL`, `CONFIRMADO` y `DESCARTADO`.
- **6 Indicaciones Médicas:** Incluye casos de indicación sustituida.
- **6 Aplicaciones:** Escenarios de sesiones ejecutadas, pendientes programadas y pendientes vencidas.

### B2. Consultas de Negocio (`03_consultas.sql`)

| ID | Pregunta de Negocio | Técnica Utilizada | Resultado Esperado |
| :--- | :--- | :--- | :--- |
| **Q01** | ¿Cuál es el historial clínico detallado del animal 'Luna' (`HS-001`)? | `JOIN` múltiple | Tres evaluaciones registradas; la inicial sin diagnóstico y la revisión con Otitis cambiando de `PROVISIONAL` a `DESCARTADO`. |
| **Q02** | ¿Qué aplicaciones médicas están pendientes al 27-10-2026? | Filtro y comparación de fechas | Tres aplicaciones: `HS-001` (vencida) y `HS-002` / `HS-003` (programadas). |
| **Q03** | ¿Cuántas revisiones veterinarias y diagnósticos confirmados tiene registrado cada animal? | Agregación (`GROUP BY`, `LEFT JOIN`, `COUNT`) | `HS-001`: 2 rev / 2 conf; `HS-002`: 1 rev / 1 conf; `HS-003`: 1 rev / 0 conf; `HS-004` y `HS-005`: 0 rev / 0 conf. |

### B3. Pruebas de Integridad (`05_pruebas.sql`)
El script ejecuta **8 pruebas aisladas** mediante transacciones (`BEGIN` ... `ROLLBACK`):
- **3 Casos Validos:** Inserción correcta de evaluación, diagnóstico y aplicación realizada.
- **5 Casos Rechazados:** Verificación de fallos por microchip duplicado, llave foránea inexistente, peso negativo, estado inválido de diagnóstico y omisión de responsable en aplicación realizada.

---

## 4. Parte C — Programación Almacenada (`04_rutinas.sql`)

### C1. Funciones PL/pgSQL

1. **`contar_revisiones_animal(p_codigo_animal VARCHAR)`**
   - **Propósito:** Retorna la cantidad (`INTEGER`) de revisiones veterinarias recibidas por un animal.
   - **Ejemplo:** `SELECT contar_revisiones_animal('HS-001');` $\rightarrow$ Devuelve `2`.

2. **`estado_aplicacion(p_id_aplicacion INTEGER)`**
   - **Propósito:** Evalúa el estado actual de una sesión. Retorna `REALIZADA` si posee `fecha_real`; `VENCIDA` si `fecha_planificada < CURRENT_DATE`; o `PROGRAMADA` en caso contrario. Lanza `RAISE EXCEPTION` si el ID no existe.
   - **Ejemplo:** `SELECT estado_aplicacion(2);` $\rightarrow$ Devuelve `VENCIDA`.

### C2. Procedimiento Almacenado

- **`registrar_aplicacion(p_id_aplicacion, p_fecha_real, p_responsable_id, p_observaciones)`**
  - **Propósito:** Registra la ejecución de una aplicación médica pendiente.
  - **Validaciones:** Bloquea la fila con `FOR UPDATE`, verifica la existencia de la aplicación, impide reejecutar sesiones ya realizadas y exige la presencia conjunta de fecha real, responsable u observaciones.
  - **Prueba Válida:** Ejecución exitosa para la aplicación #4 con fecha y responsable válidos.
  - **Prueba Rechazada:** Intento de registro enviando `p_responsable_id = NULL`, provocando `RAISE EXCEPTION 'Debe indicar fecha, responsable y observaciones'`.

### C3. Técnica Procedimental Adicional (Tabla Temporal)

- **`generar_reporte_pendientes()`**
  - **Técnica:** Utiliza `CREATE TEMP TABLE ... ON COMMIT PRESERVE ROWS` para generar la tabla temporal `reporte_pendientes`.
  - **Discusión vs. SQL Basado en Conjuntos:** Un `SELECT` directo con `JOIN` y `CASE` logra el mismo resultado de forma más limpia en ejecuciones puntuales. No obstante, la tabla temporal se justifica cuando el resultado debe ser consumido múltiples veces durante la misma sesión de trabajo sin reevaluar las uniones entre las tablas principales.

---

## 5. Parte D — Documentación, Limitaciones y Evidencias

### D1 & D2. Limitaciones y Evidencia de Ejecución
- **Entorno de Pruebas:** Las ejecuciones integradas iniciales se validaron con la herramienta PGlite/PostgreSQL 18.6, mientras que las rutinas PL/pgSQL fueron probadas individualmente en pgAdmin 4 con **PostgreSQL 16**.
- **Observaciones del Esquema:** Se identifica que el esquema declarativo actual no impone de forma estricta la presencia de un veterinario registrado para evaluaciones de tipo `REVISION_VETERINARIA`, aspecto que se proyecta automatizar mediante *triggers* en etapas futuras del curso.
- **Evidencias Completas:** Los resultados detallados de ejecución de consultas, pruebas de integridad y salidas de rutinas se encuentran documentados en [`evidencias/resultados.md`](evidencias/resultados.md).

---
