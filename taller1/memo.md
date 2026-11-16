# Memo · ¿La lluvia cambia los viajes en NYC? (Taller 1)

Equipo: Valentina Restrepo Arboleda y Andres Fernando Molina Orozco. · Anfitrión: Valentina Restrepo Arboleda · Caso: A · Fecha: 15 de noviembre de 2026

> Una página. Escribe para una persona que no sabe SQL y debe decidir algo con esto. Borra las
> instrucciones entre «>» al terminar.

## Pregunta y decisión

¿Qué cuota de mercado tiene cada empresa, Uber y Lyft, en cada zona de NYC (la proporción de los viajes de la zona que hace cada una) y cómo cambió entre enero y marzo de 2024? La respuesta ayuda a la autoridad de movilidad a decidir en qué zonas vigilar la competencia entre plataformas.

## Hallazgos

> Tres o cuatro, cada uno con su cifra y una frase que diga qué significa y qué no significa.

1. Uber mueve cerca de tres veces más viajes que Lyft. Entre enero y marzo se registraron 60 268 466 viajes; Uber superó los 14 millones cada mes y Lyft estuvo entre 4 y 5 millones. 
2. Las dos empresas concentran su demanda en los mismos puntos. Las tres zonas con más viajes de ambas son LaGuardia Airport, JFK Airport y East Village. Uber lidera en JFK (más de 810 mil viajes) y Lyft en LaGuardia (cerca de 295 mil). Muestra que la demanda se concentra en aeropuertos.
3. En 34 zonas Uber pasó del 70 % de la cuota del mercado de la zona: 31 lo hicieron en febrero y 3 en marzo. Indica que Uber ganó terreno donde ya era fuerte. 
4. Lyft recibe más propina por viaje: 1,18 USD frente a 1,06 USD de Uber, calculado con el peso de cada grupo. Corresponde a una diferencia de unos 12 centavos
5. Para los fines de semanas y festivo analizados en el primer trimestre del 2024 se encuentra que la empresa de transporte más usado en NYC es UBER con un total de 15.206.603 viajes. 2.8 veces más que lyft con 5.508.694. Los ingresos por dichos viajes también coinciden en una proporcion de 2.8 veces. Uber con 453.115.708,34 USD y Lift con 163.319.086,02 USD.

## Supuestos y definiciones

> Qué decidieron y por qué: por ejemplo, qué es un día con lluvia, cómo trataron el nombre de zona
> repetido, si cuentan Newark como aeropuerto, qué base usaron para comparar.

- Solo se comparan meses seguidos: si una empresa no tuvo viajes en una zona durante un mes, no se supuso que su cuota era 0 %; esa comparación se descartó, para no confundir un cambio entre meses no consecutivos con un cruce. Enero no se evalúa porque no tiene mes anterior, así que los cruces solo pueden ocurrir en febrero y marzo.
- Zona «N/A»: se excluyó de la dimensión de zonas porque no tiene viajes en las tabla de hechos y se considera como una limpieza de null.
- Zonas repetidas: el catálogo traía dos nombres de zona con más de un identificador. Como los datos de viajes identifican la zona solo por su nombre, se dejó una sola fila por nombre y se descartó el identificador numérico. Se pudo hacer sin perder información útil porque los registros repetidos tenían el mismo distrito y tipo de zona. La solución fue aplicada usando el comando DISTINCT() de SQL.

## Trampa evitada

-El nombre de zona repetido. Dos nombres del catálogo (Corona y Governor's Island/Ellis Island/Liberty Island) aparecen con más de un identificador, pero con el mismo distrito y tipo de zona. Unir los viajes por nombre sin cuidado habría sumado 196 filas y 184 265 viajes de más (0,3 %). Para evitarlo, la dimensión de zonas se construyó con una fila por nombre, y comprobamos que el hecho conserva 46 715 filas y 60 268 466 viajes.

## Límites

-No se puede determinar porque Uber tiene más viajes que Lyft. Los datos muestran cuántos viajes hizo cada empresa, no las razones. No se puede afirmar que los usuarios prefieran Uber, porque no hay información de precios, tiempos de espera ni cantidad de conductores disponibles, etc.
-No se puede determinar porque Uber gana en cuota del mercado en las zonas en especifico. No se puede explicar el paso del 70 % en cuota del mercado en las 34 zonas, porque los datos no traen información sobre promociones, situaciones de orden público, tráfico u otros factores que podrían explicarlo.
-No se puede concluír porque Lyft recibe más propina por viaje que Uber. La diferencia de unos 12 centavos podría deberse a un mejor servicio o a más rapidez de sus conductores, pero los datos no permiten comprobarlo.
-No se puede determinar Porque los habitante de NYC prefieren tomar Uber a una escala mucho mayor en los aeropuertos. Se ve que mueve más viajes que Lyft en esos puntos, pero los datos no explican la causa.
