-- Datos ficticios del subsistema de salud de Huellas Seguras.
-- Precondición: 01_esquema.sql ejecutado y confirmado en una base vacía.
-- Este script se carga una sola vez; para repetirlo, recrear la base de prueba.

BEGIN;

-- Identificadores y nombres inventados: no representan personas reales.
INSERT INTO persona (id_persona, nombre_identificacion) VALUES
    (1, 'Profesional veterinario ficticio A'),
    (2, 'Profesional veterinario ficticio B'),
    (3, 'Responsable de cuidados ficticio C');

INSERT INTO animal
    (codigo_interno, nombre, especie, sexo, color, tamano_aproximado,
     edad_estimada, senas_particulares, numero_microchip)
VALUES
    ('HS-001', 'Luna',  'Perro', 'Hembra', 'Café',   'Mediano', 3, 'Mancha blanca en el pecho', 'MC-HS-001'),
    ('HS-002', 'Milo',  'Gato',  'Macho',  'Gris',   'Pequeño', 2, NULL,                      'MC-HS-002'),
    ('HS-003', 'Nube',  'Perro', 'Hembra', 'Blanco', 'Pequeño', 1, 'Oreja izquierda caída',    NULL),
    ('HS-004', 'Sol',   'Perro', 'Macho',  'Dorado', 'Grande',  5, NULL,                      NULL),
    ('HS-005', 'Menta', 'Gato',  'Hembra', 'Negro',  'Pequeño', 4, NULL,                      'MC-HS-005');

-- Cada animal tiene evaluación inicial. HS-001 tiene dos revisiones;
-- HS-004 y HS-005 aún no tienen revisión posterior.
INSERT INTO evaluacion_salud
    (id_evaluacion, animal_codigo, tipo_evaluacion, fecha_evaluacion,
     veterinario_id, motivo, observaciones, peso, recomendaciones)
VALUES
    (1, 'HS-001', 'INICIAL',              DATE '2026-09-01', NULL, NULL, NULL, NULL, NULL),
    (2, 'HS-001', 'REVISION_VETERINARIA', DATE '2026-09-03', 1, 'Lesiones de piel y molestias de oído',
     'Enrojecimiento leve y rascado frecuente', 12.40, 'Realizar curas y control posterior'),
    (3, 'HS-001', 'REVISION_VETERINARIA', DATE '2026-09-17', 1, 'Control de tratamiento',
     'La piel mejoró; no se confirma infección de oído', 12.60, 'Continuar cuidados de piel'),
    (4, 'HS-002', 'INICIAL',              DATE '2026-09-05', NULL, NULL, NULL, NULL, NULL),
    (5, 'HS-002', 'REVISION_VETERINARIA', DATE '2026-09-06', 2, 'Valoración general e hidratación',
     'Deshidratación leve', 3.80, 'Hidratar y programar vacunación'),
    (6, 'HS-003', 'INICIAL',              DATE '2026-09-10', NULL, NULL, NULL, NULL, NULL),
    (7, 'HS-003', 'REVISION_VETERINARIA', DATE '2026-09-12', 1, 'Control respiratorio',
     'Tos ocasional sin compromiso general', 7.20, 'Programar control posterior'),
    (8, 'HS-004', 'INICIAL',              DATE '2026-09-15', NULL, NULL, NULL, NULL, NULL),
    (9, 'HS-005', 'INICIAL',              DATE '2026-09-20', NULL, NULL, NULL, NULL, NULL);

INSERT INTO diagnostico (id_diagnostico, nombre_estandarizado) VALUES
    (1, 'Dermatitis'),
    (2, 'Otitis'),
    (3, 'Deshidratación'),
    (4, 'Infección respiratoria');

-- Un diagnóstico se reutiliza en varias revisiones; otro cambia de
-- provisional a descartado. También hay estados confirmado y provisional.
INSERT INTO diagnostico_revision (evaluacion_id, diagnostico_id, estado_diagnostico) VALUES
    (2, 1, 'CONFIRMADO'),
    (2, 2, 'PROVISIONAL'),
    (3, 1, 'CONFIRMADO'),
    (3, 2, 'DESCARTADO'),
    (5, 3, 'CONFIRMADO'),
    (7, 4, 'PROVISIONAL');

INSERT INTO indicacion
    (id_indicacion, evaluacion_id, tipo_indicacion, descripcion,
     estado_indicacion, indicacion_sustituida_id)
VALUES
    (1, 2, 'TRATAMIENTO', 'Curación de piel y limpieza de oído', 'ACTIVA', NULL),
    (2, 2, 'MEDICAMENTO', 'Medicamento inicial para la piel', 'SUSTITUIDA', NULL),
    (3, 3, 'MEDICAMENTO', 'Medicamento ajustado para la piel', 'ACTIVA', 2),
    (4, 5, 'VACUNA', 'Aplicar vacuna según valoración veterinaria', 'ACTIVA', NULL),
    (5, 7, 'CONTROL_POSTERIOR', 'Revisar evolución de la tos', 'ACTIVA', NULL),
    (6, 3, 'PROCEDIMIENTO', 'Limpieza de la zona afectada', NULL, NULL);

-- Una indicación puede atender varios diagnósticos. La vacuna preventiva
-- no se vincula a un diagnóstico de enfermedad.
INSERT INTO indicacion_diagnostico (indicacion_id, diagnostico_id) VALUES
    (1, 1), (1, 2),
    (2, 1), (3, 1),
    (5, 4), (6, 1);

-- Hay aplicaciones realizadas, una vencida y dos programadas a futuro.
INSERT INTO aplicacion_indicacion
    (id_aplicacion, indicacion_id, fecha_planificada, fecha_real,
     responsable_id, observaciones)
VALUES
    (1, 1, DATE '2026-09-04', DATE '2026-09-04', 3, 'Curación realizada sin incidencias'),
    (2, 1, DATE '2026-10-10', NULL, NULL, NULL),
    (3, 3, DATE '2026-09-18', DATE '2026-09-18', 3, 'Se aplicó la pauta ajustada'),
    (4, 4, DATE '2026-11-05', NULL, NULL, NULL),
    (5, 5, DATE '2026-11-03', NULL, NULL, NULL),
    (6, 6, DATE '2026-09-20', DATE '2026-09-20', 3, 'Limpieza completada');

-- Los identificadores explícitos hacen deterministas las consultas y pruebas.
-- Se sincronizan las secuencias SERIAL para futuros INSERT sin ID explícito.
SELECT setval(pg_get_serial_sequence('persona', 'id_persona'), 3);
SELECT setval(pg_get_serial_sequence('evaluacion_salud', 'id_evaluacion'), 9);
SELECT setval(pg_get_serial_sequence('diagnostico', 'id_diagnostico'), 4);
SELECT setval(pg_get_serial_sequence('indicacion', 'id_indicacion'), 6);
SELECT setval(pg_get_serial_sequence('aplicacion_indicacion', 'id_aplicacion'), 6);

COMMIT;
