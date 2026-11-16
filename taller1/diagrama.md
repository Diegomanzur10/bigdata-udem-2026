# Diagrama de la estrella · Taller 1

Equipo: Valentina Restrepo Arboleda y Andres Fernando Molina Orozco.

Grano: Una fila por fecha, zona y empresa.

![Modelo Relacional en Estrella](diagrama.png)

```mermaid
erDiagram
    DIM_FECHA   ||--o{ FACT_VIAJES_DIA : "FECHA"
    DIM_ZONA    ||--o{ FACT_VIAJES_DIA : "ZONA"
    DIM_EMPRESA ||--o{ FACT_VIAJES_DIA : "EMPRESA"

    FACT_VIAJES_DIA {
        date    FECHA
        varchar ZONA
        varchar EMPRESA
        number  VIAJES
        float   INGRESO_TOTAL
        float   PROPINA_PROMEDIO
        float   DISTANCIA_PROMEDIO
    }
    DIM_FECHA {
        date    FECHA PK
        number  ANIO
        number  MES
        varchar DIA_SEMANA
        boolean ES_FIN_SEMANA
        boolean ES_FESTIVO
        float   LLUVIA_MM
    }
    DIM_ZONA {
        varchar ZONA PK
        varchar BOROUGH
        varchar SERVICE_ZONE
    }
    DIM_EMPRESA {
        varchar EMPRESA PK
    }
```


## Claves

| Dimensión | Llave en el hecho | Unión con el hecho | Por qué es única en la dimensión |
|---|---|---|---|
| DIM_FECHA | FECHA | `FACT.FECHA = DIM_FECHA.FECHA` | Se genera un registro por día calendario entre el primero y el último del gold (91 días). |
| DIM_ZONA | ZONA | `FACT.ZONA = DIM_ZONA.ZONA` | `SELECT DISTINCT ZONA, BOROUGH, SERVICE_ZONE` deja 261 filas, una por nombre. Los dos nombres repetidos comparten distrito y tipo de zona. |
| DIM_EMPRESA | EMPRESA | `FACT.EMPRESA = DIM_EMPRESA.EMPRESA` | `SELECT DISTINCT` sobre el gold; el origen no trae identificador y solo existen Uber y Lyft. |
 
La clave del hecho es compuesta (FECHA, ZONA, EMPRESA) y declara el grano.

