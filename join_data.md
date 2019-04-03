## Les jointures

Les jointures permettent de récupérer des données en relation les unes par rapport aux autres.

#### Les jointures attributaires

La condition de jointure est faite sur des champs non géométriques. Par exemple une égalité (code, identifiant).

Récupération des informations de la commune pour chaque zonage

```sql
-- Jointure attributaire: récupération du nom de la commune pour chacun des zonages
SELECT z.*, c.nom
FROM z_formation.zone_urba AS z
JOIN z_formation.commune AS c ON z.insee = c.code_insee
-- IMPORTANT: ne pas oublier le ON cad le critère de jointure,
-- sous peine de "produit cartésien" (calcul couteux de tous les possibles)
;
```

Il est souvent intéressant, pour des données volumineuses, de **créer un index sur le champ de jointure** (par exemple ici sur les champs insee et ccocom.

#### Les jointures spatiales

Le critère de jointure peut être une **condition spatiale**. On réalise souvent une jointure par **intersection** ou par **proximité**.

Récupérer le code commune de chaque chemin, par **intersection entre le chemin et la commune**.

```sql
-- Ici, on peut récupérer plusieurs fois le même chemin
-- s'il passe par plusieurs communes
SELECT
v.*,
c.nom, c.code_insee
FROM "z_formation".chemin AS v
JOIN "z_formation".commune AS c
        ON ST_Intersects(v.geom, c.geom)
ORDER BY id_chemin, nom
```

On peut utiliser le **centroide de chaque chemin** pour avoir un seul objet par chemin comme résultat.

```sql
-- Jointure spatiale
-- On ne veut qu'une seule ligne par chemin
-- Donc on fait l'intersection entre le centroïde des chemins (pour avoir un point) et les communes
SELECT
v.*,
c.nom, c.code_insee
FROM "z_formation".chemin AS v
JOIN "z_formation".commune AS c
        ON ST_Intersects(ST_Centroid(v.geom), c.geom)
```

*NB:* Attention, dans ce cas, l'index spatial sur la géométrie des chemins n'est pas utilisé. Il faudrait construire si besoin un index sur ST_Centroid(geom) pour la table des chemins.

A l'inverse, on peut vouloir faire des **statistiques pour chaque commune** via jointure spatiale. Par exemple le nombre de chemin et le total des longueurs par commune.

```sql
 -- A l'inverse, on veut récupérer des statistiques par commune
 -- On veut une ligne par commune, avec des données sur les voies
SELECT
c.id_commune, c.nom, c.code_insee,
count(v.id_chemin) AS nb_chemin,
sum(st_length(v.geom)) AS somme_longueur_chemins_entiers
FROM z_formation.commune AS c
JOIN z_formation.chemin AS v
        ON st_intersects(c.geom, st_centroid(v.geom))
GROUP BY c.id_commune, c.nom, c.code_insee
;
```

La requête précédente ne renvoit pas de lignes pour les communes qui n'ont pas de chemin dont le centroide est dans une commune. C'est une jointure de type **INNER JOIN**

Si on veut quand même récupérer ces communes, on fait une jointure **LEFT JOIN**: pour les lignes sans chemins, les champs liés à la table des chemins seront mis à NULL.


```sql
SELECT
c.id_commune, c.nom, c.code_insee,
count(v.id_chemin) AS nb_chemin,
sum(st_length(v.geom)) AS somme_longueur_chemins_entiers
FROM z_formation.commune AS c
LEFT JOIN z_formation.chemin AS v
        ON st_intersects(c.geom, st_centroid(v.geom))
GROUP BY c.id_commune, c.nom, c.code_insee
;
```

C'est *beaucoup plus long*, car la requête n'utilise pas d'abord l'intersection, donc l'index spatial des communes, mais fait un parcours de toutes les lignes des communes, puis un calcul d'intersection. Pour accélérer la requête, on doit créer l'index sur les centroïdes des chemins

```sql
CREATE INDEX ON z_formation.chemin USING GIST(ST_Centroid(geom))
```

puis la relancer. Dans cet exemple, on passe de 100 secondes à 1 seconde, grâce à ce nouvel index spatial.

Dans la requête précédente, on calculait la longueur totale de chaque chemin, pas le **morceau exacte qui est sur chaque commune**. Pour cela, on va utiliser la fonction **ST_Intersection**. La requête va être plus couteuse, car il faut réaliser le découpage des lignes des chemins par les polygones des communes.

```sql
SELECT
c.id_commune, c.nom, c.code_insee,
count(v.id_chemin) AS nb_chemin,
sum(st_length(
        ST_Intersection(v.geom,c.geom)
)) AS somme_longueur_chemins_decoupe_par_commune
FROM z_formation.commune AS c
LEFT JOIN z_formation.chemin AS v
        ON st_intersects(c.geom, st_centroid(v.geom))
GROUP BY c.id_commune, c.nom, c.code_insee
```

**NB**: Attention à ne pas confondre **ST_Intersects** qui renvoit vrai ou faux, et **ST_Intersection** qui renvoit la géométrie issue du découpage d'une géométrie par une autre.

On peut bien sûr réaliser des **jointures spatiales** entre 2 couches de **polygones**, et découper les polygones par intersection.

Trouver l'ensemble des zonages PLU pour les parcelles du Havre. On va récupérer plusieurs lignes pour chaque parcelle si elle a plusieurs zonages qui la chevauchent.

```sql
-- Jointure spatiale
SELECT
p.id_parcelle,
z.libelle, z.libelong, z.typezone
FROM z_formation.parcelle_havre AS p
JOIN z_formation.zone_urba AS z
    ON st_intersects(z.geom, p.geom)
WHERE True

```

Compter pour chaque parcelle le nombre de zonage en intersection: on veut une seule ligne par parcelle

```sql
SELECT
p.id_parcelle,
count(z.libelle) AS nombre_zonage
FROM z_formation.parcelle_havre AS p
JOIN z_formation.zone_urba AS z
    ON st_intersects(z.geom, p.geom)
WHERE True
GROUP BY p.id_parcelle
ORDER BY nombre_zonage DESC
```

Découper les parcelles par les zonages, et pouvoir calculer les surfaces des zonages, et le pourcentage par rapport à la surface de chaque parcelle. On essaye le SQL suivant


```sql
SELECT
p.id_parcelle,
z.libelle, z.libelong, z.typezone,
-- découper les géométries
st_intersection(z.geom, p.geom) AS geom
FROM z_formation.parcelle_havre AS p
JOIN z_formation.zone_urba AS z
    ON st_intersects(z.geom, p.geom)
WHERE True
ORDER BY p.id_parcelle
```

Il renvoit l'erreur

```
ERREUR:  Error performing intersection: TopologyException: Input geom 1 is invalid: Self-intersection at or near point 492016.26000489673 6938870.663846286 at 492016.26000489673 6938870.663846286
```

On a ici des soucis de validité de géométrie. Il nous faut donc corriger les géométries avant de poursuivre. Voir chapitre sur la validation des géométries.

Une fois les géométries validées, la requête fonctionne. On l'utilise dans une sous-requête pour créer une table et calculer les surfaces

```sql
-- suppression de la table
DROP TABLE IF EXISTS z_formation.decoupe_zonage_parcelle;
-- création de la table avec calcul de pourcentage de surface
CREATE TABLE z_formation.decoupe_zonage_parcelle AS
SELECT row_number() OVER() AS id,
source.*,
ST_Area(geom) AS aire,
100 * ST_Area(geom) / aire_parcelle AS pourcentage
FROM (
SELECT
        p.id_parcelle, p.idpar, ST_Area(p.geom) AS aire_parcelle,
        z.id_zone_urba, z.libelle, z.libelong, z.typezone,
        -- découper les géométries
        (ST_Multi(st_intersection(z.geom, p.geom)))::geometry(MultiPolygon,2154) AS geom
        FROM z_formation.parcelle AS p
        JOIN z_formation.zone_urba AS z ON st_intersects(z.geom, p.geom)
        WHERE True
) AS source;

-- Ajout de la clé primaire
ALTER TABLE z_formation.decoupe_zonage_parcelle ADD PRIMARY KEY (id);

-- Ajout de l'index spatial
CREATE INDEX ON z_formation.decoupe_zonage_parcelle USING GIST (geom);

```



### Distances et tampons entre couches

Pour chaque objets d'une table, on souhaite récupéerer des informations sur les** objets proches d'une autre table**. Au lieu d'utiliser un tampon puis une intersection, on utilise la fonction **ST_DWithin**

On prend comme exemple la table des bornes à incendie créée précédememnt (remplie avec quelques données de test).

Trouver toutes les parcelles **à moins de 200m** d'une borne à incendie

```sql
SELECT
p.id_parcelle, p.idpar, p.geom,
b.id_borne, b.code,
ST_Distance(b.geom, p.geom) AS distance
FROM z_formation.parcelle AS p
JOIN z_formation.borne_incendie AS b
        ON ST_DWithin(p.geom, b.geom, 200)
ORDER BY id_parcelle, id_borne
```

Attention, elle peut renvoyer **plusieurs fois la même parcelle** si 2 bornes sont assez proches. Pour ne récupérer que la borne la plus proche, on peut faire la requête suivante. La clause **DISTINCT ON** permet de dire quel champ doit être **unique** (ici id_parcelle).

On **ordonne** ensuite **par ce champ et par la distance** pour prendre seulement la ligne correspondant à la parcelle **la plus proche**

```sql
SELECT DISTINCT ON (p.id_parcelle)
p.id_parcelle, p.idpar, p.geom,
b.id_borne, b.code,
ST_Distance(b.geom, p.geom) AS distance
FROM z_formation.parcelle AS p
JOIN z_formation.borne_incendie AS b
        ON ST_DWithin(p.geom, b.geom, 200)
ORDER BY id_parcelle, distance
```


Continuer vers [Fusionner des géométries](./merge_geometries.md)
