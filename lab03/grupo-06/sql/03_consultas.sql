-- =============================================================================
-- 03_consultas.sql — Consultas de negocio del subsistema de reservaciones
-- Se ejecuta después de 04_rutinas.sql (usa fn_total_reservacion).
-- Cada consulta indica la pregunta de negocio, la necesidad de información del
-- Proyecto 1 que atiende y el resultado esperado con los datos de 02_datos.sql.
-- Los resultados esperados se calcularon a mano a partir de los datos, antes
-- de ejecutar las consultas.
-- =============================================================================
SET search_path TO hotel;

-- -----------------------------------------------------------------------------
-- Q1 · Reservaciones confirmadas, con responsable, habitaciones y total estimado
-- Pregunta  : ¿Qué reservaciones están confirmadas, quién responde por cada una,
--             qué habitaciones se confirmaron y cuánto se espera facturar?
-- Necesidad : "Tarifas y condiciones aplicadas a cada reserva" / "Reservaciones
--             pendientes de asignación de habitación" (RN-11, RN-13).
-- Técnica   : JOIN de cinco tablas (LEFT JOIN para el responsable, que es persona
--             o empresa) y función definida por el grupo.
-- Esperado  : 2 filas
--             2 | Carlos Rojas Solano       | Estándar x1             | 2026-11-05 | 2026-11-08 | 165000.00
--             3 | Cafetalera del Norte S.A. | Estándar x2, Familiar x1 | 2026-11-10 | 2026-11-14 | 680000.00
-- -----------------------------------------------------------------------------
SELECT r.id_reservacion,
       COALESCE(p.nombre || ' ' || p.apellido1 || COALESCE(' ' || p.apellido2, ''), e.nombre) AS responsable,
       string_agg(c.nombre || ' x' || d.cantidad_habitaciones, ', ' ORDER BY c.nombre)        AS habitaciones,
       r.fecha_entrada_prevista,
       r.fecha_salida_prevista,
       fn_total_reservacion(r.id_reservacion)                                                  AS total_estimado
  FROM reservacion r
  LEFT JOIN persona p ON p.id_persona = r.id_persona_responsable
  LEFT JOIN empresa e ON e.id_empresa = r.id_empresa_responsable
  JOIN detalle_reservacion d ON d.id_reservacion = r.id_reservacion
  JOIN categoria_habitacion c ON c.id_categoria = d.id_categoria
 WHERE r.estado = 'confirmada'
 GROUP BY r.id_reservacion, p.id_persona, e.id_empresa
 ORDER BY r.fecha_entrada_prevista;

-- -----------------------------------------------------------------------------
-- Q2 · Ingreso estimado por categoría (agregación con HAVING)
-- Pregunta  : ¿Qué categorías concentran más de 500.000 en ingresos estimados de
--             hospedaje entre las reservaciones vigentes (solicitada, confirmada o
--             convertida en estancia)?
-- Necesidad : "Disponibilidad de habitaciones por fecha y categoría" (demanda por
--             categoría).
-- Técnica   : GROUP BY + SUM + COUNT(DISTINCT) + HAVING.
-- Cálculo   : Estándar = R2 165000 + R3 400000 + R8 600000 = 1165000 (3 reservaciones, 6 habitaciones)
--             Familiar = R1 240000 + R3 280000 + R6 240000 =  760000 (3 reservaciones, 3 habitaciones)
--             Suite    = R8 480000 -> queda fuera por el HAVING (480000 < 500000)
-- Esperado  : 2 filas
--             Estándar | 3 | 6 | 1165000.00
--             Familiar | 3 | 3 |  760000.00
-- -----------------------------------------------------------------------------
SELECT c.nombre                                   AS categoria,
       COUNT(DISTINCT r.id_reservacion)           AS reservaciones,
       SUM(d.cantidad_habitaciones)               AS habitaciones_reservadas,
       SUM(d.cantidad_habitaciones * d.precio_pactado
           * (r.fecha_salida_prevista - r.fecha_entrada_prevista)) AS ingreso_estimado
  FROM detalle_reservacion d
  JOIN reservacion r ON r.id_reservacion = d.id_reservacion
  JOIN categoria_habitacion c ON c.id_categoria = d.id_categoria
 WHERE r.estado IN ('solicitada', 'confirmada', 'convertida en estancia')
 GROUP BY c.id_categoria, c.nombre
