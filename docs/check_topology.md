# Vérifier la topologie

## Déplacer les noeuds sur une grille

Avant de vérifier la topologie, il faut au préalable avoir des géométries valides (cf. chapitre précédent).

Certaines micro-erreurs de topologie peuvent peuvent être corrigées en réalisant une simplification des données à l'aide d'une grille, par exemple pour corriger des soucis d'arrondis. Pour cela, PostGIS a une fonction **ST_SnapToGrid**.

On peut utiliser conjointement **ST_Simplify** et **ST_SnapToGrid** pour effectuer une première correction sur les données. Attention, ces fonctions modifient la donnée. A vous de choisir la bonne tolérance, par exemple 5 cm, qui dépend de votre donnée et de votre cas d'utilisation.

Tester la simplification en lançant la requête suivante, et en chargeant le résultat comme une nouvelle couche dans QGIS

```sql
SELECT
    ST_Multi(
        ST_CollectionExtract(
            ST_MakeValid(
                ST_SnapToGrid(
                    st_simplify(geom,0),
                    0.05 -- 5 cm
                )
            ),
            3
        )
    )::geometry(multipolygon, 2154)
FROM z_formation.parcelle_havre
;
```

Une fois le résultat visuellement testé dans QGIS, par comparaison avec la table source, on peut choisir de *modifier la géométrie de la table* avec la version simplifiée des données:

```sql
-- Parcelles
UPDATE z_formation.parcelle_havre
SET geom =
ST_Multi(
    ST_CollectionExtract(
        ST_MakeValid(
            ST_SnapToGrid(
                st_simplify(geom,0),
                0.05 -- 5 cm
            )
        ),
        3
    )
)
;
;
```

**Attention:** Si vous avez d'autres tables avec des objets en relation spatiale avec cette table, il faut aussi effectuer le même traitement pour que les géométries de toutes les couches se calent sur la même grille. Par exemple la table des zonages.

```sql
UPDATE z_formation.zone_urba
SET geom =
ST_Multi(
    ST_CollectionExtract(
        ST_MakeValid(
            ST_SnapToGrid(
                st_simplify(geom,0),
                0.05 -- 5 cm
            )
        ),
        3
    )
)
;
```


## Repérer certaines erreurs de topologies

PostGIS possède de nombreuses fonctions de **relations spatiales** qui permettent de trouver les objets qui se chevauchent, qui se touchent, etc. Ces fonctions peuvent être utilisées pour comparer les objets d'une même table, ou de deux tables différentes. Voir: https://postgis.net/docs/reference.html#Spatial_Relationships_Measurements

Par exemple, trouver les parcelles voisines qui se recouvrent: on utilise la fonction **ST_Overlaps**. On peut créer une couche listant les recouvrements:


```sql
DROP TABLE IF EXISTS z_formation.recouvrement_parcelle_voisines;
CREATE TABLE z_formation.recouvrement_parcelle_voisines AS
SELECT DISTINCT ON (geom)
parcelle_a, parcelle_b, aire_a, aire_b, ST_Area(geom) AS aire, geom
FROM (
        SELECT
        a.id_parcelle AS parcelle_a, ST_Area(a.geom) AS aire_a,
        b.id_parcelle AS parcelle_b, ST_Area(b.geom) AS aire_b,
        (ST_Multi(
                st_collectionextract(
                        ST_MakeValid(ST_Intersection(a.geom, b.geom))
                        , 3)
        ))::geometry(MultiPolygon,2154) AS geom
        FROM z_formation.parcelle_havre AS a
        JOIN z_formation.parcelle_havre AS b
                ON a.id_parcelle != b.id_parcelle
                --ON ST_Intersects(a.geom, b.geom)
                AND ST_Overlaps(a.geom, b.geom)
) AS voisin
ORDER BY geom
;

CREATE INDEX ON z_formation.recouvrement_parcelle_voisines USING GIST (geom);

```

On peut alors ouvrir cette couche dans QGIS pour zoomer sur chaque objet de recouvrement.

Récupérer la liste des identifiants de ces parcelles:

```sql
SELECT string_agg( parcelle_a::text, ',') FROM z_formation.recouvrement_parcelle_voisines;
```

On peut utiliser le résultat de cette requête pour sélectionner les parcelles problématiques: on sélectionne le résultat dans le tableau du gestionnaire de base de données, et on copie (CTRL + C). On peut alors utiliser cette liste dans une **sélection par expression** dans QGIS, avec par exemple l'expression

```sql
"id_parcelle" IN (
729091,742330,742783,742513,742514,743114,742992,742578,742991,742544,743009,744282,744378,744378,744281,744199,743646,746445,743680,744280,
743653,743812,743208,743812,743813,744199,694298,694163,721712,707463,744412,707907,707069,721715,721715,696325,696372,746305,722156,722555,
722195,714500,715969,722146,722287,723526,720296,720296,722296,723576,723572,723572,723571,724056,723570,723568,740376,722186,724055,714706,
723413,723988,721808,721808,723413,724064,723854,723854,724063,723518,720736,720653,741079,741227,740932,740932,740891,721259,741304,741304,
741501,741226,741812)
```

Une fois les parcelles sélectionnées, on peut utiliser certains outils de QGIS pour faciliter la correction:

* plugin **Vérifier les géométries** en cochant la case **Uniquement les entités sélectionnées**
* plugin **Accrochage de géométrie**
* plugin **Go 2 next feature** pour facilement zoomer d'objets en objets


## Accrocher les géométries sur d'autres géométries

Dans PostGIS, on peut utiliser la fonction **ST_Snap** dans une requête SQL pour déplacer les noeuds d'une géométrie et les coller sur ceux d'une autre.

Par exemple, coller les géométries choisies (via identifiants dans le WHERE) de la table de zonage sur les parcelles choisies (via identifiants dans le WHERE):

```sql
WITH a AS (
    SELECT DISTINCT z.id_zone_urba,
    st_force2d(
        ST_Multi(
            ST_Snap(
                ST_Simplify(z.geom, 1),
                ST_Collect(p.geom),
                0.5
            )
        )
    ) AS geom
    FROM z_formation.parcelle_havre AS p
    INNER JOIN z_formation.zone_urba AS z
    ON st_dwithin(z.geom, p.geom, 0.5)
    WHERE TRUE
    AND z.id_zone_urba IN (113,29)
    AND p.id_parcelle IN (711337,711339,711240,711343)
    GROUP BY z.id_zone_urba
)
UPDATE z_formation.zone_urba pz
SET geom = a.geom
FROM a
WHERE pz.id_zone_urba = a.id_zone_urba
```

**Attention:** Cette fonction ne sait coller qu'**aux noeuds** de la table de référence, pas aux segments. Il serait néanmoins possible de créer automatiquement les noeuds situés sur la projection du noeud à déplacer sur la géométrie de référence.

Dans la pratique, il est très souvent fastidieux de corriger les erreurs de topologie d'une couche. Les outils automatiques ( Vérifier les géométries de QGIS ou outil v.clean de Grass) ne permettent pas toujours de bien voir ce qui a été modifié.

Au contraire, une modification manuelle est plus précise, mais prend beaucoup de temps.

Le Ministère du Développement Durable a mis en ligne un document intéressant sur les outils disponibles dans QGIS, OpenJump et PostgreSQL pour valider et corriger les géométries: http://www.geoinformations.developpement-durable.gouv.fr/verification-et-corrections-des-geometries-a3522.html
