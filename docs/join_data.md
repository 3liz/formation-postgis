# Les jointures

Les jointures permettent de récupérer des données en relation les unes par rapport aux autres.

## Les jointures attributaires

La condition de jointure est faite sur des champs non géométriques. Par exemple une égalité (code, identifiant).

### Exemple 1: zonages et communes

Récupération des informations de la commune pour chaque zonage

```sql
-- Jointure attributaire: récupération du nom de la commune pour chacun des zonages
SELECT z.*, c.nom
FROM z_formation.zone_urba AS z
JOIN z_formation.commune AS c ON z.insee = c.code_insee
-- IMPORTANT: ne pas oublier le ON cad le critère de jointure,
-- sous peine de "produit cartésien" (calcul coûteux de tous les possibles)
;
```

Il est souvent intéressant, pour des données volumineuses, de **créer un index sur le champ de jointure** (par exemple ici sur les champs `insee` et `ccocom`.


### Exemple 2: observations et communes

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

Pour récupérer les 3 lignes, on doit faire une jointure `LEFT`. On peut utiliser un `CASE WHEN` pour tester si la commune est trouvée sous chaque point

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

## Les jointures spatiales

Le critère de jointure peut être une **condition spatiale**. On réalise souvent une jointure par **intersection** ou par **proximité**.

### Joindre des points avec des polygones

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


On a plusieurs lignes par commune, autant que de lieux-dits pour cette commune. Par contre, comme ce n'est pas une jointure `LEFT`, on ne trouve que des résultats pour les communes qui ont des lieux-dits.

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



### Joindre des lignes avec des polygones

Récupérer le code commune de chaque chemin, par **intersection entre le chemin et la commune**.

#### Jointure spatiale simple entre les géométries brutes

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

#### Jointure spatiale entre le centroïde des chemins et la géométrie des communes

On peut utiliser le **centroïde de chaque chemin** pour avoir un seul objet par chemin comme résultat.

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

**NB:** Attention, dans ce cas, l'index spatial sur la géométrie des chemins n'est pas utilisé. C'est pour cela que nous avons créé un index spatial sur `ST_Centroid(geom)` pour la table des chemins.


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

#### Utilisation d'une jointure LEFT pour garder les communes sans chemins

La requête précédente ne renvoie pas de lignes pour les communes qui n'ont pas de chemin dont le centroïde est dans une commune. C'est une jointure de type `INNER JOIN`

Si on veut quand même récupérer ces communes, on fait une jointure `LEFT JOIN`: pour les lignes sans chemins, les champs liés à la table des chemins seront mis à `NULL`.


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

#### Affiner le résultat en découpant les chemins

Dans la requête précédente, on calculait la longueur totale de chaque chemin, pas le **morceau exacte qui est sur chaque commune**. Pour cela, on va utiliser la fonction `ST_Intersection`. La requête va être plus coûteuse, car il faut réaliser le découpage des lignes des chemins par les polygones des communes.

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


**NB**: Attention à ne pas confondre `ST_Intersects` qui renvoie vrai ou faux, et `ST_Intersection` qui renvoie la géométrie issue du découpage d'une géométrie par une autre.

### Joindre des polygones avec des polygones

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

### Faire un rapport des surfaces intersectées de zonages sur une table principale

Par exemple, pour chacune des communes, on souhaite calculer la somme des surfaces intersectée par chaque type de zone (parcs, znieff, etc.).

Afin d'avoir à disposition des données de test pour cet exemple de rapport, nous allons créer 2 tables `z_formation.parc_national` et `z_formation.znieff`, et y insérer des fausses données:


```sql
-- Table des parcs nationaux
CREATE TABLE IF NOT EXISTS z_formation.parc_national (
    id serial primary key,
    nom text,
    geom geometry(multipolygon, 2154)
);
CREATE INDEX ON z_formation.parc_national USING GIST (geom);

-- Table des znieff
CREATE TABLE IF NOT EXISTS z_formation.znieff(
    id serial primary key,
    nom_znieff text,
    geom geometry(multipolygon, 2154)
);
CREATE INDEX ON z_formation.znieff USING GIST (geom);
```

On insère des polygones dans ces deux tables:

```sql
-- données de test
-- parcs
INSERT INTO z_formation.parc_national VALUES (1, 'un', '01060000206A0800000100000001030000000100000008000000C3F7DE73553D20411B3DC1FB0C625A410531F757E93D2041BAECB21FA85E5A41F35B09978081204195F05B9787595A41D61E4865A1A7204147BC8A3AC0605A41ED76A806317F2041A79F7E4876605A41B80752433C832041037846623A655A41E10ED595BA6120413CC1D1C18C685A41C3F7DE73553D20411B3DC1FB0C625A41');
INSERT INTO z_formation.parc_national VALUES (2, 'deux', '01060000206A080000010000000103000000010000000900000024D68B4AE0412141AAAAAA3C685B5A4130642ACBD01421413A85AE4B72585A41CA08F0240E382141746C4BD107535A41FA30F7A78A4A2141524A29E544555A414796BF5CE63621414DD2E222A4565A416B92160F9B5D2141302807F981575A4130DC700B2E782141DC0ED50B6B5C5A4106FBB8C8294F214150AC17BF015E5A4124D68B4AE0412141AAAAAA3C685B5A41');
INSERT INTO z_formation.parc_national VALUES (3, 'trois', '01060000206A0800000100000001030000000100000006000000918DCFE7E0861F4137AB79AF14515A411AE56040588A1F41642A43EEC74F5A41DF2EBB3CEBA41F418C31C66ADA4F5A4168864C9562A81F416E87EA40B8505A415CBC8A74C3A31F410FA4F63202515A41918DCFE7E0861F4137AB79AF14515A41');
INSERT INTO z_formation.parc_national VALUES (4, 'quatre', '01060000206A080000010000000103000000010000000500000004474FE81DBA2041269A684EFD625A41AB17C51223C9204120B507BEAD605A4116329539BBF22041A3273886D5615A416F611F0FB6E32041FA1A9F0F4A645A4104474FE81DBA2041269A684EFD625A41');
INSERT INTO z_formation.parc_national VALUES (5, 'cinq', '01060000206A0800000100000001030000000100000005000000F2E3C256231E2041E0ACE631AE535A41F7C823E772202041E89C73B6EF505A41B048BCC266362041DAC785A15E515A419E999911782F204180C9F223F8535A41F2E3C256231E2041E0ACE631AE535A41');
SELECT pg_catalog.setval('z_formation.parc_national_id_seq', 5, true);

-- znieff
INSERT INTO z_formation.znieff VALUES (1, 'uno', '01060000206A08000001000000010300000001000000050000004039188C39D12041770A5DF74A4A5A413A54B7FBE9CE20410C5DA7C8F5455A41811042C0A4EA204130ECE38267475A416F611F0FB6E320417125FC66FB475A414039188C39D12041770A5DF74A4A5A41');
INSERT INTO z_formation.znieff VALUES (2, 'dos', '01060000206A080000010000000103000000010000000500000076BEC6DF62492141513FFDF0525A5A417CA32770B24B21411EDBD22150595A419437ABB1F05421410F06E50CBF595A419437ABB1F0542141B022F1FE085A5A4176BEC6DF62492141513FFDF0525A5A41');
INSERT INTO z_formation.znieff VALUES (3, 'tres', '01060000206A0800000100000001030000000100000005000000A6E6CD62DF5B2141B607528F585C5A41ACCB2EF32E5E2141C5DC3FA4E95B5A414CB7438DE46A2141C5DC3FA4E95B5A41B895F013CE62214189888850A55D5A41A6E6CD62DF5B2141B607528F585C5A41');
INSERT INTO z_formation.znieff VALUES (4, 'quatro', '01060000206A0800000100000001030000000100000005000000CE857DF445102041985D7665365D5A41DA4F3F15E5142041339521C7305B5A41C2F7DE73553D2041927815D5E65A5A410393E50712252041B607528F585C5A41CE857DF445102041985D7665365D5A41');
INSERT INTO z_formation.znieff VALUES (5, 'cinco', '01060000206A080000010000000103000000010000000500000045A632DC2B702041FD25CB033C5F5A41CEFDC334A373204115EB459D0E5C5A41F25B099780812041397A8257805D5A415755558D1A7720419E42D7F5855F5A4145A632DC2B702041FD25CB033C5F5A41');
SELECT pg_catalog.setval('z_formation.znieff_id_seq', 5, true);
```

Pour chaque commune, on souhaite calculer la somme des surfaces intersectées par chaque type de zone. On doit donc utiliser toutes les tables de zonage (ici seulement 2 tables, mais c'est possible d'en ajouter)

Résultat attendu:

| id_commune | code_insee | nom               | surface_commune_ha | somme_surface_parcs | somme_surface_znieff |
|------------|------------|-------------------|--------------------|---------------------|----------------------|
| 1139       | 27042      | Barville          | 275.138028733401   | 87.2237204013011    | None                 |
| 410        | 27057      | Bernienville      | 779.74546553394    | None                | 5.26504189468878     |
| 1193       | 27061      | Berthouville      | 757.19696570046    | 19.9975421896336    | None                 |
| 495        | 27074      | Boisney           | 576.995877227961   | 0.107059260396721   | None                 |
| 432        | 27077      | Boissey-le-Châtel | 438.373848703835   | 434.510197417769    | 83.9289621127432     |


* Méthode avec des sous-requêtes

```sql
SELECT
    c.id_commune, c.code_insee, c.nom,
    ST_Area(c.geom) / 10000 AS surface_commune_ha,
    (SELECT sum(ST_Area(ST_Intersection(c.geom, p.geom)) / 10000 ) FROM z_formation.parc_national AS p WHERE ST_Intersects(p.geom, c.geom) ) AS surface_parc_national,
    (SELECT sum(ST_Area(ST_Intersection(c.geom, p.geom)) / 10000 ) FROM z_formation.znieff AS p WHERE ST_Intersects(p.geom, c.geom) ) AS surface_znieff
FROM z_formation.commune AS c
ORDER BY c.nom
```

* Méthode avec des **jointures** `LEFT`

```sql
SELECT
    -- champs choisis dans la table commune
    c.id_commune, c.code_insee, c.nom,
    -- surface en ha
    ST_Area(c.geom) / 10000 AS surface_commune_ha,
    -- somme des découpages des parcs par commune
    sum(ST_Area(ST_Intersection(c.geom, p.geom)) / 10000 ) AS somme_surface_parcs,
    -- somme des découpages des znieff par commune
    sum(ST_Area(ST_Intersection(c.geom, z.geom)) / 10000 ) AS somme_surface_znieff

FROM z_formation.commune AS c
-- jointure spatiale sur les parcs
LEFT JOIN z_formation.parc_national AS p
    ON ST_Intersects(c.geom, p.geom)
-- jointure spatiale sur les znieff
LEFT JOIN z_formation.znieff AS z
    ON ST_Intersects(c.geom, z.geom)

-- clause WHERE optionelle
-- WHERE p.id IS NOT NULL OR z.id IS NOT NULL

-- on regroupe sur les champs des communes
GROUP BY c.id_commune, c.code_insee, c.nom

-- on ordonne par nom
ORDER BY c.nom
```

**Avantages**:

* on peut intégrer facilement dans la clause `WHERE` des conditions sur les champs des tables jointes. Par exemple ne récupérer que les lignes qui sont concernées par un parc ou une znieff, via `WHERE p.id IS NOT NULL OR z.id IS NOT NULL` (commenté ci-dessus pour le désactiver)
* On peut sortir plusieurs aggrégats pour les tables jointes. Par exemple un décompte des parcs, un décompte des znieff

ATTENTION:

* on peut avoir des doublons qui vont créer des erreurs. Voir cet exemple: http://sqlfiddle.com/#!17/73485c/2/0
* cette méthode peut poser des soucis de performance




**ATTENTION**:

* il faut absolument avoir un index spatial sur le champ `geom` de toutes les tables
* le calcul de découpage des polygones des communes par ceux des zonages peut être très long (et l'index spatial ne sert à rien ici)


### Distances et tampons entre couches

Pour chaque objets d'une table, on souhaite récupérer des informations sur les** objets proches d'une autre table**. Au lieu d'utiliser un tampon puis une intersection, on utilise la fonction `ST_DWithin`

On prend comme exemple la table des bornes à incendie créée précédemment (remplie avec quelques données de test).

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

Attention, elle peut renvoyer **plusieurs fois la même parcelle** si 2 bornes sont assez proches. Pour ne récupérer que la borne la plus proche, on peut faire la requête suivante. La clause `DISTINCT ON` permet de dire quel champ doit être **unique** (ici id_parcelle).

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

Pour information, on peut vérifier en créant les tampons

```sql
-- Tampons non dissous
SELECT id_borne, ST_Buffer(geom, 200) AS geom
FROM z_formation.borne_incendie

-- Tampons dissous
SELECT ST_Union(ST_Buffer(geom, 200)) AS geom
FROM z_formation.borne_incendie
```

Un [article intéressant de Paul Ramsey](http://blog.cleverelephant.ca/2021/12/knn-syntax.html) sur le calcul de distance via l'opérateur `<->` pour trouver le plus proche voisin d'un objet.



Continuer vers [Fusionner des géométries](./merge_geometries.md)
