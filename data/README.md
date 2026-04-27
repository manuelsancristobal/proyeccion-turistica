# Datos: Proyección Turística

## Origen
- **Llegadas de Turistas**: Subsecretaría de Turismo (Chile).
- **Salidas de Chilenos**: Subsecretaría de Turismo (Chile).
- **Tráfico Aéreo**: JAC (Junta de Aeronáutica Civil).
- **Modelos**: Proyecciones basadas en series de tiempo (R/Python).

## Estructura
- `raw/`: 
  - `llegadas/`: Microdatos de llegadas por nacionalidad y paso fronterizo.
  - `salidas/`: Datos históricos de turismo emisivo.
  - `trafico_aereo/`: Serie histórica de pasajeros JAC.
- `processed/`: Resultados del pipeline ETL y proyecciones consolidadas.
- `external/`: Datos económicos externos para modelos predictivos (si aplica).

## Diccionario de Datos Clave
- `Llegadas`: Cantidad de turistas extranjeros ingresando al país.
- `Salidas`: Cantidad de chilenos residentes saliendo al extranjero.
- `Pasajeros`: Flujo total de pasajeros transportados por vía aérea.
