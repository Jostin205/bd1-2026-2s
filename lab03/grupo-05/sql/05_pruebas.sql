-- Pruebas de integridad del subsistema de salud.
-- Precondición general: 01_esquema.sql confirmado y 02_datos.sql cargado
-- una sola vez en una base de prueba. Puede ejecutarse después de 04_rutinas.sql.
-- Cada Pxx indica precondición, sentencia y resultado esperado. La tabla final
-- muestra el resultado OBSERVADO y la conclusión de esta ejecución.
-- Las excepciones esperadas se capturan dentro de cada bloque DO; las demás
-- se propagan como error. ROLLBACK deja intactos los datos de negocio.

BEGIN;

CREATE TEMP TABLE resultado_integridad_lab03 (
    id_prueba VARCHAR(3) PRIMARY KEY,
    regla TEXT NOT NULL,
    esperado TEXT NOT NULL,
    observado TEXT NOT NULL,
    conclusion TEXT NOT NULL
) ON COMMIT DROP;

-- P01. Precondición: PRB-001 no existe; las evaluaciones iniciales admiten
--       campos clínicos y veterinario ausentes.
-- Sentencias: insertar animal PRB-001 y evaluación inicial 9001.
-- Esperado: ambas inserciones aceptadas (PK, FK y tipo válidos).
DO $$
BEGIN
    INSERT INTO animal (codigo_interno, especie, numero_microchip)
    VALUES ('PRB-001', 'Perro', NULL);
    INSERT INTO evaluacion_salud
        (id_evaluacion, animal_codigo, tipo_evaluacion, fecha_evaluacion)
    VALUES (9001, 'PRB-001', 'INICIAL', DATE '2026-10-27');
    IF NOT EXISTS (SELECT 1 FROM evaluacion_salud WHERE id_evaluacion = 9001) THEN
        RAISE EXCEPTION 'P01: no se creó la evaluación';
    END IF;
    INSERT INTO resultado_integridad_lab03 VALUES
        ('P01', 'Evaluación inicial válida', 'ACEPTADO', 'ACEPTADO', 'Cumple');
END $$;

-- P02. Precondición: diagnóstico 1 (Dermatitis) y revisión 5 existen;
--       la pareja (5,1) no está registrada.
-- Sentencia: vincular diagnóstico 1 con revisión 5 como provisional.
-- Esperado: aceptado; un diagnóstico estandarizado puede reutilizarse.
DO $$
BEGIN
    INSERT INTO diagnostico_revision
        (evaluacion_id, diagnostico_id, estado_diagnostico)
    VALUES (5, 1, 'PROVISIONAL');
    INSERT INTO resultado_integridad_lab03 VALUES
        ('P02', 'Diagnóstico reutilizable entre revisiones',
         'ACEPTADO', 'ACEPTADO', 'Cumple');
END $$;

-- P03. Precondición: indicación 4 y persona responsable 3 existen;
--       la aplicación 9001 no existe.
-- Sentencia: insertar una aplicación realizada con fecha, responsable y nota.
-- Esperado: aceptado por la regla de aplicación realizada.
DO $$
BEGIN
    INSERT INTO aplicacion_indicacion
        (id_aplicacion, indicacion_id, fecha_planificada, fecha_real,
         responsable_id, observaciones)
    VALUES (9001, 4, DATE '2026-10-25', DATE '2026-10-25',
            3, 'Aplicación de prueba completada');
    INSERT INTO resultado_integridad_lab03 VALUES
        ('P03', 'Aplicación realizada completa', 'ACEPTADO', 'ACEPTADO', 'Cumple');
END $$;

