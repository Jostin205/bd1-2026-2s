# TEC · Tecnológico de Costa Rica

## Escuela de Computación · Sede San Carlos

### IC-4301 · Bases de Datos I · II Semestre 2026

---

# Laboratorio 3: Del modelo lógico a la implementación física

## Grupo 01

### Caso: Clínica Los Robles (Proyecto 1 \- v2.1)

**Subproceso:** Atención médica, diagnóstico y tratamiento clínico

**Profesor:**  
Jonathan Cortés Seas

**Estudiantes:**

* Joan Steven Cordero Coto (2024156580)  
* Jason René Martínez Gutiérrez (2025105665)

**Fecha de entrega:**  
Octubre de 2026

---

## Control de Cambios: Transición y Sincronización con el Proyecto 1 (v2.1)

En atención a las observaciones y correcciones formales indicadas por el profesor en la evaluación de los entregables del Proyecto 1, se aplicaron ajustes al subproceso seleccionado de **Atención médica, diagnóstico y tratamiento clínico**:

1. **Inclusión de atributos temporales y pautas en `TRATAMIENTO` (RN-25):**  
     
   * **Cambio:** Se incorporaron formalmente las columnas `fecha_inicio_prevista` (obligatoria), `fecha_fin_prevista` (opcional con validación de secuencia), `instrucciones` (`NOT NULL`), `dosis`, `frecuencia` y `cantidad_sesiones`.  
   * **Justificación:** Cumplir con la especificación del caso sobre la delimitación temporal del tratamiento y evitar omisiones respecto a las indicaciones médicas.

   

2. **Trazabilidad de sustitución médica y estados del tratamiento (RN-26, S-15):**  
     
   * **Cambio:** Se definió la clave foránea recursiva `id_tratamiento_sustituido` con restricción de unicidad (`UNIQUE`) y dominio cerrado para `estado_actual` (`Planificado`, `Iniciado`, `Completado`, `Suspendido`, `Sustituido`).  
   * **Justificación:** Preservar la cardinalidad 1:1 en el reemplazo de indicaciones clínicas y permitir la trazabilidad histórica de los tratamientos sin sobrescribir información.

   

3. **Inmutabilidad y versionado de observaciones clínicas (RN-19, S-13):**  
     
   * **Cambio:** Se unificó el atributo temporal como `fecha_hora_registro` y se conservó la clave primaria compuesta (`id_consulta`, `consecutivo_observacion`, `num_version`) junto con el indicador `es_vigente`.  
   * **Justificación:** Garantizar que las correcciones o adiciones a las notas de examen físico generen nuevas revisiones sin alterar el expediente original.

   

4. **Respaldo formal de dominios cerrados (S-16):**  
     
   * **Cambio:** Se implementaron restricciones declarativas `CHECK` nativas para categorías diagnósticas (`Principal`, `Secundario`), condiciones (`Presuntivo`, `Confirmado`, `Descartado`) y tipos de tratamiento (`Medicamento`, `Procedimiento`, `Indicación`, `Recomendación`).  
   * **Justificación:** Proveer respaldo explícito a los dominios operativos cerrados utilizados por el modelo relacional.

---

# A1. Trazabilidad entre el modelo lógico y el diseño físico

## 1\. Fragmento del modelo lógico utilizado

El subsistema seleccionado corresponde al proceso de **Atención médica, diagnóstico y tratamiento clínico** de la Clínica Los Robles, definido a partir de los macroprocesos PR-04 y PR-05 del Proyecto 1\.

Este subsistema comprende seis relaciones del modelo lógico original, que permiten registrar las consultas realizadas, las observaciones clínicas versionadas, los diagnósticos identificados y los tratamientos prescritos.

**Relaciones seleccionadas:**

1. **CONSULTA** (`id_consulta`, `id_paciente`, `id_medico`, `id_cita`, `fecha_hora_inicio`, `motivo_clinico`, `resumen_general`).  
2. **OBSERVACION\_CLINICA** (`id_consulta`, `consecutivo_observacion`, `num_version`, `contenido_observacion`, `fecha_hora_registro`, `es_vigente`).  
3. **DIAGNOSTICO** (`codigo_diagnostico`, `descripcion_diagnostico`).  
4. **CONSULTA\_DIAGNOSTICO\_NM** (`id_consulta`, `codigo_diagnostico`, `tipo_categoria`, `condicion`).  
5. **TRATAMIENTO** (`id_tratamiento`, `id_consulta`, `id_tratamiento_sustituido`, `tipo_tratamiento`, `instrucciones`, `fecha_inicio_prevista`, `fecha_fin_prevista`, `estado_actual`, `dosis`, `frecuencia`, `cantidad_sesiones`).  
6. **TRATAMIENTO\_DIAGNOSTICO\_NM** (`id_tratamiento`, `codigo_diagnostico`).

