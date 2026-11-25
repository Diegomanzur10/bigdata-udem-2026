# Diagrama de la estrella · Taller 1

Equipo: Natasha Orozco, Miguel Angel Vélez y Xiomy Baquero
Caso: A · Competencia entre plataformas

Grano (el mismo de la primera línea de `01_estrella.sql`): Una fila por fecha, zona de recogida y empresa.

Reemplaza el diagrama de abajo por el de tu estrella: una tabla de hechos al centro y al menos dos
dimensiones, cada una con su clave. GitHub dibuja el bloque `mermaid` al abrir este archivo. Si
prefieres una imagen, súbela como `diagrama.png` a esta carpeta y deja aquí un enlace a ella.

![Diagrama del modelo estrella](./diagrama.png)

## Claves

| Dimensión | Clave | Por qué es única |
|---|---|---|
| DIM_FECHA | FECHA | Se genera un único registro por cada día del período analizado, garantizando que no existan fechas duplicadas. |
| DIM_ZONA | ZONA_KEY | Cada zona tiene una clave sustituta única (ZONA_KEY). Durante la carga se agrupan los registros por nombre de zona para evitar duplicidades que puedan alterar las métricas de la tabla de hechos |
| DIM_EMPRESA | EMPRESA_KEY | Cada empresa recibe una clave diferente generada desde los nombres unicos de las empresas mediante SELECT DISTINCT  |
