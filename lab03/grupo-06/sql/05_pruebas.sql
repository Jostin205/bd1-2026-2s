-- =============================================================================
-- 05_pruebas.sql — 9 pruebas de integridad y de rutinas (3 funcionan, 6 fallan)
-- Se ejecuta al final, en UNA sola sesión (psql -f), después de 01, 02, 04 y 03.
--
-- Cómo funciona (para que las pruebas inválidas no detengan el resto):
--   * hotel.prueba_exito   ejecuta una sentencia que DEBE funcionar, verifica su
--                            efecto con una consulta y luego deshace todo.
--   * hotel.prueba_rechazo ejecuta una sentencia que DEBE ser rechazada, captura el
--                            error y comprueba que lo rechazó la restricción prevista.
--   Ambas corren cada prueba en un subbloque con EXCEPTION (savepoint implícito):
--   nada de lo que prueban queda guardado en la base.
--   Los resultados se acumulan en la tabla resultado_pruebas, que se
--   muestra al final con: precondición, sentencia, esperado, observado y conclusión.
--   El SQL que se muestra en la columna "sentencia" es exactamente el que se ejecutó.
-- La tabla y las dos funciones auxiliares (resultado_pruebas, prueba_exito y
-- prueba_rechazo) no son rutinas del negocio: se crean al inicio, en el esquema
-- hotel. Al final se borran las dos funciones y se conserva la tabla
-- resultado_pruebas para poder consultarla después con:
--     SELECT * FROM hotel.resultado_pruebas ORDER BY id;
-- No dependen de la sesión, así que funcionan igual en psql, DBeaver u otro cliente.
-- =============================================================================
SET search_path TO hotel;

