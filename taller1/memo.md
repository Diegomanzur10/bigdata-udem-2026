# Memo · Competencia entre Uber y Lyft en Nueva York (Taller 1)

Equipo: Natasha Orozco, Miguel Ángel Vélez y Xiomy Baquero · Anfitrión: Natasha Orozco · Caso: A · Fecha: 13/11/2026


## Pregunta y decisión

**¿Una sola plataforma concentra la mayoría de los viajes en las distintas zonas de Nueva York y cómo cambia su participación entre enero y marzo de 2024?**
Este análisis permite a la autoridad de movilidad identificar las zonas donde predomina Uber o Lyft y determinar dónde sería conveniente fortalecer el seguimiento y la supervisión del servicio.

## Hallazgos

1. **Uber concentra la mayor parte de los viajes.** Durante el período analizado, registró aproximadamente el 74% de los 60,3 millones de viajes y el 74% de los ingresos totales (1.383 millones de dólares). Lyft representó el 26% restante. Esto muestra una diferencia importante en la participación de ambas plataformas, aunque no permite concluir cuál es más rentable ni si existe competencia desleal.
2. **Lyft presentó un mayor crecimiento en marzo.** Sus viajes aumentaron un 14% respecto a febrero, mientras que los de Uber crecieron un 8,5%. Aunque Uber continuó liderando el mercado, Lyft mostró un crecimiento más acelerado durante ese mes. Sin embargo, este resultado no permite asegurar que la tendencia se mantenga durante el resto del año.
3. **Los usuarios de Lyft dejaron propinas ligeramente superiores.** El promedio fue de 1,18 dólares por viaje, frente a 1,06 dólares en Uber, considerando la cantidad de viajes de cada plataforma. Esta diferencia no significa necesariamente que una ofrezca un mejor servicio, ya que pueden influir las características de los recorridos y de los pasajeros.
4. **El predominio de Uber varía según la zona y el mes.** En febrero se identificaron 31 zonas donde su participación superó el 70%, después de encontrarse en ese nivel o por debajo. En marzo, 16 zonas descendieron a ese umbral o menos. Estos cambios sugieren que la participación de las plataformas no es completamente estable, aunque pequeñas variaciones pueden producir cruces del 70% sin representar transformaciones importantes del mercado.

## Supuestos y definiciones

- **Zonas con pocos viajes:** Para analizar los cambios mensuales en la participación de Uber y Lyft, se consideraron únicamente zonas con al menos 100 viajes por mes. Se excluyeron 14 combinaciones de zona y mes (1,8% del total analizado), ya que un volumen muy bajo puede generar cambios porcentuales exagerados. Esta exclusión se aplicó únicamente al análisis de variaciones; los viajes originales se conservaron.
- **Participación superior al 70%:** Se considera un cambio relevante cuando una plataforma pasa de tener el 70% o menos de los viajes de una zona a superar ese porcentaje, o cuando ocurre lo contrario. Este límite fue establecido en el enunciado del taller.
- **Identificación de zonas:** Se unificaron los nombres repetidos para evitar contar viajes más de una vez. El catálogo contiene 262 zonas distintas, mientras que los datos analizados registran actividad en 261. Se verificó que esta diferencia no representa pérdida de información, porque se conservaron los 46.715 registros y los 60.268.466 viajes originales.
- **Cálculo de propinas:** El promedio se calculó teniendo en cuenta la cantidad de viajes de cada grupo, para que los grupos con pocos viajes no tengan el mismo peso que los de mayor volumen. Los valores son aproximados porque los datos originales estaban redondeados.


## Trampa evitada

**Trampa: 2 - Promediar sin considerar la cantidad de viajes.**

Si calculáramos el promedio de las propinas de Uber y Lyft dando la misma importancia a ambas plataformas, obtendríamos 1,12 dólares por viaje. Sin embargo, al considerar que Uber registra un número significativamente mayor de viajes, el promedio conjunto es aproximadamente de 1,09 dólares.
Para evitar esta distorsión, calculamos el promedio teniendo en cuenta la cantidad de viajes de cada plataforma. Así obtenemos un resultado más representativo del comportamiento general de las propinas.


## Límites

El análisis comprende únicamente los tres primeros meses de 2024, por lo que no es posible determinar si los cambios observados en marzo se mantienen durante el resto del año. Además, no se evaluó cómo factores como la lluvia, los festivos, las zonas o las características de los viajes pueden influir en la demanda y las propinas.
Por otra parte, pequeñas variaciones en la cantidad de viajes pueden hacer que una plataforma supere o descienda del 70 % de participación, sin que esto represente necesariamente un cambio importante en el mercado. Se recomienda realizar un seguimiento mensual de la participación de ambas plataformas por zona y ampliar el período de análisis antes de adoptar decisiones definitivas.