-- P04. Precondición: HS-001 ya tiene el microchip MC-HS-001.
-- Sentencia: insertar PRB-004 con el mismo microchip.
-- Esperado: rechazo por UNIQUE de animal.numero_microchip (RN-03).
DO $$
BEGIN
    BEGIN
        INSERT INTO animal (codigo_interno, especie, numero_microchip)
        VALUES ('PRB-004', 'Gato', 'MC-HS-001');
        RAISE EXCEPTION 'P04: se aceptó un microchip duplicado';
    EXCEPTION WHEN unique_violation THEN
        INSERT INTO resultado_integridad_lab03 VALUES
            ('P04', 'Unicidad de microchip', 'RECHAZADO',
             'RECHAZADO (unique_violation)', 'Cumple');
    END;
END $$;

-- P05. Precondición: no existe un animal con código PRB-INEXISTENTE.
-- Sentencia: insertar evaluación inicial 9002 para ese código.
-- Esperado: rechazo por FK evaluacion_salud.animal_codigo.
DO $$
BEGIN
    BEGIN
        INSERT INTO evaluacion_salud
            (id_evaluacion, animal_codigo, tipo_evaluacion, fecha_evaluacion)
        VALUES (9002, 'PRB-INEXISTENTE', 'INICIAL', DATE '2026-10-27');
        RAISE EXCEPTION 'P05: se aceptó una evaluación sin animal';
    EXCEPTION WHEN foreign_key_violation THEN
        INSERT INTO resultado_integridad_lab03 VALUES
            ('P05', 'Referencia a animal existente', 'RECHAZADO',
             'RECHAZADO (foreign_key_violation)', 'Cumple');
    END;
END $$;

-- P06. Precondición: PRB-006 no existe.
-- Sentencia: insertar animal con edad_estimada = -1.
-- Esperado: rechazo por CHECK edad_estimada >= 0.
DO $$
BEGIN
    BEGIN
        INSERT INTO animal (codigo_interno, especie, edad_estimada)
        VALUES ('PRB-006', 'Perro', -1);
        RAISE EXCEPTION 'P06: se aceptó una edad negativa';
    EXCEPTION WHEN check_violation THEN
        INSERT INTO resultado_integridad_lab03 VALUES
            ('P06', 'Edad estimada no negativa', 'RECHAZADO',
             'RECHAZADO (check_violation)', 'Cumple');
    END;
END $$;

-- P07. Precondición: revisión 5 y diagnóstico 2 existen;
--       la pareja (5,2) no está registrada.
-- Sentencia: insertar estado_diagnostico = INVALIDO.
-- Esperado: rechazo por CHECK de estados permitidos (RN-11).
DO $$
BEGIN
    BEGIN
        INSERT INTO diagnostico_revision
            (evaluacion_id, diagnostico_id, estado_diagnostico)
        VALUES (5, 2, 'INVALIDO');
        RAISE EXCEPTION 'P07: se aceptó un estado de diagnóstico inválido';
    EXCEPTION WHEN check_violation THEN
        INSERT INTO resultado_integridad_lab03 VALUES
            ('P07', 'Estado de diagnóstico permitido', 'RECHAZADO',
             'RECHAZADO (check_violation)', 'Cumple');
    END;
END $$;

-- P08. Precondición: indicación 4 existe; aplicación 9002 no existe.
-- Sentencia: insertar fecha_real sin persona responsable.
-- Esperado: rechazo por chk_aplicacion_realizada (RN-13).
DO $$
BEGIN
    BEGIN
        INSERT INTO aplicacion_indicacion
            (id_aplicacion, indicacion_id, fecha_planificada, fecha_real,
             responsable_id, observaciones)
        VALUES (9002, 4, DATE '2026-10-26', DATE '2026-10-26',
                NULL, 'Intento de prueba sin responsable');
        RAISE EXCEPTION 'P08: se aceptó una aplicación sin responsable';
    EXCEPTION WHEN check_violation THEN
        INSERT INTO resultado_integridad_lab03 VALUES
            ('P08', 'Responsable obligatorio al realizar', 'RECHAZADO',
             'RECHAZADO (check_violation)', 'Cumple');
    END;
END $$;

