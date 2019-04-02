## Vérifier la topologie

#### Déplacer les noeuds sur une grille

Avant de vérifier la topologie, il faut au préalable avoir des géométries valides (cf. chapitre précédent).

Certaines micro-erreurs de topologie peuvent peuvent être corrigées en réalisant une simplification des données à l'aide d'une grille, par exemple pour corriger des soucis d'arrondis. Pour cela, PostGIS a une fonction **ST_SnapToGrid**.

On peut utiliser conjointement **ST_Simplify* et **ST_SnapToGrid** pour effectuer une première correction sur les données. Attention, ces fonctions modifient la donnée. A vous de choisir la bonne tolérance, par exemple 5 cm, qui dépend de votre donnée et de votre cas d'utilisation.

Tester la simplification:

```sql
SELECT
ST_SnapToGrid(
    ST_Multi(
        ST_CollectionExtract(
            ST_MakeValid(
                st_simplify(geom,0)
            ),
            3
        )
    ),
    0.05 -- 5 cm
)
FROM urbanisme.plui_parcelles
;
```

Modifier la table avec la version simplifiée des données

```sql
-- Parcelles
UPDATE urbanisme.plui_parcelles
SET geom = ST_SnapToGrid(
    ST_Multi(
        ST_CollectionExtract(
            ST_MakeValid(
                st_simplify(geom,0)
            ),
            3
        )
    ),
    0.05 -- 5 cm
)
;
```

**Attention:** Si vous avez d'autres tables avec des objets en relation spatiale avec cette table, il faut aussi effectuer le même traitement pour que les géométries de toutes les couches se calent sur la même grille.


#### Repérer certaines erreurs de topologies

PostGIS possède de nombreuses fonctions de **relations spatiales** qui permettent de trouver les objets qui se chevauchent, qui se touchent, etc. Ces fonctions peuvent être utilisées pour comparer les objets d'une même table, ou de deux tables différentes. Voir: https://postgis.net/docs/reference.html#Spatial_Relationships_Measurements

Par exemple, trouver les parcelles voisines qui se recouvrent: on utilise la fonction **ST_Overlaps**. On peut créer une couche listant les recouvrements:


```sql
DROP TABLE IF EXISTS urbanisme.recouvrement_parcelle_voisines;
CREATE TABLE urbanisme.recouvrement_parcelle_voisines AS
SELECT DISTINCT ON (geom)
parcelle_a, parcelle_b, aire_a, aire_b, ST_Area(geom) AS aire, geom
FROM (
        SELECT
        a.gid AS parcelle_a, ST_Area(a.geom) AS aire_a,
        b.gid AS parcelle_b, ST_Area(a.geom) AS aire_b,
        (ST_Multi(
                st_collectionextract(
                        ST_MakeValid(ST_Intersection(a.geom, b.geom))
                        , 3)
        ))::geometry(MultiPolygon,2154) AS geom
        FROM urbanisme.plui_parcelles AS a
        JOIN urbanisme.plui_parcelles AS b
                ON a.gid != b.gid
                --ON ST_Intersects(a.geom, b.geom)
                AND ST_Overlaps(a.geom, b.geom)
) AS voisin
ORDER BY geom
;

```

Récupérer la liste des identifiants de ces parcelles:

```sql
SELECT string_agg( parcelle_a::text, ',') FROM urbanisme.recouvrement_parcelle_voisines;
```

On peut utiliser le résultat de cette requête pour sélectionner les parcelles problématiques: on sélectionne le résultat dans le tableau du gestionnaire de base de données, et on copie (CTRL + C). On peut utiliser cette liste dans une **sélection par expression** dans QGIS, avec par exemple l'expression ```"gid" IN (1,2,3,4)```

Une fois les parcelles sélectionnées, on peut utiliser certains outils pour faciliter la correction:

* plugin **Vérifier les géométries** en cochant la case **Uniquement les entités sélectionnées**
* plugin **Accrochage de géométrie**
* etc.


### Accrocher les géométries sur d'autres géométries

Dans PostGIS, on peut utiliser la fonction **ST_Snap** dans une requête SQL pour déplacer les noeuds d'une géométrie et les coller sur ceux d'une autre.

Par exemple, coller les géométries choisies (via identifiants dans le WHERE) de la table de zonage sur les parcelles choisies (via identifiants dans le WHERE):

```sql
WITH a AS (
    SELECT DISTINCT z.id,
    ST_Force2d(
        ST_Multi(
            ST_Snap(
                z.geom,
                ST_Collect(p.geom),
                0.5
            )
        )
    ) AS geom
    FROM urbanisme.plui_parcelles AS p
    INNER JOIN urbanisme.plui_zonage AS z
    ON ST_Dwithin(z.geom, p.geom, 0.6)
    WHERE TRUE
    AND z.id IN (225, 1851)
    AND p.gid IN (11141, 11178)
    GROUP BY z.id
)
UPDATE urbanisme.plui_zonage pz
SET geom = a.geom
FROM a
WHERE pz.id = a.id
```

**Attention:** Cette fonction ne sait coller qu'**aux noeuds** de la table de référence, pas aux segments. Il serait néanmoins possible de créer automatiquement les noeuds situés sur la projection du noeud à déplacer sur la géométrie de référence.

Dans la pratique, il est très souvent fastidieux de corriger les erreurs de topologie d'une couche. Les outils automatiques ( Vérifier les géométries de QGIS ou outil v.clean de Grass) ne permettent pas toujours de bien voir ce qui a été modifié.

Au contraire, une modification manuelle est plus précise, mais prend beaucoup de temps.

Le Ministère du Développement Durable a mis en ligne un document intéressant sur les outils disponibles dans QGIS, OpenJump et PostgreSQL pour valider et corriger les géométries: http://www.geoinformations.developpement-durable.gouv.fr/verification-et-corrections-des-geometries-a3522.html
