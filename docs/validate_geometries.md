# Correction des géométries

Avec PostgreSQL on peut **tester la validité des géométries** d'une table, comprendre la raison et localiser les soucis de validité:


```sql
SELECT
id_parcelle,
-- vérifier si la géom est valide
ST_IsValid(geom) AS validite_geom,
-- connaitre la raison d'invalidité
st_isvalidreason(geom) AS validite_raison,
-- sortir un point qui localise le souci de validité
ST_SetSRID(location(st_isvaliddetail(geom)), 2154) AS geom
FROM z_formation.parcelle_havre
WHERE ST_IsValid(geom) IS FALSE
```

qui renvoit 2 erreurs de polygones croisés.

| id_parcelle | validite_geom | validite_raison                                      | point_invalide                             |
|-------------|---------------|------------------------------------------------------|--------------------------------------------|
| 707847      | False         | Self-intersection[492016.260004897 6938870.66384629] | 010100000041B93E0AC1071E4122757CAA3D785A41 |
| 742330      | False         | Self-intersection[489317.48266784 6939616.89391708]  | 0101000000677A40EE95DD1D41FBEF3539F8785A41 |

et qu'on peut ouvrir comme une nouvelle couche, avec le champ géométrie *point_invalide*, ce qui permet de visualiser dans QGIS les positions des erreurs.

PostGIS fournir l'outil **ST_MakeValid** pour corriger automatiquement les géométries invalides. On peut l'utiliser pour les lignes et polygones.

Attention, pour les polygones, cela peut conduire à des géométries de type différent (par exemple une polygone à 2 noeuds devient une ligne). On utilise donc aussi la fonction **ST_CollectionExtract** pour ne récupérer que les polygones.

```sql
-- Corriger les géométries
UPDATE z_formation.parcelle_havre
SET geom = ST_Multi(ST_CollectionExtract(ST_MakeValid(geom), 3))
WHERE NOT ST_isvalid(geom)

-- Tester
SELECT count(*)
FROM z_formation.parcelle_havre
WHERE NOT ST_isvalid(geom)
```

Il faut aussi supprimer l'ensemble des lignes dans la table qui ne correspondent pas au type de la couche importée. Par exemple, pour les polygones, supprimer les objets dont le nombre de noeuds est inférieur à 3.

* On les trouve:

```sql
SELECT *
FROM z_formation.parcelle_havre
WHERE ST_NPoints(geom) < 3
```

* On les supprime:

```sql
DELETE
FROM z_formation.parcelle_havre
WHERE ST_NPoints(geom) < 3
```


Continuer vers [Vérifier la topologie](./check_topology.md)