-- P09. Precondición: HS-001 y los demás datos clínicos son válidos.
-- Sentencia: insertar revisión 9003 sin veterinario_id.
-- Esperado: rechazo por chk_revision_campos (RN-10).
DO $$
BEGIN
    BEGIN
        INSERT INTO evaluacion_salud
            (id_evaluacion, animal_codigo, tipo_evaluacion, fecha_evaluacion,
             motivo, observaciones, peso, recomendaciones)
        VALUES (9003, 'HS-001', 'REVISION_VETERINARIA', DATE '2026-10-28',
                'Control', 'Hallazgo de prueba', 12.40, 'Continuar seguimiento');
        RAISE EXCEPTION 'P09: se aceptó una revisión sin veterinario';
    EXCEPTION WHEN check_violation THEN
        INSERT INTO resultado_integridad_lab03 VALUES
            ('P09', 'Veterinario obligatorio en revisión', 'RECHAZADO',
             'RECHAZADO (check_violation)', 'Cumple');
    END;
END $$;

-- P10. Precondición: evaluación 1 es INICIAL y diagnóstico 4 existe.
-- Sentencia: registrar el diagnóstico 4 en la evaluación inicial.
-- Esperado: rechazo por FK que exige REVISION_VETERINARIA (RN-11).
DO $$
BEGIN
    BEGIN
        INSERT INTO diagnostico_revision
            (evaluacion_id, diagnostico_id, estado_diagnostico)
        VALUES (1, 4, 'PROVISIONAL');
        RAISE EXCEPTION 'P10: se aceptó un diagnóstico en evaluación inicial';
    EXCEPTION WHEN foreign_key_violation THEN
        INSERT INTO resultado_integridad_lab03 VALUES
            ('P10', 'Diagnóstico solo en revisión', 'RECHAZADO',
             'RECHAZADO (foreign_key_violation)', 'Cumple');
    END;
END $$;

-- P11. Precondición: evaluación 1 es INICIAL; indicación 9003 no existe.
-- Sentencia: crear indicación 9003 a partir de esa evaluación.
-- Esperado: rechazo por FK que exige REVISION_VETERINARIA (RN-12).
DO $$
BEGIN
    BEGIN
        INSERT INTO indicacion
            (id_indicacion, evaluacion_id, tipo_indicacion, descripcion)
        VALUES (9003, 1, 'TRATAMIENTO', 'Indicación de prueba');
        RAISE EXCEPTION 'P11: se aceptó una indicación en evaluación inicial';
    EXCEPTION WHEN foreign_key_violation THEN
        INSERT INTO resultado_integridad_lab03 VALUES
            ('P11', 'Indicación solo desde revisión', 'RECHAZADO',
             'RECHAZADO (foreign_key_violation)', 'Cumple');
    END;
END $$;

-- P12. Precondición: indicación 4 existe; aplicación 9003 no existe.
-- Sentencia: registrar una aplicación realizada con observaciones vacías.
-- Esperado: rechazo por chk_aplicacion_realizada (RN-13).
DO $$
BEGIN
    BEGIN
        INSERT INTO aplicacion_indicacion
            (id_aplicacion, indicacion_id, fecha_planificada, fecha_real,
             responsable_id, observaciones)
        VALUES (9003, 4, DATE '2026-10-28', DATE '2026-10-28', 3, '   ');
        RAISE EXCEPTION 'P12: se aceptaron observaciones vacías';
    EXCEPTION WHEN check_violation THEN
        INSERT INTO resultado_integridad_lab03 VALUES
            ('P12', 'Observaciones no vacías al realizar', 'RECHAZADO',
             'RECHAZADO (check_violation)', 'Cumple');
    END;
END $$;

-- La salida de este SELECT es la evidencia observada de P01-P12.
SELECT id_prueba, regla, esperado, observado, conclusion
FROM resultado_integridad_lab03
ORDER BY id_prueba;

DO $$
BEGIN
    IF (SELECT COUNT(*) FROM resultado_integridad_lab03) <> 12 THEN
        RAISE EXCEPTION 'Faltan resultados de pruebas de integridad';
    END IF;
END $$;

ROLLBACK;
