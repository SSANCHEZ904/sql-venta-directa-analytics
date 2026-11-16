-- 01 · Staging: una fila por consultora y ciclo
-- Problema: la fuente trae filas reprocesadas (duplicados con distinta fecha de actualización).
-- Solución: ROW_NUMBER() por la llave de negocio y QUALIFY para quedarse con la más reciente.
CREATE OR REPLACE VIEW stg_consultoras AS
SELECT
    pais_cod,
    ciclo,
    consultora_cod,
    grupo_cod,
    sector_cod,
    lider_nombre,
    facturacion_local,
    pedidos,
    activa
FROM raw_indice_consultoras
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY pais_cod, ciclo, consultora_cod
    ORDER BY actualizado_en DESC NULLS LAST
) = 1;

SELECT
    (SELECT COUNT(*) FROM raw_indice_consultoras) AS filas_origen,
    (SELECT COUNT(*) FROM stg_consultoras)        AS filas_sin_duplicados;
