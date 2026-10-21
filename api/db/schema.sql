-- Esquema de la base de datos del módulo Perfil médico (PostgreSQL 16).
-- Es la misma estructura que crea el API al iniciar (SQLAlchemy create_all).
-- Sirve como documentación y para crear las tablas a mano si se necesita.

CREATE TABLE usuario (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(120) NOT NULL,
    correo      VARCHAR(160) NOT NULL UNIQUE,
    creado      TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- Un perfil por usuario (relación 1:1 gracias al UNIQUE en usuario_id).
CREATE TABLE perfil_medico (
    id                SERIAL PRIMARY KEY,
    usuario_id        INTEGER      NOT NULL UNIQUE REFERENCES usuario (id) ON DELETE CASCADE,
    nombre            VARCHAR(120) NOT NULL,
    fecha_nacimiento  DATE,
    tipo_sangre       VARCHAR(12)  NOT NULL,   -- A+, A-, B+, B-, AB+, AB-, O+, O- o desconocido
    actualizado       TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- Alergias, padecimientos y medicamentos en una sola tabla, distinguidos por "tipo".
CREATE TABLE condicion_medica (
    id           SERIAL PRIMARY KEY,
    perfil_id    INTEGER      NOT NULL REFERENCES perfil_medico (id) ON DELETE CASCADE,
    tipo         VARCHAR(20)  NOT NULL,        -- alergia | padecimiento | medicamento
    descripcion  VARCHAR(120) NOT NULL
);

CREATE TABLE contacto_emergencia (
    id          SERIAL PRIMARY KEY,
    perfil_id   INTEGER      NOT NULL REFERENCES perfil_medico (id) ON DELETE CASCADE,
    nombre      VARCHAR(120) NOT NULL,
    parentesco  VARCHAR(40)  NOT NULL,
    telefono    VARCHAR(10)  NOT NULL           -- solo dígitos, 10 posiciones
);
