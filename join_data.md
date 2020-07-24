---
Title: Jointure
Favicon: logo.svg
Sibling: yes
...

[TOC]

## Les jointures

Les jointures permettent de récupérer des données en relation les unes par rapport aux autres.

### Les jointures attributaires

La condition de jointure est faite sur des champs non géométriques. Par exemple une égalité (code, identifiant).

#### Exemple 1: zonages et communes

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


#### Exemple 2: observations et communes

* On crée une table de points qui contiendra des observations

```sql
-- création
CREATE TABLE z_formation.observation (
    id serial NOT NULL PRIMARY KEY,
    date date DEFAULT (now())::date NOT NULL,
    description text,
    geom public.geometry(Point,2154),
    code_insee character varying(5)
);
ALTER TABLE z_formation.observation ADD PRIMARY KEY (id);
CREATE INDEX sidx_observation_geom ON z_formation.observation USING gist (geom);

-- on y met des données
INSERT INTO z_formation.observation VALUES (1, '2020-07-08', 'un', '01010000206A080000D636D95AFB832141279BD2C8FEA65A41', '76618');
INSERT INTO z_formation.observation VALUES (2, '2020-07-08', 'deux', '01010000206A08000010248E173E37224156920AEA21525A41', '27213');
INSERT INTO z_formation.observation VALUES (3, '2020-07-08', 'trois', '01010000206A08000018BF3048EA112341183933F6CC885A41', NULL);

```

On fait une jointure attributaire entre les points des observations et les communes

```sql
SELECT
    -- tous les champs de la table observation
    o.*,
    -- le nom de la commune
    c.nom,
    -- l'aire entière en hectares
    ST_area(c.geom)::integer/10000 AS surface_commune
FROM z_formation.observation AS o
JOIN z_formation.commune AS c ON o.code_insee = c.code_insee
WHERE True
```

Résultat:

| id | date       | description | geom | code_insee | nom            | surface_commune |
|----|------------|-------------|------|------------|----------------|-----------------|
| 2  | 2020-07-08 | deux        | .... | 27213      | Vexin-sur-Epte | 11434           |
| 1  | 2020-07-08 | un          | .... | 76618      | Petit-Caux     | 9243            |

On ne récupère ici que 2 lignes alors qu'il y a bien 3 observations dans la table.

Pour récupérer les 3 lignes, on doit faire une jointure LEFT. On peut utiliser un `CASE WHEN` pour tester si la commune est trouvée sous chaque point

```sql
SELECT
    o.*, c.nom, ST_area(c.geom)::integer/10000 AS surface_commune,
    CASE
        WHEN c.code_insee IS NULL THEN 'pas de commune'
        ELSE 'ok'
    END AS test_commune
FROM z_formation.observation AS o
LEFT JOIN z_formation.commune AS c ON o.code_insee = c.code_insee
WHERE True
```

Résultat

| id | date       | description | geom | code_insee | nom            | surface_commune | test_commune   |
|----|------------|-------------|------|------------|----------------|-----------------|----------------|
| 2  | 2020-07-08 | deux        | .... | 27213      | Vexin-sur-Epte | 11434           | ok             |
| 1  | 2020-07-08 | un          | .... | 76618      | Petit-Caux     | 9243            | ok             |
| 3  | 2020-07-08 | trois       | .... | Null       | Null           | Null            | pas de commune |



### Les jointures spatiales

Le critère de jointure peut être une **condition spatiale**. On réalise souvent une jointure par **intersection** ou par **proximité**.

#### Joindre des points avec des polygones

Un exemple classique de récupération des données de la table commune (nom, etc.) depuis une table de points.

```sql
-- Pour chaque lieu-dit, on veut le nom de la commune
SELECT
l.id_lieu_dit_habite, l.nom,
c.nom AS nom_commune, c.code_insee,
l.geom
FROM "z_formation".lieu_dit_habite AS l
JOIN "z_formation".commune AS c
        ON st_intersects(c.geom, l.geom)
ORDER BY l.nom
```

