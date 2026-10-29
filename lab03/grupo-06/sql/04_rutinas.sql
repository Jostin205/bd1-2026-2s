-- =============================================================================
-- 04_rutinas.sql — Programación almacenada (PL/pgSQL, PostgreSQL 16)
-- Se ejecuta después de 02_datos.sql y antes de 03_consultas.sql.
--
-- Contenido
--   C1  fn_total_reservacion      función que calcula un valor (total estimado)
--   C1  fn_decision_adelanto      función con decisión de negocio (CASE) — RN-15
--   C2  sp_cancelar_reservacion   procedimiento con validaciones y RAISE EXCEPTION
--   C3  sp_marcar_reservaciones_vencidas            cursor explícito
--       sp_marcar_reservaciones_vencidas_conjunto   alternativa basada en conjuntos
--
-- Las restricciones declarativas (CHECK, FK, UNIQUE) siguen en 01_esquema.sql:
-- las rutinas no las reemplazan, solo validan lo que el esquema no puede expresar
-- (reglas que cruzan tablas o dependen del tiempo).
-- =============================================================================
SET search_path TO hotel;

-- -----------------------------------------------------------------------------
-- C1.a  fn_total_reservacion
-- Propósito : total estimado de hospedaje de una reservación, con los precios
--             congelados al confirmar (RN-13): noches × Σ(cantidad × precio_pactado).
-- Parámetros: p_id_reservacion  identificador de la reservación.
-- Retorno   : NUMERIC(14,2). Lanza excepción si la reservación no existe.
-- Regla     : el precio_pactado es por noche y por habitación; no incluye servicios.
-- Ejemplo   : SELECT fn_total_reservacion(3);   -- 4 noches × (2×50000 + 1×70000) = 680000.00
-- -----------------------------------------------------------------------------
CREATE FUNCTION fn_total_reservacion(p_id_reservacion INTEGER)
RETURNS NUMERIC(14,2)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_noches INTEGER;
    v_total  NUMERIC(14,2);
BEGIN
    SELECT fecha_salida_prevista - fecha_entrada_prevista
      INTO v_noches
      FROM reservacion
     WHERE id_reservacion = p_id_reservacion;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La reservación % no existe', p_id_reservacion;
    END IF;

    SELECT COALESCE(SUM(cantidad_habitaciones * precio_pactado), 0) * v_noches
      INTO v_total
      FROM detalle_reservacion
     WHERE id_reservacion = p_id_reservacion;

    RETURN v_total;
END;
$$;