**Cardinalidades conservadas:**

* CONSULTA → OBSERVACION\_CLINICA: 1:N.  
* CONSULTA → TRATAMIENTO: 1:N.  
* CONSULTA ↔ DIAGNOSTICO: N:M, mediante CONSULTA\_DIAGNOSTICO\_NM.  
* TRATAMIENTO ↔ DIAGNOSTICO: N:M, mediante TRATAMIENTO\_DIAGNOSTICO\_NM.  
* TRATAMIENTO → TRATAMIENTO: relación recursiva 1:1 opcional, para registrar sustituciones.

Además, CONSULTA conserva sus referencias obligatorias a PACIENTE y MEDICO y su referencia opcional a CITA, según las reglas RN-16 y RN-17.

## 2\. Matriz de trazabilidad lógico-física

La siguiente matriz establece la correspondencia entre las relaciones del Proyecto 1 y las tablas físicas creadas en PostgreSQL.

**Convenciones:** PK \= clave primaria; FK \= clave foránea; NN \= NOT NULL; UQ \= UNIQUE; CK \= CHECK.

| Relación lógica | Tabla física | Clave primaria | Claves foráneas | Restricciones relevantes | Justificación de cambios |
| :---- | :---- | :---- | :---- | :---- | :---- |
| CONSULTA | `consulta` | `id_consulta` | `id_paciente` (lógica); `id_medico` (lógica); `id_cita` (lógica) | NN para paciente, médico, fecha de inicio, motivo y resumen. `id_cita` admite NULL y es UQ. | Se conserva la estructura del Proyecto 1\. Por el límite del proceso, `id_paciente` e `id_medico` se mantienen como enteros obligatorios (RN-17) y `id_cita` único anulable (RN-16). |
| OBSERVACION\_CLINICA | `observacion_clinica` | (`id_consulta`, `consecutivo_observacion`, `num_version`) | `id_consulta` → CONSULTA | NN en atributos obligatorios; CK `num_version >= 1`. | Se mantiene la PK compuesta y el versionado histórico inmutable definido en RN-19 y S-13. |
| DIAGNOSTICO | `diagnostico` | `codigo_diagnostico` | Ninguna | NN en código y descripción. Código único mediante PK. | Sin cambios estructurales. Se conserva el catálogo estandarizado de patologías (CIE-10). |
| CONSULTA\_DIAGNOSTICO\_NM | `consulta_diagnostico_nm` | (`id_consulta`, `codigo_diagnostico`) | `id_consulta` → CONSULTA; `codigo_diagnostico` → DIAGNOSTICO | NN en ambas FK, `tipo_categoria` y `condicion`. CK de los dominios permitidos. | Sin cambios. Materializa la relación N:M y conserva la clasificación clínica de cada diagnóstico (RN-20). |
| TRATAMIENTO | `tratamiento` | `id_tratamiento` | `id_consulta` → CONSULTA; `id_tratamiento_sustituido` → TRATAMIENTO | NN en consulta, tipo, instrucciones, inicio previsto y estado. UQ y NULL permitidos en la FK recursiva. CK de fechas, tipos y estados. | Sin cambios de cardinalidad. Se conserva la sustitución 1:1 opcional y las fechas incorporadas en la versión corregida del Proyecto 1 (RN-25, RN-26). |
| TRATAMIENTO\_DIAGNOSTICO\_NM | `tratamiento_diagnostico_nm` | (`id_tratamiento`, `codigo_diagnostico`) | `id_tratamiento` → TRATAMIENTO; `codigo_diagnostico` → DIAGNOSTICO | Ambas FK son NN. La PK compuesta impide duplicar la asociación. | Sin cambios. Materializa la relación N:M entre tratamientos e indicaciones con los diagnósticos abordados (RN-21). |

## 3\. Justificación de las decisiones de diseño físico

La transformación del modelo lógico al físico mantiene los nombres, identificadores y cardinalidades definidos en el Proyecto 1\.

Las decisiones principales son:

* **Conservación de las claves compuestas:** Las tablas `observacion_clinica`, `consulta_diagnostico_nm` y `tratamiento_diagnostico_nm` mantienen sus identificadores originales compuestos, evitando introducir claves artificiales innecesarias.  
* **Integridad de las relaciones:** Las asociaciones 1:N se representan mediante claves foráneas con reglas `ON DELETE RESTRICT` y `ON UPDATE CASCADE` para proteger la inmutabilidad de la información médica.  
* **Versionado clínico inmutable:** `observacion_clinica` conserva `num_version` y `es_vigente`, de acuerdo con RN-19 y S-13, garantizando que una corrección no sobrescriba la nota previa.  
* **Sustitución de tratamientos:** `tratamiento` conserva `id_tratamiento_sustituido` como clave foránea recursiva, opcional y única (`UQ`), de acuerdo con RN-26 y S-15.  
* **Restricciones de dominio:** Los valores permitidos para categorías diagnósticas, condiciones, tipos de tratamiento y estados se conservan mediante restricciones `CHECK` nativas de PostgreSQL, siguiendo las reglas RN-20, RN-25, RN-26 y el supuesto S-16.

## 4\. Dependencias externas y limitaciones

El subsistema clínico depende conceptualmente de las relaciones PACIENTE, MEDICO y CITA, pertenecientes a otros procesos de la clínica (admisión y agendamiento). Siguiendo las pautas de la Sección 3 del README del laboratorio:

* `id_paciente` e `id_medico` se definen como `INTEGER NOT NULL`, modelando fielmente la regla RN-17 sin acarrear tablas auxiliares extensas.  
* `id_cita` se conserva como `INTEGER UNIQUE NULL`, permitiendo reflejar atenciones de urgencia (RN-16).

---

# B1. Datos representativos (7 puntos)

### Descripción de la carga de datos

Para comprobar el funcionamiento del subsistema se elaboró el archivo `02_datos.sql`, que contiene un conjunto de 24 registros ficticios distribuidos entre las seis tablas seleccionadas del Proyecto 1\.

### Distribución de los datos

| Tabla | Cantidad de registros | Propósito |
| :---- | ----: | :---- |
| `diagnostico` | 3 | Registrar un catálogo de diagnósticos médicos estandarizados (CIE-10). |
| `consulta` | 3 | Representar consultas programadas, urgencias y consultas de control. |
| `observacion_clinica` | 5 | Demostrar el registro de observaciones y la conservación de versiones anteriores. |
| `consulta_diagnostico_nm` | 4 | Asociar diagnósticos con consultas y establecer su categoría y condición clínica. |
| `tratamiento` | 4 | Registrar indicaciones terapéuticas, fechas previstas, estados y sustituciones. |
| `tratamiento_diagnostico_nm` | 5 | Representar la relación muchos a muchos entre tratamientos y diagnósticos. |
| **Total** | **24** | **Conjunto de datos representativo del subproceso clínico.** |

### Escenarios de negocio representados

1. **Consultas programadas y atención de urgencia (RN-16 y RN-17):** Tres consultas médicas (dos asociadas a citas previas y una por urgencias con `id_cita = NULL`).  
2. **Registro y corrección de notas clínicas (RN-19 y S-13):** Registro de evolución con dos versiones para una misma nota (versión 1 con `es_vigente = FALSE` y versión 2 con `es_vigente = TRUE`).  
3. **Clasificación diagnóstica (RN-20):** Diagnósticos categorizados como principales y secundarios, presuntivos y confirmados.  
4. **Prescripción y sustitución terapéutica (RN-21, RN-25 y RN-26):** Tratamientos con dosificación, frecuencia y sesiones; el tratamiento 7002 sustituye al tratamiento 7001 mediante `id_tratamiento_sustituido`.  
5. **Asociación tratamiento-diagnóstico (RN-21):** Mapeo de tratamientos dirigidos a múltiples diagnósticos y viceversa.

---

# B2. Consultas de negocio (6 puntos)

Se elaboró el archivo `03_consultas.sql` con cuatro consultas SQL orientadas a responder preguntas clínicas y analíticas:

* **Q01. Diagnósticos registrados por consulta (RN-20):** `INNER JOIN` entre `consulta`, `consulta_diagnostico_nm` y `diagnostico` para desplegar el cuadro clínico completo de cada atención.  
* **Q02. Cantidad y clasificación de diagnósticos por consulta (RN-20):** Consulta con agregación (`COUNT`, `SUM` condicional y `GROUP BY`) con `LEFT JOIN` para contabilizar diagnósticos principales y secundarios.  
* **Q03. Historial de sustitución de tratamientos (RN-26):** Operación de `SELF JOIN` sobre `tratamiento` para rastrear la indicación anterior y la que la reemplaza junto con sus estados.  
* **Q04. Observaciones clínicas vigentes (RN-19, S-13):** Filtrado selectivo (`WHERE es_vigente = TRUE`) para desplegar únicamente las versiones activas de las notas clínicas.

