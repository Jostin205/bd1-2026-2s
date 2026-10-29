-- =============================================================================
-- 02_datos.sql — Datos ficticios para el subsistema de reservaciones
-- Todos los datos son inventados (nombres, documentos, correos y referencias).
-- Las fechas son fijas (no dependen de CURRENT_DATE) para que los resultados
-- de 03_consultas.sql y 05_pruebas.sql sean reproducibles.
--
-- Cobertura (por qué el conjunto es suficiente):
--   * 6 personas de 5 nacionalidades y 3 tipos de documento, una sin segundo apellido.
--   * 2 empresas responsables (reservación hecha por empresa).
--   * 3 categorías y 3 planes (uno con vigencia abierta).
--   * 8 reservaciones que cubren los 6 estados del ciclo de vida:
--       solicitada (R6, R8), confirmada (R2, R3), cancelada (R4 con 'devolver',
--       R5 con 'penalizar'), no presentada (R7), convertida en estancia (R1).
--       'vencida' no tiene fila a propósito: la produce sp_marcar_reservaciones_vencidas.
--   * R3 y R8 mezclan categorías distintas en una misma reservación (RN-11).
--   * R6 exige adelanto y no lo ha pagado (candidata a vencer); R3 y R8 son de empresa.
--   * 5 adelantos y 3 modificaciones (cambio de fechas con y sin cambio de precio,
--     y dos cancelaciones) para observar el historial.
-- =============================================================================
SET search_path TO hotel;

INSERT INTO persona (id_persona, tipo_documento, numero_documento, nombre, apellido1, apellido2, fecha_nacimiento, nacionalidad) VALUES
 (1, 'cédula nacional', '1-0001-0001', 'Laura',  'Mora',      'Vega',     DATE '1985-03-14', 'Costa Rica'),
 (2, 'cédula nacional', '2-0002-0002', 'Carlos', 'Rojas',     'Solano',   DATE '1979-11-02', 'Costa Rica'),
 (3, 'pasaporte',       'P-US-554433', 'Emily',  'Carter',    NULL,       DATE '1990-07-21', 'Estados Unidos'),
 (4, 'DIMEX',           '1-8000-0004', 'Ana',    'Gómez',     'Castro',   DATE '1988-01-30', 'Nicaragua'),
 (5, 'cédula nacional', '3-0005-0005', 'Jorge',  'Villalobos','Campos',   DATE '1995-05-09', 'Costa Rica'),
 (6, 'pasaporte',       'P-ES-778899', 'Lucía',  'Fernández', NULL,       DATE '1982-09-17', 'España');

INSERT INTO empresa (id_empresa, nombre, medio_contacto) VALUES
 (1, 'Cafetalera del Norte S.A.',   'reservas@cafetaleranorte.example'),
 (2, 'Constructora Altura S.R.L.',  'compras@altura.example');

INSERT INTO categoria_habitacion (id_categoria, nombre, descripcion, capacidad_habitual) VALUES
 (1, 'Estándar', 'Una cama doble, baño privado',                     2),
 (2, 'Familiar', 'Dos camas dobles y espacio de sala',               4),
 (3, 'Suite',    'Dormitorio con sala independiente y terraza',      3);

INSERT INTO plan_tarifario (id_plan, nombre, condiciones, vigencia_inicio, vigencia_fin) VALUES
 (1, 'Plan Básico',            'Solo hospedaje; cancelación sin costo hasta 48 horas antes de la llegada', DATE '2026-01-01', DATE '2026-12-31'),
 (2, 'Plan Desayuno Incluido', 'Incluye desayuno buffet; cancelación sin costo hasta 48 horas antes de la llegada', DATE '2026-01-01', DATE '2026-12-31'),
 (3, 'Plan Pago Anticipado',   'Pago anticipado; el adelanto no se reembolsa dentro de las 48 horas previas a la llegada', DATE '2026-03-01', NULL);

INSERT INTO reservacion (id_reservacion, id_persona_responsable, id_empresa_responsable, fecha_solicitud,
                         fecha_entrada_prevista, fecha_salida_prevista, cantidad_huespedes, estado,
                         adelanto_requerido, decision_adelanto) VALUES
 (1, 1,    NULL, DATE '2026-09-01', DATE '2026-10-10', DATE '2026-10-13', 3, 'convertida en estancia', 50000, NULL),
 (2, 2,    NULL, DATE '2026-09-20', DATE '2026-11-05', DATE '2026-11-08', 2, 'confirmada',             40000, NULL),
 (3, NULL, 1,    DATE '2026-09-25', DATE '2026-11-10', DATE '2026-11-14', 6, 'confirmada',             NULL,  NULL),
 (4, 3,    NULL, DATE '2026-08-15', DATE '2026-09-20', DATE '2026-09-22', 2, 'cancelada',              30000, 'devolver'),
 (5, 4,    NULL, DATE '2026-09-10', DATE '2026-10-01', DATE '2026-10-03', 2, 'cancelada',              35000, 'penalizar'),
 (6, 5,    NULL, DATE '2026-10-01', DATE '2026-12-20', DATE '2026-12-23', 4, 'solicitada',             60000, NULL),
 (7, 6,    NULL, DATE '2026-09-05', DATE '2026-10-15', DATE '2026-10-17', 2, 'no presentada',          25000, 'penalizar'),
 (8, NULL, 2,    DATE '2026-10-05', DATE '2026-12-01', DATE '2026-12-05', 8, 'solicitada',             NULL,  NULL);

