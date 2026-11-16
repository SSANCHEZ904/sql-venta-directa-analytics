"""Genera datos 100 % sintéticos de una empresa ficticia de venta directa
("Andina Belleza") y los carga en una base DuckDB local.

Generates fully synthetic data for a fictional direct-sales company.
Uso / Usage:  python datos/generar_datos.py
"""
import random
from datetime import datetime, timedelta
from pathlib import Path

import duckdb

random.seed(42)
RUTA_DB = Path(__file__).parent / "andina.duckdb"

# El negocio opera con 17 ciclos por año (formato AAAACC); el rango cruza el cambio de año.
CICLOS = [202513, 202514, 202515, 202516, 202517,
          202601, 202602, 202603, 202604, 202605, 202606]
PAISES = {170: ("Colombia", "COP", 4000.0), 604: ("Perú", "PEN", 3.7), 218: ("Ecuador", "USD", 1.0)}
NOMBRES = ["Ana Rojas", "Luz Pérez", "Marta Gil", "Rosa Díaz", "Elena Ruiz", "Paola Mora",
           "Sara León", "Julia Vega", "Carla Soto", "Diana Cruz", "Nora Pino", "Irene Lara"]

estructura, indice, metas, cambio = [], [], [], []
deuda_col, deuda_per = [], []

for pais, (_, _, tasa) in PAISES.items():
    for ciclo in CICLOS:
        cambio.append((pais, ciclo, round(tasa * random.uniform(0.97, 1.03), 4)))

    grupos = []
    for s in range(1, 5):                      # 4 sectores por país
        sector = pais * 100 + s
        for g in range(1, 4):                  # 3 grupos por sector
            grupo = sector * 10 + g
            lider = random.choice(NOMBRES)
            grupos.append((sector, grupo, lider))

    for sector, grupo, lider in grupos:
        sin_lider = random.random() < 0.10     # ~10 % de grupos sin responsable
        for ciclo in CICLOS:
            texto = f"{grupo} - SIN RESPONSABLE" if sin_lider else f"{grupo} - LN - {lider}"
            estructura.append((pais, ciclo, grupo, sector, f"Sector {sector}", texto))

    for sector in sorted({g[0] for g in grupos}):
        for ciclo in CICLOS:
            metas.append((pais, ciclo, sector,
                          round(random.uniform(5200, 6800) * tasa, 2), random.randint(20, 26)))

    consultora = pais * 10000
    for sector, grupo, lider in grupos:
        # El índice transaccional no siempre trae el nombre del líder (caso real a resolver).
        lider_en_indice = None if random.random() < 0.30 else lider
        for _ in range(random.randint(8, 12)):
            consultora += 1
            for ciclo in CICLOS:
                activa = random.random() < 0.72
                fact = round(random.uniform(60, 420) * tasa, 2) if activa else 0.0
                pedidos = random.randint(1, 3) if activa else 0
                base = datetime(2025, 9, 1) + timedelta(days=21 * CICLOS.index(ciclo))
                indice.append((pais, ciclo, consultora, grupo, sector, lider_en_indice,
                               fact, pedidos, activa, base))
                if random.random() < 0.06:     # fila reprocesada: duplicado con fecha posterior
                    indice.append((pais, ciclo, consultora, grupo, sector, lider_en_indice,
                                   round(fact * 1.05, 2), pedidos, activa, base + timedelta(days=2)))
            if random.random() < 0.25:
                if pais == 170:
                    deuda_col.append((consultora, round(random.uniform(50, 900) * tasa, 2),
                                      random.randint(1, 120)))
                elif pais == 604:              # Perú llega con otro esquema y la llave como texto
                    deuda_per.append((str(consultora), round(random.uniform(50, 900) * tasa, 2),
                                      random.randint(1, 120)))

RUTA_DB.unlink(missing_ok=True)
con = duckdb.connect(str(RUTA_DB))
con.execute("""
CREATE TABLE raw_indice_consultoras (pais_cod INT, ciclo INT, consultora_cod INT, grupo_cod INT,
    sector_cod INT, lider_nombre VARCHAR, facturacion_local DOUBLE, pedidos INT, activa BOOLEAN,
    actualizado_en TIMESTAMP);
CREATE TABLE raw_estructura (pais_cod INT, ciclo INT, grupo_cod INT, sector_cod INT,
    sector_nombre VARCHAR, estructura_nombre VARCHAR);
CREATE TABLE raw_metas (pais_cod INT, ciclo INT, sector_cod INT, meta_facturacion DOUBLE, meta_activas INT);
CREATE TABLE raw_tipo_cambio (pais_cod INT, ciclo INT, tasa_usd DOUBLE);
CREATE TABLE raw_deuda_col (consultora_id INT, saldo DOUBLE, dias_mora INT);
CREATE TABLE raw_deuda_per (cod_consultora VARCHAR, monto_pendiente DOUBLE, dias_atraso INT);
""")
con.executemany("INSERT INTO raw_indice_consultoras VALUES (?,?,?,?,?,?,?,?,?,?)", indice)
con.executemany("INSERT INTO raw_estructura VALUES (?,?,?,?,?,?)", estructura)
con.executemany("INSERT INTO raw_metas VALUES (?,?,?,?,?)", metas)
con.executemany("INSERT INTO raw_tipo_cambio VALUES (?,?,?)", cambio)
con.executemany("INSERT INTO raw_deuda_col VALUES (?,?,?)", deuda_col)
con.executemany("INSERT INTO raw_deuda_per VALUES (?,?,?)", deuda_per)
for t in ["raw_indice_consultoras", "raw_estructura", "raw_metas", "raw_tipo_cambio",
          "raw_deuda_col", "raw_deuda_per"]:
    print(f"{t:26s} {con.execute(f'SELECT COUNT(*) FROM {t}').fetchone()[0]:>6} filas")
con.close()