---

# B3. Pruebas de integridad (7 puntos)

Para verificar el cumplimiento de las reglas del modelo se diseñó el archivo `05_pruebas.sql`, compuesto por ocho pruebas estructuradas dentro de un bloque transaccional autónomo con captura de excepciones:

| ID | Precondición | Sentencia de prueba | Restricción evaluada | Resultado esperado |
| :---- | :---- | :---- | :---- | :---- |
| **P01** | ID 5099 disponible. | `INSERT` en `consulta` con `id_cita = NULL`. | RN-16 (Urgencias) | Aceptación exitosa. |
| **P02** | Consulta 5099 creada en P01. | `INSERT` en `observacion_clinica` con versión 1\. | RN-19 (Nota inicial) | Aceptación exitosa. |
| **P03** | Consulta 5099 creada; ID 7099 disponible. | `INSERT` en `tratamiento` con fechas y sesiones válidas. | RN-21, RN-25 | Aceptación exitosa. |
| **P04** | Diagnóstico 'J00' ya existente. | `INSERT` en `diagnostico` con código repetido. | `pk_diagnostico` | Rechazo por PK duplicada. |
| **P05** | No existe la consulta 999999\. | `INSERT` en `observacion_clinica` hacia consulta inexistente. | `fk_observacion_consulta` | Rechazo por FK inexistente. |
| **P06** | Consulta 5099 existente. | `INSERT` en `observacion_clinica` con `num_version = 0`. | `ck_observacion_version_positiva` | Rechazo por violación CHECK. |
| **P07** | Consulta 5099 existente; ID 7098 disponible. | `INSERT` en `tratamiento` con estado `'Activo'`. | `ck_tratamiento_estado` | Rechazo por valor fuera de dominio. |
| **P08** | ID 5098 disponible. | `INSERT` en `consulta` con `id_medico = NULL`. | `consulta.id_medico NOT NULL` | Rechazo por violación NOT NULL. |

---

# C. Programación almacenada (25 puntos)

Se implementaron cuatro rutinas en PL/pgSQL en el archivo `04_rutinas.sql`:

### C1. Funciones en PL/pgSQL (8 puntos)

1. **`fn_calcular_dias_tratamiento(p_id_tratamiento INTEGER)` (Cálculo/Respuesta útil):**  
   * **Regla:** RN-25.  
   * **Propósito:** Calcula la duración neta en días calendario de una prescripción a partir de sus fechas previstas. Retorna `NULL` si el tratamiento es indefinido y eleva una excepción si el ID no existe.  
2. **`fn_determinar_prioridad_consulta(p_id_consulta INTEGER)` (Decisión de negocio):**  
   * **Reglas:** RN-20 y RN-21.  
   * **Propósito:** Clasifica la atención médica en `'ALTA'`, `'MEDIA'` o `'BAJA'` evaluando si existen diagnósticos principales confirmados y prescripciones múltiples mediante estructuras `IF-ELSIF-ELSE`.

### C2. Procedimiento almacenado de negocio (10 puntos)

* **`sp_sustituir_tratamiento(...)`:**  
  * **Regla:** RN-26 y supuesto S-15.  
  * **Validaciones:** Verifica existencia del tratamiento anterior, que no esté en un estado final (`'Suspendido'`, `'Sustituido'`, `'Completado'`), que no haya sido relevado previamente (`uq_tratamiento_sustituido`) y la coherencia cronológica de inicio.  
  * **Operación:** Pasa el tratamiento anterior a estado `'Sustituido'`, inserta el nuevo tratamiento con la FK recursiva y hereda automáticamente los diagnósticos asociados en `tratamiento_diagnostico_nm` (RN-21).

### C3. Técnica procedimental adicional (7 puntos)

* **`fn_auditar_evolucion_consulta_cursor(p_id_consulta INTEGER)` (Cursor Explícito):**  
  * **Técnica:** Cursor explícito de PostgreSQL (`OPEN`, `FETCH`, `CLOSE`).  
  * **Propósito:** Itera de manera secuencial a lo largo de las revisiones de notas de evolución (RN-19), compilando un reporte de auditoría clínica estructurado.  
  * **Discusión técnica:** Se incluye en la documentación y en el código la comparación con la alternativa basada en conjuntos (`STRING_AGG`), justificando el uso del cursor con fines didácticos para control de flujo procedimental.

---

# D. Documentación y defensa técnica (30 puntos)

### D1. Instrucciones de ejecución y reproducibilidad del entorno

