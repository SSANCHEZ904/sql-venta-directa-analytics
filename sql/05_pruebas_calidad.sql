-- 05 · Pruebas de calidad de datos
-- Cada prueba devuelve el número de filas que incumplen la regla: 0 = aprobada.
SELECT 'stg_consultoras: llave única pais+ciclo+consultora' AS prueba, COUNT(*) AS filas_con_error
FROM (SELECT 1 FROM stg_consultoras GROUP BY pais_cod, ciclo, consultora_cod HAVING COUNT(*) > 1)
UNION ALL
SELECT 'dim_grupo: llave única pais+grupo', COUNT(*)
FROM (SELECT 1 FROM dim_grupo GROUP BY pais_cod, grupo_cod HAVING COUNT(*) > 1)
UNION ALL
SELECT 'dim_grupo: líder sin valor', COUNT(*)
FROM dim_grupo WHERE lider_nombre IS NULL OR lider_nombre = ''
UNION ALL
SELECT 'mart_kpis_sector: grano pais+sector+ciclo', COUNT(*)
FROM (SELECT 1 FROM mart_kpis_sector GROUP BY pais_cod, sector_cod, ciclo HAVING COUNT(*) > 1)
UNION ALL
SELECT 'mart_kpis_sector: todo sector tiene meta y tasa de cambio',
       (SELECT COUNT(*) FROM (SELECT DISTINCT c.pais_cod, c.ciclo, g.sector_cod
                              FROM stg_consultoras c
                              JOIN dim_grupo g ON g.pais_cod = c.pais_cod AND g.grupo_cod = c.grupo_cod))
       - (SELECT COUNT(*) FROM mart_kpis_sector)
UNION ALL
SELECT 'stg_consultoras: inactiva con facturación', COUNT(*)
FROM stg_consultoras WHERE NOT activa AND facturacion_local > 0
UNION ALL
SELECT 'stg_deuda: consultora inexistente en el índice', COUNT(*)
FROM stg_deuda d
WHERE NOT EXISTS (SELECT 1 FROM stg_consultoras c
                  WHERE c.pais_cod = d.pais_cod AND c.consultora_cod = d.consultora_cod);
