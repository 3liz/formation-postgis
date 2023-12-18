# Faire des calculs

## Calcul sur des attributs

Le SQL permet de réaliser des calculs ou des modifications à partir de champs. On peut donc faire des calculs sur des nombres, ou des modifications (remplacement de texte, mise en majuscule, etc.)

Faire un calcul très simple, avec des opérateurs `+ - /` et `*`, ainsi que des parenthèses

```sql
-- On multiplie 10 par 2
SELECT
10 * 2 AS vingt,
(2.5 -1) * 10 AS quinze
```

Il est aussi possible de faire des calculs à partir d'un ou plusieurs champs.

Nous souhaitons par exemple créer un champ qui contiendra la **population** des communes. Dans la donnée source, le champ `popul` est de type chaîne de caractère, car il contient parfois la valeur `'NC'` lorsque la population n'est pas connue.

Nous ne pouvons pas faire de calculs à partir d'un champ texte. On souhaite donc **créer un nouveau champ** population pour y stocker les valeurs entières.

```sql
-- Ajout d'un champ de type entier dans la table
ALTER TABLE z_formation.commune ADD COLUMN population integer;
```

**Modifier** le nouveau champ population pour y mettre la valeur entière lorsqu'elle est connue. La modification d'une table se fait avec la requête `UPDATE`, en passant les champs à modifier et leur nouvelle valeur via `SET`

```sql
-- Mise à jour d'un champ à partir d'un calcul
UPDATE z_formation.commune SET population =
CASE
        WHEN popul != 'NC' THEN popul::integer
        ELSE NULL
END
;
```

Dans cette requête, le `CASE WHEN condition THEN valeur ELSE autre_valeur END` permet de faire un test sur la valeur d'origine, et de proposer une valeur si la condition est remplie ( https://sql.sh/cours/case )

Une fois ce champ `population` renseigné correctement, dans un type entier, on peut réaliser un calcul très simple, par exemple **doubler la population**:

```sql
-- Calcul simple : on peut utiliser les opérateurs mathématiques
SELECT id_commune, code_insee, nom, geom,
population,
population * 2 AS double_population
FROM z_formation.commune
LIMIT 10
```

Il est possible de **combiner plusieurs champs** pour réaliser un calcul. Nous verrons plus loin comment calculer la **densité de population** à partir de la population et de la surface des communes.

## Calculer des caractéristiques spatiales

Par exemple la **longueur** ou la **surface**

Calculer la longueur d'objets linéaires

```sql
-- Calcul des longueurs de route
SELECT id_route, id, nature,
ST_Length(geom) AS longueur_m
FROM z_formation.route
LIMIT 100
```

Calculer la **surface** de polygones, et utiliser ce résultat dans un calcul. Par exemple ici la **densité de population**:

```sql
-- Calculer des données à partir de champs et de fonctions spatiales
SELECT id_commune, code_insee, nom, geom,
population,
ST_Area(geom) AS surface,
population / ( ST_Area(geom) / 1000000 ) AS densite_hab_km
FROM z_formation.commune
LIMIT 10
```

## Créer des géométries à partir de géométries

On peut modifier les géométries avec des fonctions spatiales, ce qui revient à effectuer un calcul sur les géométries. Deux exemples classiques : **centroides** et **tampons**

Calculer le **centroïde** de polygones

```sql
-- Centroides des communes
SELECT id_commune, code_insee, nom,
ST_Centroid(geom) AS geom
FROM z_formation.commune
```

Le centroïde peut ne pas être à l'intérieur du polygone, par exemple sur la commune de **Arnières-sur-Iton**.
Forcer le **centroïde à l'intérieur du polygone**. Attention, ce calcul est plus long.
[Si vous souhaitez mieux comprendre l'algorithme derrière cette fonction](https://gis.stackexchange.com/questions/76498/how-is-st-pointonsurface-calculated)

```sql
-- Centroïdes à l'intérieur des communes
-- Attention, c'est plus long à calculer
SELECT id_commune, code_insee, nom,
ST_PointOnSurface(geom) AS geom
FROM z_formation.commune
```

Calculer le **tampon** autour d'objets

```sql
-- Tampons de 1km autour des communes
SELECT id_commune, nom, population,
ST_Buffer(geom, 1000) AS geom
FROM z_formation.commune
LIMIT 10
```

Continuer vers [Filtrer des données: WHERE](./filter_data.md)