* **Motor requerido:** PostgreSQL 14 o superior.  
* **Herramientas cliente:** `psql` (CLI oficial) o DBeaver.  
* **Orden de ejecución obligatorio (entorno limpio):**

```
01_esquema.sql  -->  02_datos.sql  -->  04_rutinas.sql  -->  03_consultas.sql  -->  05_pruebas.sql
```

#### Guía de preparación del entorno con Docker:

1. **Creación local del archivo de configuración Docker Compose:**

Debido a que las restricciones de entrega del repositorio únicamente permiten archivos con extensiones específicas (`.md`, `.sql`, `.pdf`, `.png`, `.jpg`, `.jpeg`) y prohíben explícitamente la inclusión de archivos `.yaml` / `.yml`, el evaluador o usuario debe crear manualmente un archivo denominado `docker-compose.yml` (o `compose.yaml`) en la raíz de su espacio de trabajo e incluir el siguiente contenido:

```
services:
  db:
    image: postgres:17
    container_name: clinica-postgres
    restart: always
    environment:
      POSTGRES_DB: ClinicaLosRobles
      POSTGRES_USER: Admin
      POSTGRES_PASSWORD: LAB3
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

2. **Levantar el contenedor de PostgreSQL:**

Una vez creado y guardado el archivo `docker-compose.yml` en la raíz, ejecute el siguiente comando para levantar el servicio:

```sh
docker compose up -d
```

3. **Ejecutar los scripts en orden secuencial:**  
     
   * **En entornos Linux / macOS / Git Bash:**

```sh
# 1. Esquema DDL con restricciones nativas (A2, A3)
docker exec -i clinica-postgres psql -U Admin -d ClinicaLosRobles < sql/01_esquema.sql

# 2. Carga del set de 24 datos representativos (B1)
docker exec -i clinica-postgres psql -U Admin -d ClinicaLosRobles < sql/02_datos.sql

# 3. Compilación de funciones, procedimiento y cursor (C1, C2, C3)
docker exec -i clinica-postgres psql -U Admin -d ClinicaLosRobles < sql/04_rutinas.sql

# 4. Consultas analíticas y de negocio Q01 a Q04 (B2)
docker exec -i clinica-postgres psql -U Admin -d ClinicaLosRobles < sql/03_consultas.sql

# 5. Suite de pruebas transaccionales P01 a P08 (B3)
docker exec -i clinica-postgres psql -U Admin -d ClinicaLosRobles < sql/05_pruebas.sql
```

   * **En Windows PowerShell:**

```
# 1. Esquema DDL con restricciones nativas (A2, A3)
Get-Content sql/01_esquema.sql | docker exec -i clinica-postgres psql -U Admin -d ClinicaLosRobles

# 2. Carga del set de 24 datos representativos (B1)
Get-Content sql/02_datos.sql | docker exec -i clinica-postgres psql -U Admin -d ClinicaLosRobles

# 3. Compilación de funciones, procedimiento y cursor (C1, C2, C3)
Get-Content sql/04_rutinas.sql | docker exec -i clinica-postgres psql -U Admin -d ClinicaLosRobles

# 4. Consultas analíticas y de negocio Q01 a Q04 (B2)
Get-Content sql/03_consultas.sql | docker exec -i clinica-postgres psql -U Admin -d ClinicaLosRobles

# 5. Suite de pruebas transaccionales P01 a P08 (B3)
Get-Content sql/05_pruebas.sql | docker exec -i clinica-postgres psql -U Admin -d ClinicaLosRobles
```

### D2. Evidencias de ejecución

Los resultados de ejecución, tablas de salida y trazas de excepción capturadas durante la ejecución de las consultas y pruebas se encuentran detallados en el archivo `evidencias/resultados.md`.

### D3. Enlaces a los videos de defensa individual

Conforme a las directrices de la Sección 4 (D3) del laboratorio (toma continua sin cortes, cámara visible y pantalla compartida durante la ejecución de las pruebas):

| Integrante | Rol / Componentes expuestos | Enlace al video de defensa |
| :---- | :---- | :---- |
| **Joan Steven Cordero Coto** | Transformación de modelo lógico a físico, restricciones declarativas, procedimiento `sp_sustituir_tratamiento` y pruebas de rechazo P04/P07. | [Enlace al video de Joan Cordero](https://drive.google.com/...) |
| **Jason René Martínez Gutiérrez** | Versionado inmutable de observaciones clínicas, cursor explícito, consultas agregadas Q02/Q03 y pruebas de integridad P01/P06. | [Enlace al video de Jason Martínez](https://drive.google.com/...) |

