"""Ejecuta el pipeline SQL en orden (staging -> dimensión -> mart -> pruebas).
Runs the SQL pipeline in order.  Uso / Usage:  python ejecutar.py
"""
import sys
from pathlib import Path

import duckdb

RAIZ = Path(__file__).parent
con = duckdb.connect(str(RAIZ / "datos" / "andina.duckdb"))
errores = 0
for archivo in sorted((RAIZ / "sql").glob("*.sql")):
    print(f"\n=== {archivo.name} ===")
    sentencias = [s for s in archivo.read_text(encoding="utf-8").split(";") if s.strip()]
    for sentencia in sentencias:
        resultado = con.execute(sentencia)
        if resultado.description and resultado.description[0][0] != "Count":
            tabla = resultado.fetchdf()
            print(tabla.to_string(index=False))
            if archivo.name.startswith("05"):
                errores = int(tabla["filas_con_error"].sum())
con.close()
print("\nPruebas de calidad:", "APROBADAS" if errores == 0 else f"{errores} filas con error")
sys.exit(1 if errores else 0)