HAVING SUM(d.cantidad_habitaciones * d.precio_pactado
           * (r.fecha_salida_prevista - r.fecha_entrada_prevista)) > 500000
 ORDER BY ingreso_estimado DESC;

-- -----------------------------------------------------------------------------
-- Q3 · Reservaciones con adelanto pendiente de pago
-- Pregunta  : ¿Qué reservaciones vigentes exigen adelanto y todavía no lo han
--             cubierto completamente, y cuánto falta?
-- Necesidad : "Adelantos, cargos, pagos y saldos" (RN-15, RN-26).
-- Técnica   : LEFT JOIN (una reservación sin pagos debe aparecer) + GROUP BY + HAVING.
-- Cálculo   : R2 exige 40000 y recibió 40000 -> no aparece.
--             R6 exige 60000 y no recibió nada -> falta 60000.
--             R3 y R8 no exigen adelanto (empresa) -> no aparecen.
-- Esperado  : 1 fila
--             6 | solicitada | 60000.00 | 0.00 | 60000.00
-- -----------------------------------------------------------------------------
SELECT r.id_reservacion,
       r.estado,
       r.adelanto_requerido,
       COALESCE(SUM(p.monto), 0.00)                       AS adelanto_recibido,
       r.adelanto_requerido - COALESCE(SUM(p.monto), 0.00) AS faltante
  FROM reservacion r
  LEFT JOIN pago p ON p.id_reservacion = r.id_reservacion AND p.tipo = 'adelanto'
 WHERE r.adelanto_requerido IS NOT NULL
   AND r.estado IN ('solicitada', 'confirmada')
 GROUP BY r.id_reservacion
HAVING COALESCE(SUM(p.monto), 0.00) < r.adelanto_requerido
 ORDER BY r.id_reservacion;

-- -----------------------------------------------------------------------------
-- Q4 · Historial de modificaciones y cancelaciones
-- Pregunta  : ¿Qué cambios y cancelaciones han tenido las reservaciones, quién
--             los pidió, cuándo y si afectaron el precio?
-- Necesidad : "Historial de modificaciones y cancelaciones" (RN-14).
-- Técnica   : JOIN entre la entidad débil, su reservación y el responsable.
-- Esperado  : 4 filas, ordenadas por reservación
--             2 | 1 | 2026-10-01 10:15 | fechas      | Carlos Rojas Solano       | t | 55000.00
--             3 | 1 | 2026-10-10 14:00 | ocupacion   | Cafetalera del Norte S.A. | f | (nulo)
--             4 | 1 | 2026-09-12 09:00 | cancelacion | Emily Carter              | f | (nulo)
--             5 | 1 | 2026-09-30 18:30 | cancelacion | Ana Gómez Castro          | f | (nulo)
-- -----------------------------------------------------------------------------
SELECT m.id_reservacion,
       m.id_modificacion,
       m.fecha_hora_modificacion,
       m.tipo_modificacion,
       m.solicitante,
       m.genero_cambio_precio,
       m.diferencia_precio
  FROM modificacion_reservacion m
  JOIN reservacion r ON r.id_reservacion = m.id_reservacion
 ORDER BY m.id_reservacion, m.id_modificacion;

-- -----------------------------------------------------------------------------
-- Q5 · Penalizaciones sobre adelantos
-- Pregunta  : ¿En qué reservaciones canceladas o no presentadas se decidió
--             penalizar, y qué monto de adelanto queda retenido?
-- Necesidad : "Reservas no presentadas y penalizaciones aplicadas" (RN-15).
-- Técnica   : JOIN + agregación (SUM) con filtro por la decisión registrada.
-- Esperado  : 2 filas
--             5 | cancelada     | penalizar | 35000.00
--             7 | no presentada | penalizar | 25000.00
-- -----------------------------------------------------------------------------
SELECT r.id_reservacion,
       r.estado,
       r.decision_adelanto,
       SUM(p.monto) AS adelanto_retenido
  FROM reservacion r
  JOIN pago p ON p.id_reservacion = r.id_reservacion AND p.tipo = 'adelanto'
 WHERE r.decision_adelanto = 'penalizar'
 GROUP BY r.id_reservacion, r.estado, r.decision_adelanto
 ORDER BY r.id_reservacion;