| id_lieu_dit_habite | nom                   | nom_commune              | code_insee | geom | 
|--------------------|-----------------------|--------------------------|------------|------|
| 58                 | Abbaye du Valasse     | Gruchet-le-Valasse       | 76329      | .... |
| 1024               | Ablemont              | Bacqueville-en-Caux      | 76051      | .... |
| 1043               | Agranville            | Douvrend                 | 76220      | .... |
| 1377               | All des Artisans      | Mesnils-sur-Iton         | 27198      | .... |
| 1801               | Allée des Maronniers  | Heudebouville            | 27332      | .... |
| 1293               | Alliquerville         | Trouville                | 76715      | .... |
| 507                | Alventot              | Sainte-Hélène-Bondeville | 76587      | .... |
| 555                | Alvinbuc              | Veauville-lès-Baons      | 76729      | .... |
| 69                 | Ancien hôtel de ville | Rouen                    | 76540      | .... |


On peut facilement inverser la table principale pour afficher les lignes ordonnées par commune.

```sql
SELECT
c.nom, c.code_insee,
l.id_lieu_dit_habite, l.nom
FROM "z_formation".commune AS c
JOIN "z_formation".lieu_dit_habite AS l
        ON st_intersects(c.geom, l.geom)
ORDER BY c.nom
```

| nom      | code_insee | id_lieu_dit_habite | nom                |
|----------|------------|--------------------|--------------------|
| Aclou    | 27001      | 107                | Manoir de la Haule |
| Acquigny | 27003      | 106                | Manoir de Becdal   |
| Ailly    | 27005      | 596                | Quaizes            |
| Ailly    | 27005      | 595                | Ingremare          |
| Ailly    | 27005      | 594                | Gruchet            |
| Alizay   | 27008      | 667                | Le Solitaire       |
| Ambenay  | 27009      | 204                | Les Siaules        |
| Ambenay  | 27009      | 201                | Les Renardieres    |
| Ambenay  | 27009      | 202                | Le Culoron         |


On a plusieurs lignes par commune, autant que de lieux-dits pour cette commune. Par contre, comme ce n'est pas une jointure LEFT, on ne trouve que des résultats pour les communes qui ont des lieux-dits.

On pourrait aussi faire des statistiques, en regroupant par les champs de la table principale, ici les communes.

```sql
SELECT
c.nom, c.code_insee,
count(l.id_lieu_dit_habite) AS nb_lieu_dit,
c.geom
FROM "z_formation".commune AS c
JOIN "z_formation".lieu_dit_habite AS l
        ON st_intersects(c.geom, l.geom)
GROUP BY c.nom, c.code_insee, c.geom
ORDER BY nb_lieu_dit DESC
LIMIT 10
```

| nom                | code_insee | nb_lieu_dit | geom |
|--------------------|------------|-------------|------|
| Heudebouville      | 27332      | 61          | .... |
| Mesnils-sur-Iton   | 27198      | 52          | .... |
| Rouen              | 76540      | 20          | .... |
| Saint-Saëns        | 76648      | 19          | .... |
| Les Grandes-Ventes | 76321      | 19          | .... |
| Mesnil-en-Ouche    | 27049      | 18          | .... |
| Quincampoix        | 76517      | 18          | .... |



#### Joindre des lignes avec des polygones

Récupérer le code commune de chaque chemin, par **intersection entre le chemin et la commune**.

##### jointure spatiale simple entre les géométries brutes

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

Cela peut renvoyer plusieurs lignes par chemin, car chaque chemin peut passer par plusieurs communes.

##### jointure spatiale entre le centroide des chemins et la géométrie des communes

On peut utiliser le **centroide de chaque chemin** pour avoir un seul objet par chemin comme résultat.

```sql
-- création de l'index
CREATE INDEX ON z_formation.chemin USING gist (ST_Centroid(geom));
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

**NB:** Attention, dans ce cas, l'index spatial sur la géométrie des chemins n'est pas utilisé. C'est pour cela que nous avons créé un index spatial sur ST_Centroid(geom) pour la table des chemins.


A l'inverse, on peut vouloir faire des **statistiques pour chaque commune** via jointure spatiale. Par exemple le nombre de chemins et le total des longueurs par commune.

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

##### Utilisation d'une jointure LEFT pour garder les communes sans chemins

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

C'est **beaucoup plus long**, car la requête n'utilise pas d'abord l'intersection, donc l'index spatial des communes, mais fait un parcours de toutes les lignes des communes, puis un calcul d'intersection. Pour accélérer la requête, on doit créer l'index sur les centroïdes des chemins

```sql
CREATE INDEX ON z_formation.chemin USING GIST(ST_Centroid(geom))
```

puis la relancer. Dans cet exemple, on passe de 100 secondes à 1 seconde, grâce à ce nouvel index spatial.

##### Affiner le résultat en découpant les chemins

Dans la requête précédente, on calculait la longueur totale de chaque chemin, pas le **morceau exacte qui est sur chaque commune**. Pour cela, on va utiliser la fonction **ST_Intersection**. La requête va être plus couteuse, car il faut réaliser le découpage des lignes des chemins par les polygones des communes.

On va découper exactement les chemins par commune et récupérer les informations

```sql
CREATE TABLE z_formation.decoupe_chemin_par_commune AS
-- Découper les chemins par commune
SELECT
-- id unique
-- infos du chemin
l.id AS id_chemin,
-- infos de la commune
c.nom, c.code_insee,
ST_Multi(st_collectionextract(ST_Intersection(c.geom, l.geom), 2))::geometry(multilinestring, 2154) AS geom
FROM "z_formation".commune AS c
JOIN "z_formation".chemin AS l
        ON st_intersects(c.geom, l.geom)
