-- Laboratorio 03 - Grupo 01
-- Subsistema de Atención Médica Efectiva, Diagnóstico Clínico y Prescripción Terapéutica
-- Caso: Clínica Los Robles
-- Archivo: 02_datos.sql

BEGIN;

-- 1. Catálogo de diagnósticos médicos (CIE-10) [RN-20]
INSERT INTO diagnostico (
    codigo_diagnostico,
    descripcion_diagnostico
)
VALUES
    ('J00', 'Rinofaringitis aguda'),
    ('J06.9', 'Infección aguda de vias respiratorias superiores, no especificada'),
    ('R50.9', 'Fiebre, no especificada');

-- 2. Registros de consultas médicas [RN-16, RN-17]
INSERT INTO consulta (
    id_consulta,
    id_paciente,
    id_medico,
    id_cita,
    fecha_hora_inicio,
    motivo_clinico,
    resumen_general
)
VALUES
(
    5001,
    100245,
    200317,
    9001,
    '2026-10-10 09:35:00',
    'Fiebre y dolor de garganta',
    'Paciente con sintomas respiratorios leves.'
),
(
    5002,
    100246,
    200318,
    NULL,
    '2026-10-11 14:15:00',
    'Dificultad respiratoria leve',
    'Atencion urgente por sintomas respiratorios.'
),
(
    5003,
    100245,
    200317,
    9002,
    '2026-10-13 11:05:00',
    'Control de sistemas respiratorios',
    'Paciente presenta mejoria respecto a la consulta anterior.'
);

-- 3. Observaciones clínicas versionadas [RN-19, S-13]
INSERT INTO observacion_clinica (
    id_consulta,
    consecutivo_observacion,
    num_version,
    contenido_observacion,
    fecha_hora_registro,
    es_vigente
)
VALUES
(
    5001, 1, 1,
    'Paciente presenta temperatura de 38.5 grados.',
    '2026-10-10 09:40:00',
    FALSE
),
(
    5001, 1, 2,
    'Se corrige la medicion: temperatura de 38.2 grados.',
    '2026-10-10 09:50:00',
    TRUE
),
(
    5001, 2, 1,
    'Paciente presenta irritacion leve de garganta.',
    '2026-10-10 09:55:00',
    TRUE
),
(
    5002, 1, 1,
    'Paciente presenta dificultad respiratoria leve.',
    '2026-10-11 14:20:00',
    TRUE
),
(
    5003, 1, 1,
    'Paciente presenta mejoria de los sintomas.',
    '2026-10-13 11:10:00',
    TRUE
);

-- 4. Asociación de consultas con diagnósticos [RN-20]
INSERT INTO consulta_diagnostico_nm (
    id_consulta,
    codigo_diagnostico,
    tipo_categoria,
    condicion
)
VALUES
(
    5001,
    'J06.9',
    'Principal',
    'Confirmado'
),
(
    5001,
    'R50.9',
    'Secundario',
    'Confirmado'
),
(
    5002,
    'J06.9',
    'Principal',
    'Presuntivo'
),
(
    5003,
    'J00',
    'Principal',
    'Confirmado'
);

-- 5. Registro de tratamientos médicos [RN-21, RN-25, RN-26]
INSERT INTO tratamiento (
    id_tratamiento,
    id_consulta,
    id_tratamiento_sustituido,
    tipo_tratamiento,
    instrucciones,
    fecha_inicio_prevista,
    fecha_fin_prevista,
    estado_actual,
    dosis,
    frecuencia,
    cantidad_sesiones
)
VALUES
(
    7001,
    5001,
    NULL,
    'Medicamento',
    'Pauta farmacologica inicial, posteriormente sustituida.',
    '2026-10-10',
    '2026-10-12',
    'Sustituido',
    '1 unidad',
    'Cada 8 horas',
    NULL
),
(
    7002,
    5001,
    7001,
    'Medicamento',
    'Nueva pauta farmacologica que sustituye al tratamiento anterior.',
    '2026-10-11',
    '2026-10-17',
    'Iniciado',
    '1 unidad',
    'Cada 12 horas',
    NULL
),
(
    7003,
    5002,
    NULL,
    'Procedimiento',
    'Realizar dos controles de evaluacion respiratoria.',
    '2026-10-12',
    '2026-10-15',
    'Completado',
    NULL,
    NULL,
    2
),
(
    7004,
    5003,
    NULL,
    'Recomendación',
    'Mantener vigilancia de sintomas y acudir a control si reaparecen.',
    '2026-10-13',
    NULL,
    'Iniciado',
    NULL,
    NULL,
    NULL
);

-- 6. Asociación entre tratamientos y diagnósticos [RN-21]
INSERT INTO tratamiento_diagnostico_nm (
    id_tratamiento,
    codigo_diagnostico
)
VALUES
    (7001, 'J06.9'),
    (7001, 'R50.9'),
    (7002, 'J06.9'),
    (7003, 'J06.9'),
    (7004, 'J00');

COMMIT;