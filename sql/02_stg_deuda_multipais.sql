-- 02 · Staging: deuda unificada de dos países con esquemas distintos
-- Colombia y Perú llegan en tablas con nombres de columna y tipos de llave diferentes.
-- Solución: UNION ALL con columnas homologadas y CAST de la llave de cruce.
CREATE OR REPLACE VIEW stg_deuda AS
SELECT
    170                                   AS pais_cod,
    consultora_id                         AS consultora_cod,
    saldo                                 AS deuda_local,
    dias_mora
FROM raw_deuda_col
UNION ALL
SELECT
    604                                   AS pais_cod,
    CAST(cod_consultora AS INT)           AS consultora_cod,
    monto_pendiente                       AS deuda_local,
    dias_atraso                           AS dias_mora
FROM raw_deuda_per;

SELECT
    pais_cod,
    COUNT(*)                                             AS consultoras_con_deuda,
    ROUND(AVG(dias_mora), 1)                             AS dias_mora_promedio,
    SUM(CASE WHEN dias_mora > 60 THEN 1 ELSE 0 END)      AS en_mora_mayor_60
FROM stg_deuda
GROUP BY pais_cod
ORDER BY pais_cod;