-- -----------------------------------------------------------------------------
-- C1.b  fn_decision_adelanto
-- Propósito : decisión de negocio sobre el adelanto cuando una reservación se
--             cancela (RN-15): ¿se devuelve o se penaliza?
-- Parámetros: p_id_reservacion     reservación que se cancela.
--             p_fecha_cancelacion  fecha en que se solicita la cancelación.
-- Retorno   : 'devolver' | 'penalizar' | NULL (NULL si no se recibió ningún adelanto).
-- Regla     : SUPUESTO DEL LABORATORIO. El enunciado dice que "las políticas de
--             cancelación determinan" la decisión, pero no las define. Se aplica
--             la condición que traen los planes del hotel ("cancelación sin costo
--             hasta 48 horas antes de la llegada"):
--                 faltan 2 o más días para la entrada -> 'devolver'
--                 faltan menos de 2 días              -> 'penalizar'
--             Una política distinta por plan requeriría una tabla de políticas
--             (fuera del subsistema; ver README, limitaciones).
-- Ejemplo   : SELECT fn_decision_adelanto(2, DATE '2026-10-20');  -- entrada 2026-11-05 -> 'devolver'
--             SELECT fn_decision_adelanto(2, DATE '2026-11-04');  -- falta 1 día        -> 'penalizar'
-- -----------------------------------------------------------------------------
CREATE FUNCTION fn_decision_adelanto(p_id_reservacion INTEGER, p_fecha_cancelacion DATE)
RETURNS VARCHAR
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_entrada  DATE;
    v_adelanto NUMERIC(12,2);
    v_dias     INTEGER;
BEGIN
    SELECT fecha_entrada_prevista INTO v_entrada
      FROM reservacion
     WHERE id_reservacion = p_id_reservacion;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La reservación % no existe', p_id_reservacion;
    END IF;

    SELECT COALESCE(SUM(monto), 0) INTO v_adelanto
      FROM pago
     WHERE id_reservacion = p_id_reservacion AND tipo = 'adelanto';

    IF v_adelanto = 0 THEN
        RETURN NULL;                       -- no hay adelanto sobre el cual decidir
    END IF;

    v_dias := v_entrada - p_fecha_cancelacion;

    RETURN CASE
               WHEN v_dias >= 2 THEN 'devolver'
               ELSE 'penalizar'
           END;
END;
$$;

-- -----------------------------------------------------------------------------
-- C2  sp_cancelar_reservacion
-- Operación de negocio: cancelar una reservación. Toca tres tablas:
--   reservacion               -> estado = 'cancelada' y decision_adelanto
--   modificacion_reservacion  -> deja el historial (RN-14: cuándo y quién)
--   pago                      -> solo lectura, a través de fn_decision_adelanto
-- Parámetros: p_id_reservacion, p_solicitante (quién pide la cancelación),
--             p_fecha_cancelacion (por defecto, el momento actual).
-- Validaciones (cada una rechaza con RAISE EXCEPTION y un mensaje claro):
--   1. el solicitante no puede estar vacío;
--   2. la reservación debe existir;
--   3. solo se cancelan reservaciones 'solicitada' o 'confirmada';
--   4. no se cancela después de la fecha de entrada (eso es 'no presentada').
-- Concurrencia: SELECT ... FOR UPDATE bloquea la fila de la reservación, de modo
-- que dos cancelaciones simultáneas no calculen el mismo id_modificacion.
-- Ejemplo   : CALL sp_cancelar_reservacion(2, 'Carlos Rojas Solano', TIMESTAMP '2026-10-20 09:00');
-- -----------------------------------------------------------------------------
CREATE PROCEDURE sp_cancelar_reservacion(
    p_id_reservacion    INTEGER,
    p_solicitante       VARCHAR,
    p_fecha_cancelacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP)
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado   VARCHAR(30);
    v_entrada  DATE;
    v_decision VARCHAR(10);
    v_siguiente INTEGER;
    v_dias     INTEGER;
BEGIN
    IF p_solicitante IS NULL OR btrim(p_solicitante) = '' THEN
        RAISE EXCEPTION 'Debe indicarse quién solicita la cancelación (RN-14)';
    END IF;

    SELECT estado, fecha_entrada_prevista
      INTO v_estado, v_entrada
      FROM reservacion
     WHERE id_reservacion = p_id_reservacion
       FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La reservación % no existe', p_id_reservacion;
    END IF;

    IF v_estado NOT IN ('solicitada', 'confirmada') THEN
        RAISE EXCEPTION 'La reservación % no se puede cancelar: su estado actual es "%"',
                        p_id_reservacion, v_estado;
    END IF;

    IF p_fecha_cancelacion::date > v_entrada THEN
        RAISE EXCEPTION 'La reservación % no se puede cancelar después de su fecha de entrada (%); debe marcarse como no presentada',
                        p_id_reservacion, v_entrada;
    END IF;

    v_decision := fn_decision_adelanto(p_id_reservacion, p_fecha_cancelacion::date);
    v_dias     := v_entrada - p_fecha_cancelacion::date;

    UPDATE reservacion
       SET estado = 'cancelada',
           decision_adelanto = v_decision
     WHERE id_reservacion = p_id_reservacion;

    SELECT COALESCE(MAX(id_modificacion), 0) + 1
      INTO v_siguiente
      FROM modificacion_reservacion
     WHERE id_reservacion = p_id_reservacion;

    INSERT INTO modificacion_reservacion
           (id_reservacion, id_modificacion, fecha_hora_modificacion, tipo_modificacion,
            solicitante, genero_cambio_precio, diferencia_precio, descripcion_cambio)
    VALUES (p_id_reservacion, v_siguiente, p_fecha_cancelacion, 'cancelacion',
            btrim(p_solicitante), FALSE, NULL,
            format('Cancelación con %s días de anticipación; decisión sobre el adelanto: %s',
                   v_dias, COALESCE(v_decision, 'sin adelanto recibido')));

    RAISE NOTICE 'Reservación % cancelada. Decisión sobre el adelanto: %',
                 p_id_reservacion, COALESCE(v_decision, 'sin adelanto recibido');
END;
$$;

-- -----------------------------------------------------------------------------
-- C3  Técnica adicional: CURSOR EXPLÍCITO
-- sp_marcar_reservaciones_vencidas
-- Operación : pasar a 'vencida' las reservaciones 'solicitada' que exigen adelanto,
--             llevan más de p_dias_vigencia días desde su solicitud y no lo han pagado.
--             Cada vencimiento deja su registro en modificacion_reservacion.
-- Parámetros: p_fecha_corte (fecha contra la que se mide la vigencia),
--             p_dias_vigencia (por defecto 7; SUPUESTO del laboratorio, el caso
--             solo dice que una reservación puede estar "vencida").
-- Por qué un cursor: se recorre fila por fila para dejar un aviso (RAISE NOTICE)
-- por cada reservación vencida y se actualiza con WHERE CURRENT OF, que garantiza
-- modificar exactamente la fila recorrida bajo el bloqueo FOR UPDATE.
-- Discusión honesta: el mismo resultado se obtiene con una sola sentencia basada
-- en conjuntos (procedimiento siguiente). Esa alternativa es más simple y rápida
-- para volúmenes grandes; el cursor se justifica aquí por la trazabilidad fila a
-- fila y por ser la técnica pedida en el laboratorio, no por necesidad técnica.
-- Ejemplo   : CALL sp_marcar_reservaciones_vencidas(DATE '2026-10-25');
-- -----------------------------------------------------------------------------
CREATE PROCEDURE sp_marcar_reservaciones_vencidas(
    p_fecha_corte   DATE,
    p_dias_vigencia INTEGER DEFAULT 7)
LANGUAGE plpgsql
AS $$
DECLARE
    cur_pendientes CURSOR (c_limite DATE) FOR
        SELECT r.id_reservacion, r.fecha_solicitud
          FROM reservacion r
         WHERE r.estado = 'solicitada'
           AND r.adelanto_requerido > 0
           AND r.fecha_solicitud < c_limite
           AND NOT EXISTS (SELECT 1
                             FROM pago p
                            WHERE p.id_reservacion = r.id_reservacion
                              AND p.tipo = 'adelanto')
         ORDER BY r.id_reservacion
           FOR UPDATE OF r;
    v_reg       RECORD;
    v_siguiente INTEGER;
    v_total     INTEGER := 0;
BEGIN
    IF p_fecha_corte IS NULL OR p_dias_vigencia IS NULL OR p_dias_vigencia < 0 THEN
        RAISE EXCEPTION 'Se requiere una fecha de corte y una vigencia en días no negativa';
    END IF;

    OPEN cur_pendientes(p_fecha_corte - p_dias_vigencia);
    LOOP
        FETCH cur_pendientes INTO v_reg;
        EXIT WHEN NOT FOUND;

        UPDATE reservacion
           SET estado = 'vencida'
         WHERE CURRENT OF cur_pendientes;

        SELECT COALESCE(MAX(id_modificacion), 0) + 1
          INTO v_siguiente
          FROM modificacion_reservacion
         WHERE id_reservacion = v_reg.id_reservacion;

        INSERT INTO modificacion_reservacion
               (id_reservacion, id_modificacion, fecha_hora_modificacion, tipo_modificacion,
                solicitante, genero_cambio_precio, descripcion_cambio)
        VALUES (v_reg.id_reservacion, v_siguiente, p_fecha_corte::timestamp, 'cancelacion',
                'sistema', FALSE,
                format('Vencida: adelanto no recibido en %s días desde la solicitud (%s)',
                       p_dias_vigencia, v_reg.fecha_solicitud));

        v_total := v_total + 1;
        RAISE NOTICE 'Reservación % marcada como vencida', v_reg.id_reservacion;
    END LOOP;
    CLOSE cur_pendientes;

    RAISE NOTICE 'Reservaciones vencidas en esta corrida: %', v_total;
END;
$$;

-- Alternativa basada en conjuntos (misma regla, una sola sentencia con CTE).
-- Ejemplo   : CALL sp_marcar_reservaciones_vencidas_conjunto(DATE '2026-10-25');
CREATE PROCEDURE sp_marcar_reservaciones_vencidas_conjunto(
    p_fecha_corte   DATE,
    p_dias_vigencia INTEGER DEFAULT 7)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total INTEGER;
BEGIN
    IF p_fecha_corte IS NULL OR p_dias_vigencia IS NULL OR p_dias_vigencia < 0 THEN
        RAISE EXCEPTION 'Se requiere una fecha de corte y una vigencia en días no negativa';
    END IF;

    WITH vencidas AS (
        UPDATE reservacion r
           SET estado = 'vencida'
         WHERE r.estado = 'solicitada'
           AND r.adelanto_requerido > 0
           AND r.fecha_solicitud < p_fecha_corte - p_dias_vigencia
           AND NOT EXISTS (SELECT 1
                             FROM pago p
                            WHERE p.id_reservacion = r.id_reservacion
                              AND p.tipo = 'adelanto')
        RETURNING r.id_reservacion, r.fecha_solicitud
    ), historial AS (
        INSERT INTO modificacion_reservacion
               (id_reservacion, id_modificacion, fecha_hora_modificacion, tipo_modificacion,
                solicitante, genero_cambio_precio, descripcion_cambio)
        SELECT v.id_reservacion,
               COALESCE((SELECT MAX(m.id_modificacion)
                           FROM modificacion_reservacion m
                          WHERE m.id_reservacion = v.id_reservacion), 0) + 1,
               p_fecha_corte::timestamp, 'cancelacion', 'sistema', FALSE,
               format('Vencida: adelanto no recibido en %s días desde la solicitud (%s)',
                      p_dias_vigencia, v.fecha_solicitud)
          FROM vencidas v
        RETURNING 1
    )
    SELECT COUNT(*) INTO v_total FROM historial;

    RAISE NOTICE 'Reservaciones vencidas en esta corrida: %', v_total;
END;
$$;
