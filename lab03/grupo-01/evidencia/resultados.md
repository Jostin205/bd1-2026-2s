# Evidencias de Ejecución — Laboratorio 3

**Curso:** IC-4301 · Bases de Datos I  
**Equipo:** Grupo 01 (Joan Cordero Coto, Jason Martínez Gutiérrez)  
**Caso:** Clínica Los Robles — Subsistema de Atención Médica Efectiva, Diagnóstico Clínico y Prescripción Terapéutica  
**Entorno de ejecución:** PostgreSQL 14+ sobre Docker Compose

---

## 1\. Ejecución de Consultas de Negocio (`03_consultas.sql`)

### Q01. Diagnósticos registrados por consulta

* **Pregunta de negocio:** ¿Qué diagnósticos se registraron en cada consulta médica, cuál es su categoría y condición clínica?  
* **Regla asociada:** RN-20  
* **Resultado observado:**

```
 id_consulta |  fecha_hora_inicio  | codigo_diagnostico |                      descripcion_diagnostico                       | tipo_categoria | condicion  
-------------+---------------------+--------------------+--------------------------------------------------------------------+----------------+------------
        5001 | 2026-10-10 09:35:00 | J06.9              | Infección aguda de vias respiratorias superiores, no especificada | Principal      | Confirmado
        5001 | 2026-10-10 09:35:00 | R50.9              | Fiebre, no especificada                                            | Secundario     | Confirmado
        5002 | 2026-10-11 14:15:00 | J06.9              | Infección aguda de vias respiratorias superiores, no especificada | Principal      | Presuntivo
        5003 | 2026-10-13 11:05:00 | J00                | Rinofaringitis aguda                                               | Principal      | Confirmado
(4 rows)
```

* **Conclusión:** Se comprueba el mapeo de la relación M:N entre consultas y el catálogo CIE-10, ordenando primero los diagnósticos principales sobre los secundarios.

---

### Q02. Cantidad y clasificación de diagnósticos por consulta

* **Pregunta de negocio:** ¿Cuántos diagnósticos principales y secundarios tiene registrada cada atención médica?  
* **Regla asociada:** RN-20  
* **Resultado observado:**

```
 id_consulta | total_diagnosticos | principales | secundarios 
-------------+--------------------+-------------+-------------
        5001 |                  2 |           1 |           1
        5002 |                  1 |           1 |           0
        5003 |                  1 |           1 |           0
(3 rows)
```

* **Conclusión:** La agregación condicional (`COUNT`, `SUM CASE`, `GROUP BY`) calcula fielmente la distribución de severidad diagnóstica por atención.

---

### Q03. Historial de sustitución de tratamientos

* **Pregunta de negocio:** ¿Qué tratamientos han sustituido a otros y cuál es el estado y fecha de inicio de ambos?  
* **Regla asociada:** RN-26  
* **Resultado observado:**

```
 id_consulta | tratamiento_anterior | tratamiento_nuevo | estado_anterior | estado_nuevo | inicio_anterior | inicio_nuevo 
-------------+----------------------+-------------------+-----------------+--------------+-----------------+--------------
        5001 |                 7001 |              7002 | Sustituido      | Iniciado     | 2026-10-10      | 2026-10-11
(1 row)
```

* **Conclusión:** El `SELF JOIN` sobre la clave foránea recursiva `id_tratamiento_sustituido` evidencia la trazabilidad histórica sin pérdida de la indicación médica previa.

---

### Q04. Observaciones clínicas vigentes

* **Pregunta de negocio:** ¿Cuáles son las versiones vigentes de las observaciones registradas en cada consulta?  
* **Reglas asociadas:** RN-19 y S-13  
* **Resultado observado:**

```
 id_consulta | consecutivo_observacion | num_version |                contenido_observacion                | fecha_hora_registro 
-------------+-------------------------+-------------+-----------------------------------------------------+---------------------
        5001 |                       1 |           2 | Se corrige la medicion: temperatura de 38.2 grados. | 2026-10-10 09:50:00
        5001 |                       2 |           1 | Paciente presenta irritacion leve de garganta.      | 2026-10-10 09:55:00
        5002 |                       1 |           1 | Paciente presenta dificultad respiratoria leve.     | 2026-10-11 14:20:00
        5003 |                       1 |           1 | Paciente presenta mejoria de los sintomas.          | 2026-10-13 11:10:00
(4 rows)
```

* **Conclusión:** Se visualiza la versión vigente (versión 2\) de la nota 1 en la consulta 5001, preservando inmutable la versión 1 en la base de datos física.

---

## 2\. Pruebas de Integridad (`05_pruebas.sql`)

### Resumen global de ejecución

* **Transacción:** Ejecutada en bloque autónomo y revertida con `ROLLBACK` (datos base de B1 intactos).  
* **Métricas:** 8 pruebas totales \| 8 cumplidas \| 0 no cumplidas.

```
 pruebas_totales | cumplen | no_cumplen 
-----------------+---------+------------
               8 |       8 |          0
(1 row)
```

### Detalle por identificador de prueba

| ID | Descripción de la prueba | Resultado esperado | Resultado observado | Conclusión |
| :---- | :---- | :---- | :---- | :---: |
| **P01** | Consulta de urgencia sin cita previa | Aceptación | INSERT aceptado | **CUMPLE** |
| **P02** | Observación versión 1 con FK válida | Aceptación | INSERT aceptado | **CUMPLE** |
| **P03** | Tratamiento con fechas y sesiones válidas | Aceptación | INSERT aceptado | **CUMPLE** |
| **P04** | Código de diagnóstico duplicado | Rechazo por PK | Rechazado por pk\_diagnostico | **CUMPLE** |
| **P05** | Observación con consulta inexistente | Rechazo por FK | Rechazado por fk\_observacion\_consulta | **CUMPLE** |
| **P06** | Versión de observación igual a cero | Rechazo por CHECK | Rechazado por ck\_observacion\_version\_positiva | **CUMPLE** |
| **P07** | Estado de tratamiento no permitido | Rechazo por CHECK | Rechazado por ck\_tratamiento\_estado | **CUMPLE** |
| **P08** | Consulta sin médico responsable | Rechazo por NOT NULL | Rechazado por columna id\_medico | **CUMPLE** |

