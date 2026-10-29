-- Consultas de negocio. Ejecutar después de 02_datos.sql.
-- Las fechas de referencia son fijas para que los resultados sean reproducibles.

-- Q01. ¿Cuál es el historial de evaluaciones y diagnósticos de Luna?
-- Esperado: tres filas (evaluación inicial y dos revisiones); la evaluación
-- inicial no tiene diagnóstico, Otitis pasa de PROVISIONAL a DESCARTADO.
SELECT e.id_evaluacion, a.codigo_interno, a.nombre,
       e.fecha_evaluacion, e.tipo_evaluacion,
       p.nombre_identificacion AS veterinario,
       COALESCE(
           STRING_AGG(d.nombre_estandarizado || ' (' || dr.estado_diagnostico || ')',
                      ', ' ORDER BY d.nombre_estandarizado),
           'Sin diagnóstico'
       ) AS diagnosticos
FROM animal AS a
JOIN evaluacion_salud AS e ON e.animal_codigo = a.codigo_interno
LEFT JOIN persona AS p ON p.id_persona = e.veterinario_id
LEFT JOIN diagnostico_revision AS dr ON dr.evaluacion_id = e.id_evaluacion
LEFT JOIN diagnostico AS d ON d.id_diagnostico = dr.diagnostico_id
WHERE a.codigo_interno = 'HS-001'
GROUP BY e.id_evaluacion, a.codigo_interno, a.nombre,
         e.fecha_evaluacion, e.tipo_evaluacion, p.nombre_identificacion
ORDER BY e.fecha_evaluacion, e.id_evaluacion;

-- Q02. ¿Qué aplicaciones siguen pendientes al 27-10-2026 y cuáles vencieron?
-- Esperado: HS-001/2026-10-10 VENCIDA, HS-003/2026-11-03 PROGRAMADA,
-- HS-002/2026-11-05 PROGRAMADA, en ese orden.
SELECT a.codigo_interno, a.nombre, i.tipo_indicacion,
       i.descripcion, ap.fecha_planificada,
       CASE WHEN ap.fecha_planificada < DATE '2026-10-27'
            THEN 'VENCIDA' ELSE 'PROGRAMADA' END AS situacion
FROM aplicacion_indicacion AS ap
JOIN indicacion AS i ON i.id_indicacion = ap.indicacion_id
JOIN evaluacion_salud AS e ON e.id_evaluacion = i.evaluacion_id
JOIN animal AS a ON a.codigo_interno = e.animal_codigo
WHERE ap.fecha_real IS NULL
ORDER BY ap.fecha_planificada, a.codigo_interno;

-- Q03. ¿Cuántas revisiones y registros de diagnóstico confirmado tiene cada animal?
-- Esperado: HS-001 (2,2), HS-002 (1,1), HS-003 (1,0),
-- HS-004 (0,0) y HS-005 (0,0). Se cuentan apariciones, no nombres únicos.
SELECT a.codigo_interno, a.nombre,
       COUNT(DISTINCT e.id_evaluacion) FILTER
           (WHERE e.tipo_evaluacion = 'REVISION_VETERINARIA') AS revisiones,
       COUNT(dr.diagnostico_id) FILTER
           (WHERE dr.estado_diagnostico = 'CONFIRMADO') AS registros_confirmados
FROM animal AS a
LEFT JOIN evaluacion_salud AS e ON e.animal_codigo = a.codigo_interno
LEFT JOIN diagnostico_revision AS dr ON dr.evaluacion_id = e.id_evaluacion
GROUP BY a.codigo_interno, a.nombre
ORDER BY a.codigo_interno;

-- Q04. ¿Qué indicaciones atienden más de un diagnóstico?
-- Esperado: la indicación 1 de HS-001 atiende Dermatitis y Otitis.
SELECT i.id_indicacion, a.codigo_interno, i.descripcion,
       COUNT(*) AS cantidad_diagnosticos,
       STRING_AGG(d.nombre_estandarizado, ', ' ORDER BY d.nombre_estandarizado)
           AS diagnosticos_atendidos
FROM indicacion AS i
JOIN indicacion_diagnostico AS ide ON ide.indicacion_id = i.id_indicacion
JOIN diagnostico AS d ON d.id_diagnostico = ide.diagnostico_id
JOIN evaluacion_salud AS e ON e.id_evaluacion = i.evaluacion_id
JOIN animal AS a ON a.codigo_interno = e.animal_codigo
GROUP BY i.id_indicacion, a.codigo_interno, i.descripcion
HAVING COUNT(*) > 1
ORDER BY i.id_indicacion;
