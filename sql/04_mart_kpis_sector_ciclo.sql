-- 04 · Mart: KPIs por sector y ciclo (real vs. meta, variación y moneda común)
-- Grano: una fila por país + sector + ciclo.
-- Las sumas en moneda local nunca se mezclan entre países: se convierten a USD con la tasa del ciclo.
CREATE OR REPLACE VIEW mart_kpis_sector AS
WITH reales AS (
    SELECT
        c.pais_cod,
        c.ciclo,
        g.sector_cod,
        MAX(g.sector_nombre)                              AS sector_nombre,
        SUM(c.facturacion_local)                          AS facturacion_local,
        SUM(CASE WHEN c.activa THEN 1 ELSE 0 END)         AS activas,
        COUNT(*)                                          AS disponibles,
        SUM(c.pedidos)                                    AS pedidos
    FROM stg_consultoras c
    JOIN dim_grupo g
        ON g.pais_cod = c.pais_cod AND g.grupo_cod = c.grupo_cod
    GROUP BY c.pais_cod, c.ciclo, g.sector_cod
)
SELECT
    r.pais_cod,
    r.ciclo,
    r.sector_cod,
    r.sector_nombre,
    r.activas,
    ROUND(r.activas * 1.0 / r.disponibles, 4)                         AS pct_actividad,
    ROUND(r.facturacion_local / tc.tasa_usd, 2)                       AS facturacion_usd,
    ROUND(r.facturacion_local / tc.tasa_usd / NULLIF(r.activas, 0), 2) AS productividad_usd,
    ROUND(r.facturacion_local / m.meta_facturacion, 4)                AS cump_facturacion,
    ROUND(r.activas * 1.0 / m.meta_activas, 4)                        AS cump_activas,
    ROUND(r.facturacion_local
          / LAG(r.facturacion_local) OVER (PARTITION BY r.pais_cod, r.sector_cod ORDER BY r.ciclo)
          - 1, 4)                                                     AS var_vs_ciclo_anterior,
    CASE
        WHEN r.facturacion_local / m.meta_facturacion >= 1.00 THEN 'Supera'
        WHEN r.facturacion_local / m.meta_facturacion >= 0.95 THEN 'Atiende'
        ELSE 'Abajo'
    END                                                               AS estado
FROM reales r
JOIN raw_metas m
    ON m.pais_cod = r.pais_cod AND m.ciclo = r.ciclo AND m.sector_cod = r.sector_cod
JOIN raw_tipo_cambio tc
    ON tc.pais_cod = r.pais_cod AND tc.ciclo = r.ciclo;

-- Últimos 3 ciclos disponibles (filtro dinámico: no hay ciclos escritos a mano)
SELECT pais_cod, ciclo, sector_cod, activas, facturacion_usd, productividad_usd,
       cump_facturacion, var_vs_ciclo_anterior, estado
FROM mart_kpis_sector
WHERE ciclo IN (SELECT DISTINCT ciclo FROM stg_consultoras ORDER BY ciclo DESC LIMIT 3)
ORDER BY pais_cod, sector_cod, ciclo
LIMIT 12;