INSERT INTO detalle_reservacion (id_reservacion, id_categoria, cantidad_habitaciones, precio_pactado, id_plan, condiciones_pactadas) VALUES
 (1, 2, 1,  80000, 2, 'Incluye desayuno buffet; cancelación sin costo hasta 48 horas antes de la llegada'),
 (2, 1, 1,  55000, 1, 'Solo hospedaje; cancelación sin costo hasta 48 horas antes de la llegada'),
 (3, 1, 2,  50000, 1, 'Solo hospedaje; cancelación sin costo hasta 48 horas antes de la llegada'),
 (3, 2, 1,  70000, 1, 'Solo hospedaje; cancelación sin costo hasta 48 horas antes de la llegada'),
 (4, 1, 1,  60000, 2, 'Incluye desayuno buffet; cancelación sin costo hasta 48 horas antes de la llegada'),
 (5, 1, 1,  55000, 3, 'Pago anticipado; el adelanto no se reembolsa dentro de las 48 horas previas a la llegada'),
 (6, 2, 1,  80000, 2, 'Incluye desayuno buffet; cancelación sin costo hasta 48 horas antes de la llegada'),
 (7, 1, 1,  55000, 1, 'Solo hospedaje; cancelación sin costo hasta 48 horas antes de la llegada'),
 (8, 1, 3,  50000, 1, 'Solo hospedaje; cancelación sin costo hasta 48 horas antes de la llegada'),
 (8, 3, 1, 120000, 1, 'Solo hospedaje; cancelación sin costo hasta 48 horas antes de la llegada');

INSERT INTO pago (id_pago, monto, fecha, medio, referencia, tipo, id_reservacion) VALUES
 (1, 50000, DATE '2026-09-02', 'tarjeta',       'AUTH-10001', 'adelanto', 1),
 (2, 40000, DATE '2026-09-21', 'transferencia', 'TRF-20002',  'adelanto', 2),
 (3, 30000, DATE '2026-08-16', 'tarjeta',       'AUTH-30003', 'adelanto', 4),
 (4, 35000, DATE '2026-09-11', 'tarjeta',       'AUTH-40004', 'adelanto', 5),
 (5, 25000, DATE '2026-09-06', 'transferencia', 'TRF-50005',  'adelanto', 7);

INSERT INTO modificacion_reservacion (id_reservacion, id_modificacion, fecha_hora_modificacion, tipo_modificacion,
                                      solicitante, genero_cambio_precio, diferencia_precio, descripcion_cambio) VALUES
 (2, 1, TIMESTAMP '2026-10-01 10:15', 'fechas',     'Carlos Rojas Solano',       TRUE,  55000, 'La salida pasa del 2026-11-07 al 2026-11-08 (una noche adicional)'),
 (3, 1, TIMESTAMP '2026-10-10 14:00', 'ocupacion',  'Cafetalera del Norte S.A.', FALSE, NULL,  'Los huéspedes pasan de 5 a 6; cabe en las habitaciones contratadas'),
 (4, 1, TIMESTAMP '2026-09-12 09:00', 'cancelacion','Emily Carter',              FALSE, NULL,  'Cancelación con 8 días de anticipación; decisión sobre el adelanto: devolver'),
 (5, 1, TIMESTAMP '2026-09-30 18:30', 'cancelacion','Ana Gómez Castro',          FALSE, NULL,  'Cancelación con 1 día de anticipación; decisión sobre el adelanto: penalizar');

-- Las claves se insertaron de forma explícita: se avanzan las secuencias de identidad
-- para que los INSERT posteriores sin id (pruebas) no choquen con estos registros.
SELECT setval(pg_get_serial_sequence('hotel.persona',              'id_persona'),    (SELECT MAX(id_persona)    FROM persona));
SELECT setval(pg_get_serial_sequence('hotel.empresa',              'id_empresa'),    (SELECT MAX(id_empresa)    FROM empresa));
SELECT setval(pg_get_serial_sequence('hotel.categoria_habitacion', 'id_categoria'),  (SELECT MAX(id_categoria)  FROM categoria_habitacion));
SELECT setval(pg_get_serial_sequence('hotel.plan_tarifario',       'id_plan'),       (SELECT MAX(id_plan)       FROM plan_tarifario));
SELECT setval(pg_get_serial_sequence('hotel.reservacion',          'id_reservacion'),(SELECT MAX(id_reservacion) FROM reservacion));
SELECT setval(pg_get_serial_sequence('hotel.pago',                 'id_pago'),       (SELECT MAX(id_pago)       FROM pago));