-- Limpieza de los auxiliares propios de este script (permite repetirlo sin error).
DROP TABLE IF EXISTS hotel.resultado_pruebas;
DROP FUNCTION IF EXISTS hotel.prueba_exito(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS hotel.prueba_rechazo(TEXT, TEXT, TEXT, TEXT, TEXT);

CREATE TABLE hotel.resultado_pruebas (
    id           VARCHAR(4) PRIMARY KEY,
    tipo         VARCHAR(10) NOT NULL,       -- debe funcionar / debe fallar
    descripcion  TEXT NOT NULL,
    precondicion TEXT NOT NULL,
    sentencia    TEXT NOT NULL,
    esperado     TEXT NOT NULL,
    observado    TEXT NOT NULL,
    conclusion   VARCHAR(6) NOT NULL         -- PASA / FALLA
);

CREATE FUNCTION hotel.prueba_exito(
    p_id TEXT, p_desc TEXT, p_pre TEXT, p_sentencia TEXT, p_verificacion TEXT, p_esperado TEXT)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    v_obs TEXT := 'sin resultado';
    v_ok  BOOLEAN := FALSE;
BEGIN
    BEGIN
        EXECUTE p_sentencia;
        EXECUTE p_verificacion INTO v_obs;
        v_ok := (v_obs = p_esperado);
        RAISE EXCEPTION '__deshacer__';          -- revierte todo lo que hizo la prueba
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM <> '__deshacer__' THEN
            v_obs := 'ERROR inesperado: ' || SQLERRM;
            v_ok := FALSE;
        END IF;
    END;
    INSERT INTO resultado_pruebas
    VALUES (p_id, 'funciona', p_desc, p_pre, p_sentencia, p_esperado, v_obs,
            CASE WHEN v_ok THEN 'PASA' ELSE 'FALLA' END);
END;
$$;

CREATE FUNCTION hotel.prueba_rechazo(
    p_id TEXT, p_desc TEXT, p_pre TEXT, p_sentencia TEXT, p_esperado TEXT)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    v_obs   TEXT := 'ACEPTADA (debía ser rechazada)';
    v_ok    BOOLEAN := FALSE;
    v_msg   TEXT;
    v_const TEXT;
    v_col   TEXT;
    v_state TEXT;
BEGIN
    BEGIN
        EXECUTE p_sentencia;
        RAISE EXCEPTION '__deshacer__';
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_msg = MESSAGE_TEXT, v_const = CONSTRAINT_NAME,
                                v_col = COLUMN_NAME, v_state = RETURNED_SQLSTATE;
        IF v_msg <> '__deshacer__' THEN
            v_obs := format('Rechazada [%s] %s', v_state, v_msg);
            v_ok  := p_esperado IN (COALESCE(v_const, ''), COALESCE(v_col, ''))
                     OR position(p_esperado IN v_msg) > 0;
        END IF;
    END;
    INSERT INTO resultado_pruebas
    VALUES (p_id, 'falla', p_desc, p_pre, p_sentencia,
            'Rechazada por: ' || p_esperado, v_obs,
            CASE WHEN v_ok THEN 'PASA' ELSE 'FALLA' END);
END;
$$;

-- =============================================================================
-- PRUEBAS QUE DEBEN FUNCIONAR (P01–P03)
-- =============================================================================

SELECT hotel.prueba_exito('P01',
  'Cancelar con 16 días de anticipación: se devuelve el adelanto (rama devolver)',
  'Reservación 2 confirmada, con adelanto de 40000 y entrada el 2026-11-05',
  $q$CALL sp_cancelar_reservacion(2, 'Carlos Rojas Solano', TIMESTAMP '2026-10-20 09:00')$q$,
  $q$SELECT r.estado || '/' || r.decision_adelanto || '/' ||
            (SELECT count(*) FROM modificacion_reservacion m WHERE m.id_reservacion = 2)
       FROM reservacion r WHERE r.id_reservacion = 2$q$,
  'cancelada/devolver/2');

SELECT hotel.prueba_exito('P02',
  'Cancelar con 1 día de anticipación: se penaliza el adelanto (rama penalizar)',
  'Reservación 2 confirmada, con adelanto de 40000 y entrada el 2026-11-05',
  $q$CALL sp_cancelar_reservacion(2, 'Carlos Rojas Solano', TIMESTAMP '2026-11-04 09:00')$q$,
  $q$SELECT r.estado || '/' || r.decision_adelanto || '/' ||
            (SELECT count(*) FROM modificacion_reservacion m WHERE m.id_reservacion = 2)
       FROM reservacion r WHERE r.id_reservacion = 2$q$,
  'cancelada/penalizar/2');

SELECT hotel.prueba_exito('P03',
  'Marcar vencidas las reservaciones sin adelanto (cursor explícito)',
  'Reservación 6 solicitada el 2026-10-01 exige 60000 sin pagar; la 8 no exige adelanto',
  $q$CALL sp_marcar_reservaciones_vencidas(DATE '2026-10-25')$q$,
  $q$SELECT (SELECT estado FROM reservacion WHERE id_reservacion = 6) || '/' ||
            (SELECT estado FROM reservacion WHERE id_reservacion = 8) || '/' ||
            (SELECT count(*) FROM modificacion_reservacion WHERE id_reservacion = 6)$q$,
  'vencida/solicitada/1');

-- =============================================================================
-- PRUEBAS QUE DEBEN SER RECHAZADAS (P04–P09)
-- =============================================================================

SELECT hotel.prueba_rechazo('P04',
  'Unicidad: dos personas con el mismo tipo y número de documento (RN-01)',
  'Ya existe la persona 1 con cédula nacional 1-0001-0001',
  $q$INSERT INTO persona (id_persona, tipo_documento, numero_documento, nombre, apellido1, fecha_nacimiento, nacionalidad)
     VALUES (101, 'cédula nacional', '1-0001-0001', 'Otra', 'Persona', DATE '1990-01-01', 'Costa Rica')$q$,
  'uq_persona_documento');

SELECT hotel.prueba_rechazo('P05',
  'Obligatoriedad: una persona sin nombre',
  'Ninguna',
  $q$INSERT INTO persona (id_persona, tipo_documento, numero_documento, nombre, apellido1, fecha_nacimiento, nacionalidad)
     VALUES (102, 'pasaporte', 'P-XX-000001', NULL, 'Sinnombre', DATE '1990-01-01', 'Costa Rica')$q$,
  'nombre');

SELECT hotel.prueba_rechazo('P06',
  'Regla de negocio: una reservación sin responsable (RN-02, RN-03)',
  'Ninguna',
  $q$INSERT INTO reservacion (id_reservacion, id_persona_responsable, id_empresa_responsable,
                              fecha_solicitud, fecha_entrada_prevista, fecha_salida_prevista, cantidad_huespedes)
     VALUES (103, NULL, NULL, DATE '2026-10-20', DATE '2027-02-01', DATE '2027-02-03', 2)$q$,
  'ck_reservacion_responsable');

SELECT hotel.prueba_rechazo('P07',
  'Rango: una reservación cuya salida es anterior a la entrada',
  'Existe la persona 1',
  $q$INSERT INTO reservacion (id_reservacion, id_persona_responsable,
                              fecha_solicitud, fecha_entrada_prevista, fecha_salida_prevista, cantidad_huespedes)
     VALUES (104, 1, DATE '2026-10-20', DATE '2027-02-05', DATE '2027-02-03', 2)$q$,
  'ck_reservacion_fechas');

SELECT hotel.prueba_rechazo('P08',
  'Referencia: un detalle con una categoría que no existe',
  'Existe la reservación 2; no existe la categoría 999',
  $q$INSERT INTO detalle_reservacion (id_reservacion, id_categoria, cantidad_habitaciones, precio_pactado, id_plan, condiciones_pactadas)
     VALUES (2, 999, 1, 50000, 1, 'Solo hospedaje')$q$,
  'fk_detalle_categoria');

SELECT hotel.prueba_rechazo('P09',
  'Rutina: cancelar una reservación que ya está cancelada',
  'Reservación 4 en estado cancelada',
  $q$CALL sp_cancelar_reservacion(4, 'Emily Carter', TIMESTAMP '2026-09-15 09:00')$q$,
  'su estado actual es "cancelada"');

-- =============================================================================
-- RESULTADOS
-- =============================================================================
SELECT '=== RESULTADO DE LAS PRUEBAS ===' AS seccion;
SELECT id, tipo, conclusion, descripcion, esperado, observado
  FROM resultado_pruebas ORDER BY id;

SELECT '=== RESUMEN ===' AS seccion;
SELECT count(*) AS total,
       count(*) FILTER (WHERE conclusion = 'PASA')  AS pasan,
       count(*) FILTER (WHERE conclusion = 'FALLA') AS fallan
  FROM resultado_pruebas;

SELECT '=== LAS PRUEBAS NO DEJARON CAMBIOS: deben salir 8, 6, 4, confirmada, solicitada ===' AS seccion;
SELECT (SELECT count(*) FROM reservacion)               AS reservaciones,   -- 8
       (SELECT count(*) FROM persona)                   AS personas,        -- 6
       (SELECT count(*) FROM modificacion_reservacion)  AS modificaciones,  -- 4
       (SELECT estado FROM reservacion WHERE id_reservacion = 2) AS estado_r2,  -- confirmada
       (SELECT estado FROM reservacion WHERE id_reservacion = 6) AS estado_r6;  -- solicitada

-- -----------------------------------------------------------------------------
-- Limpieza final: se borran las funciones auxiliares; la tabla de resultados se conserva
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS hotel.prueba_exito(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS hotel.prueba_rechazo(TEXT, TEXT, TEXT, TEXT, TEXT);
