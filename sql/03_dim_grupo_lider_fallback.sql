-- 03 · Dimensión de grupo: nombre del líder con respaldo entre fuentes
-- Problema: el índice transaccional no siempre trae el nombre del líder.
-- Solución: COALESCE entre (1) el índice y (2) el texto libre de la estructura oficial
-- ("codigo - rol - nombre"), del que se extrae el último segmento.
-- "SIN RESPONSABLE" se deja visible a propósito: distingue "sin líder" de "sin dato".
CREATE OR REPLACE VIEW dim_grupo AS
WITH estructura_vigente AS (
    SELECT pais_cod, grupo_cod, sector_cod, sector_nombre, estructura_nombre
    FROM raw_estructura
    QUALIFY ROW_NUMBER() OVER (PARTITION BY pais_cod, grupo_cod ORDER BY ciclo DESC) = 1
),
lider_indice AS (
    SELECT pais_cod, grupo_cod, MAX(lider_nombre) AS lider_nombre
    FROM stg_consultoras
    GROUP BY pais_cod, grupo_cod
)
SELECT
    e.pais_cod,
    e.grupo_cod,
    e.sector_cod,                       -- el sector sale de la estructura oficial, no del histórico
    e.sector_nombre,
    COALESCE(
        i.lider_nombre,
        TRIM(list_extract(string_split(e.estructura_nombre, ' - '), -1))
    )                                   AS lider_nombre,
    CASE
        WHEN i.lider_nombre IS NOT NULL THEN 'indice'
        ELSE 'estructura'
    END                                 AS origen_lider
FROM estructura_vigente e
LEFT JOIN lider_indice i
    ON i.pais_cod = e.pais_cod AND i.grupo_cod = e.grupo_cod;

SELECT origen_lider, COUNT(*) AS grupos,
       SUM(CASE WHEN lider_nombre = 'SIN RESPONSABLE' THEN 1 ELSE 0 END) AS sin_responsable
FROM dim_grupo
GROUP BY origen_lider
ORDER BY origen_lider;