;
CREATE INDEX ON z_formation.decoupe_chemin_par_commune USING GIST (geom);
```


**NB**: Attention à ne pas confondre **ST_Intersects** qui renvoit vrai ou faux, et **ST_Intersection** qui renvoit la géométrie issue du découpage d'une géométrie par une autre.



#### Joindre des polygones avec des polygones

On peut bien sûr réaliser des **jointures spatiales** entre 2 couches de **polygones**, et découper les polygones par intersection. Attention, les performances sont forcément moins bonnes qu'avec des points.

Trouver l'ensemble des zonages PLU pour les parcelles du Havre. 

On va récupérer **plusieurs résultats pour chaque parcelle** si plusieurs zonages chevauchent une parcelle.

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



Compter pour chaque parcelle le nombre de zonages en intersection: on veut **une seule ligne par parcelle**.

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

Découper les parcelles par les zonages, et pouvoir calculer les surfaces des zonages, et le pourcentage par rapport à la surface de chaque parcelle. On essaye le SQL suivant:

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

On a ici des soucis de **validité de géométrie**. Il nous faut donc corriger les géométries avant de poursuivre. Voir chapitre sur la validation des géométries.

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
        p.id_parcelle, p.id AS idpar, ST_Area(p.geom) AS aire_parcelle,
        z.id_zone_urba, z.libelle, z.libelong, z.typezone,
        -- découper les géométries
        (ST_Multi(st_intersection(z.geom, p.geom)))::geometry(MultiPolygon,2154) AS geom
        FROM z_formation.parcelle_havre AS p
        JOIN z_formation.zone_urba AS z ON st_intersects(z.geom, p.geom)
        WHERE True
) AS source;

-- Ajout de la clé primaire
ALTER TABLE z_formation.decoupe_zonage_parcelle ADD PRIMARY KEY (id);

-- Ajout de l'index spatial
CREATE INDEX ON z_formation.decoupe_zonage_parcelle USING GIST (geom);

```



#### Distances et tampons entre couches

Pour chaque objets d'une table, on souhaite récupéerer des informations sur les** objets proches d'une autre table**. Au lieu d'utiliser un tampon puis une intersection, on utilise la fonction **ST_DWithin**

On prend comme exemple la table des bornes à incendie créée précédememnt (remplie avec quelques données de test).

Trouver toutes les parcelles **à moins de 200m** d'une borne à incendie

```sql
SELECT
p.id_parcelle, p.geom,
b.id_borne, b.code,
ST_Distance(b.geom, p.geom) AS distance
FROM z_formation.parcelle_havre AS p
JOIN z_formation.borne_incendie AS b
        ON ST_DWithin(p.geom, b.geom, 200)
ORDER BY id_parcelle, id_borne
```

Attention, elle peut renvoyer **plusieurs fois la même parcelle** si 2 bornes sont assez proches. Pour ne récupérer que la borne la plus proche, on peut faire la requête suivante. La clause **DISTINCT ON** permet de dire quel champ doit être **unique** (ici id_parcelle).

On **ordonne** ensuite **par ce champ et par la distance** pour prendre seulement la ligne correspondant à la parcelle **la plus proche**

```sql
SELECT DISTINCT ON (p.id_parcelle)
p.id_parcelle, p.geom,
b.id_borne, b.code,
ST_Distance(b.geom, p.geom) AS distance
FROM z_formation.parcelle_havre AS p
JOIN z_formation.borne_incendie AS b
        ON ST_DWithin(p.geom, b.geom, 200)
ORDER BY id_parcelle, distance
```


Continuer vers [Fusionner des géométries](./merge_geometries.md)
