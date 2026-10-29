-- ============================================================================
-- Laboratorio 3 · Huellas Seguras
-- 01_esquema.sql — Definición del esquema físico (PostgreSQL)
-- Proceso de negocio: Subsistema de Salud y Tratamientos de animales.
-- Versión de PostgreSQL utilizada: 16.x
-- ============================================================================
-- Ejecutar sobre una base de datos vacía. No depende de objetos
-- creados manualmente; crea todo lo necesario desde cero.
-- ============================================================================

BEGIN;

CREATE TABLE persona (
    id_persona SERIAL PRIMARY KEY,
    nombre_identificacion VARCHAR(150) NULL
);

CREATE TABLE animal (
    codigo_interno VARCHAR(50) PRIMARY KEY,
    nombre VARCHAR(100) NULL,
    especie VARCHAR(50) NOT NULL,
    sexo VARCHAR(20) NULL,
    color VARCHAR(50) NULL,
    tamano_aproximado VARCHAR(30) NULL,
    edad_estimada INT NULL CHECK (edad_estimada >= 0),
    senas_particulares TEXT NULL,
    numero_microchip VARCHAR(50) UNIQUE NULL
);

CREATE TABLE evaluacion_salud (
    id_evaluacion SERIAL PRIMARY KEY,
    animal_codigo VARCHAR(50) NOT NULL REFERENCES animal(codigo_interno) ON UPDATE CASCADE ON DELETE RESTRICT,
    tipo_evaluacion VARCHAR(40) NOT NULL CHECK (tipo_evaluacion IN ('INICIAL', 'REVISION_VETERINARIA')),
    fecha_evaluacion DATE NOT NULL,
    veterinario_id INT NULL REFERENCES persona(id_persona),
    motivo TEXT NULL,
    observaciones TEXT NULL,
    peso NUMERIC(5,2) NULL CHECK (peso > 0),
    recomendaciones TEXT NULL,
    -- La clave compuesta permite que tablas hijas referencien solo revisiones.
    CONSTRAINT uq_evaluacion_id_tipo UNIQUE (id_evaluacion, tipo_evaluacion),
    CONSTRAINT chk_revision_campos CHECK (
        tipo_evaluacion <> 'REVISION_VETERINARIA' OR (
            veterinario_id IS NOT NULL
            AND NULLIF(BTRIM(motivo), '') IS NOT NULL
            AND NULLIF(BTRIM(observaciones), '') IS NOT NULL
            AND peso IS NOT NULL
            AND NULLIF(BTRIM(recomendaciones), '') IS NOT NULL
        )
    )
);

CREATE TABLE diagnostico (
    id_diagnostico SERIAL PRIMARY KEY,
    nombre_estandarizado VARCHAR(100) UNIQUE NOT NULL
);

CREATE TABLE diagnostico_revision (
    evaluacion_id INT NOT NULL,
    tipo_evaluacion VARCHAR(40) NOT NULL DEFAULT 'REVISION_VETERINARIA'
        CHECK (tipo_evaluacion = 'REVISION_VETERINARIA'),
    diagnostico_id INT NOT NULL REFERENCES diagnostico(id_diagnostico) ON UPDATE CASCADE ON DELETE RESTRICT,
    estado_diagnostico VARCHAR(30) NOT NULL CHECK (estado_diagnostico IN ('PROVISIONAL', 'CONFIRMADO', 'DESCARTADO')),
    PRIMARY KEY (evaluacion_id, diagnostico_id),
    CONSTRAINT fk_diagnostico_revision_evaluacion
        FOREIGN KEY (evaluacion_id, tipo_evaluacion)
        REFERENCES evaluacion_salud(id_evaluacion, tipo_evaluacion) ON DELETE CASCADE
);

CREATE TABLE indicacion (
    id_indicacion SERIAL PRIMARY KEY,
    evaluacion_id INT NOT NULL,
    tipo_evaluacion VARCHAR(40) NOT NULL DEFAULT 'REVISION_VETERINARIA'
        CHECK (tipo_evaluacion = 'REVISION_VETERINARIA'),
    tipo_indicacion VARCHAR(50) NOT NULL CHECK (tipo_indicacion IN ('TRATAMIENTO', 'MEDICAMENTO', 'VACUNA', 'PROCEDIMIENTO', 'CONTROL_POSTERIOR')),
    descripcion TEXT NOT NULL,
    estado_indicacion VARCHAR(30) NULL,
    indicacion_sustituida_id INT NULL REFERENCES indicacion(id_indicacion),
    CONSTRAINT fk_indicacion_revision
        FOREIGN KEY (evaluacion_id, tipo_evaluacion)
        REFERENCES evaluacion_salud(id_evaluacion, tipo_evaluacion) ON DELETE CASCADE
);

CREATE TABLE indicacion_diagnostico (
    indicacion_id INT NOT NULL REFERENCES indicacion(id_indicacion) ON UPDATE CASCADE ON DELETE CASCADE,
    diagnostico_id INT NOT NULL REFERENCES diagnostico(id_diagnostico) ON UPDATE CASCADE ON DELETE RESTRICT,
    PRIMARY KEY (indicacion_id, diagnostico_id)
);

CREATE TABLE aplicacion_indicacion (
    id_aplicacion SERIAL PRIMARY KEY,
    indicacion_id INT NOT NULL REFERENCES indicacion(id_indicacion) ON UPDATE CASCADE ON DELETE CASCADE,
    fecha_planificada DATE NOT NULL,
    fecha_real DATE NULL,
    responsable_id INT NULL REFERENCES persona(id_persona),
    observaciones TEXT NULL,
    CONSTRAINT chk_aplicacion_realizada CHECK (
        fecha_real IS NULL OR (
            responsable_id IS NOT NULL
            AND NULLIF(BTRIM(observaciones), '') IS NOT NULL
        )
    )
);

-- Índices adicionales para optimizar consultas frecuentes de salud
CREATE INDEX idx_evaluacion_animal ON evaluacion_salud(animal_codigo);
CREATE INDEX idx_indicacion_evaluacion ON indicacion(evaluacion_id);
CREATE INDEX idx_aplicacion_indicacion ON aplicacion_indicacion(indicacion_id);

COMMIT;
