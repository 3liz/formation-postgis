# Grouper des données et calculer des statistiques

[Les fonctions d'agrégat dans PostgreSQL](https://docs.postgresql.fr/14/functions-aggregate.html)

## Valeurs distinctes d'un champ

On souhaite récupérer **toutes les valeurs possibles** d'un champ

```sql
-- Vérifier les valeurs distinctes d'un champ: table commune
SELECT DISTINCT depart
FROM z_formation.commune
ORDER BY depart

-- idem sur la table lieu_dit_habite
SELECT DISTINCT nature
FROM z_formation.lieu_dit_habite
ORDER BY nature
```


## Regrouper des données en spécifiant les champs de regroupement

Certains calculs nécessitent le regroupement de lignes, comme les moyennes, les sommes ou les totaux. Pour cela, il faut réaliser un **regroupement** via la clause **GROUP BY**

**Compter** les communes par département et calculer la **population totale**

```sql
-- Regrouper des données
-- Compter le nombre de communes par département
SELECT depart,
count(code_insee) AS nb_commune,
sum(population) AS total_population
FROM z_formation.commune
WHERE True
GROUP BY depart
ORDER BY nb_commune DESC
```

Calculer des **statistiques sur l'aire** des communes pour chaque département


```sql
SELECT depart,
count(id_commune) AS nb,
min(ST_Area(geom)/10000)::int AS min_aire_ha,
max(ST_Area(geom)/10000)::int AS max_aire_ha,
avg(ST_Area(geom)/10000)::int AS moy_aire_ha,
sum(ST_Area(geom)/10000)::int AS total_aire_ha
FROM z_formation.commune
GROUP BY depart
```

**Compter** le nombre de routes par nature

```sql
-- Compter le nombre de routes par nature
SELECT count(id_route) AS nb_route, nature
FROM z_formation.route
WHERE True
GROUP BY nature
ORDER BY nb_route DESC
```

Compter le nombre de routes par nature et par sens

```sql
SELECT count(id_route) AS nb_route, nature, sens
FROM z_formation.route
WHERE True
GROUP BY nature, sens
ORDER BY nature, sens DESC
```

Les caculs sur des ensembles groupés peuvent aussi être réalisé **sur les géométries.**. Les plus utilisés sont

* **ST_Collect** qui regroupe les géométries dans une multi-géométrie,
* **ST_Union** qui fusionne les géométries.

Par exemple, on peut souhaiter trouver l'**enveloppe convexe** autour de points (élastique tendu autour d'un groupe de points). Ici, nous regroupons les lieux-dits par nature (ce qui n'a pas beaucoup de sens, mais c'est pour l'exemple). Dans ce cas, il faut faire une sous-requête pour filtrer seulement les résultats de type polygone (car s'il y a seulement 1 ou 2 objets par nature, alors on ne peut créer de polygone)


```sql
SELECT *
FROM (
        SELECT
        nature,
        -- ST_Convexhull renvoie l'enveloppe convexe
        ST_Convexhull(ST_Collect(geom)) AS geom
        FROM z_formation.lieu_dit_habite
        GROUP BY nature
) AS source
-- GeometryType renvoie le type de géométrie
WHERE Geometrytype(geom) = 'POLYGON'
```

Attention, on doit donner un alias à la sous-requête (ici `source`)


Un autre exemple sur les bornes. Ici, on groupe les bornes par identifiant pair ou impair, et on calcule l'enveloppe convexe

```sql
SELECT count(id_borne), ((id_borne % 2) = 0) AS pair,
(st_convexhull(ST_Collect(geom))) AS geom
FROM z_formation.borne_incendie
GROUP BY pair
```


On peut réaliser l'équivalent d'un **DISSOLVE** de QGIS en regroupant les géométries via **ST_Union**. Par exemple fusionner l'ensemble des communes pour construire les géométries des départements:

```sql
SELECT
depart,
count(id_commune) AS nb_com,
-- ST_Union crée une seule géométrie en fusionnant les géométries.
ST_Union(geom) AS geom

FROM z_formation.commune

GROUP BY depart
```

Attention, cette requête est lourde, et devra être enregistrée comme une table.

Continuer vers [Rassembler des données: UNION ALL](./union.md)

## Quiz
<details>
  <summary>Écrire une requête retournant pour les départements 'SEINE-MARITIME' et 'EURE', le nom, le nombre de communes ainsi que la surface et la surface de l'enveloppe convexe sous forme d'entier</summary>
  
  ```sql
  SELECT depart,
  count(id_commune) AS nb_commune,
  ST_Area(ST_Collect(geom))::int8 AS surface,
  ST_Area(ST_Convexhull(ST_Collect(geom)))::int8 AS surface_enveloppe_convexe
  FROM z_formation.commune
  WHERE depart IN ('SEINE-MARITIME', 'EURE')
  GROUP BY depart
  ```
</details>
