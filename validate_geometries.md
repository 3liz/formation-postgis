## Correction des géométries

Avec PostgreSQL on peut **tester la validité des géométries** d'une table, comprendre la raison et localiser les soucis de validité:


```sql
SELECT
id_parcelle,
-- vérifier si la géom est valide
ST_IsValid(geom) AS validite_geom,
-- connaitre la raison d'invalidité
st_isvalidreason(geom) AS validite_raison,
-- sortir un point qui localise le souci de validité
location(st_isvaliddetail(geom)) AS point_invalide
FROM urbanisme.parcelle
WHERE ST_IsValid(geom) IS FALSE
```

PostGIS fournir l'outil **ST_MakeValid** pour corriger automatiquement les géométries invalides. On peut l'utiliser pour les lignes et polygones.

Attention, pour les polygones, cela peut conduire à des géométries de type différent (par exemple une polygone à 2 noeuds devient une ligne). On utilise donc aussi la fonction **ST_CollectionExtract** pour ne récupérer que les polygones.

```sql
-- Corriger les géométries
UPDATE urbanisme.parcelle
SET geom = ST_Multi(ST_CollectionExtract(ST_MakeValid(geom), 3))
WHERE NOT ST_isvalid(geom)

-- Tester
SELECT *
FROM urbanisme.parcelle
WHERE NOT ST_isvalid(geom)
```

Continuer vers [Vérifier la topologie](./check_topology.md)
