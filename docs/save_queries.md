# Enregistrer une requête

## Les vues

Une vue est l'enregistrement d'une requête, appelée **définition de la vue**, qui est stocké dans la base, et peut être **utilisée comme une table**.

Créer une vue via `CREATE VIEW`

```sql
-- On supprime d'abord la vue si elle existe
DROP VIEW IF EXISTS z_formation.v_voies;
-- On crée la vue en récupérant les routes de plus de 5 km
CREATE VIEW z_formation.v_voies AS
SELECT id_route, id AS code, ST_Length(geom) AS longueur, geom
FROM z_formation.route
WHERE ST_Length(geom) > 5000
```

Utiliser cette vue dans une autre requête

* pour filtrer les données

```sql
-- Ou filtrer les données
SELECT * FROM z_formation.v_voies
WHERE longueur > 10000
```

## Enregistrer une requête comme une table

C'est la même chose que pour enregistrer une vue, sauf qu'on crée une table: les données sont donc stockées en base, et n'évoluent plus en fonction des données source. Cela permet d'accéder rapidement aux données, car la requête sous-jacente n'est plus exécutée une fois la table créée.

### Exemple 1 - créer la table des voies rassemblant les routes et les chemins

```sql
DROP TABLE IF EXISTS z_formation.t_voies;
CREATE TABLE z_formation.t_voies AS
SELECT
-- on récupère tous les champs
source.*,
-- on calcule la longueur après rassemblement des données
ST_Length(geom) AS longueur
FROM (
        (SELECT id, geom
        FROM z_formation.chemin
        LIMIT 100)
        UNION ALL
        (SELECT id, geom
        FROM z_formation.route
        LIMIT 100)
) AS source
ORDER BY longueur
;
```

Comme c'est une table, il est intéressant d'ajouter un index spatial.

```sql
CREATE INDEX ON z_formation.t_voies USING GIST (geom);
```

On peut aussi ajouter une clé primaire

```sql
ALTER TABLE z_formation.t_voies ADD COLUMN gid serial;
ALTER TABLE z_formation.t_voies ADD PRIMARY KEY (gid);
```

**Attention** Les données de la table n'évoluent plus en fonction des données des tables source. Il faut donc supprimer la table puis la recréer si besoin. Pour répondre à ce besoin, il existe les **vues matérialisées**.




### Exemple 2 - créer une table de nomenclature à partir des valeurs distinctes d'un champ.

On crée la table si besoin. On ajoutera ensuite les données via `INSERT`

```sql
-- Suppression de la table
DROP TABLE IF EXISTS z_formation.nomenclature;
-- Création de la table
CREATE TABLE z_formation.nomenclature (
    id serial primary key,
    code text,
    libelle text,
    ordre smallint
);

```

On ajoute ensuite les données. La clause `WITH` permet de réaliser une sous-requête, et de l'utiliser ensuite comme une table. La clause `INSERT INTO` permet d'ajouter les données. On ne lui passe pas le champ id, car c'est un **serial**, c'est-à-dire un entier **auto-incrémenté**.

```sql
-- Ajout des données à partir d'une table via commande INSERT
INSERT INTO z_formation.nomenclature
(code, libelle, ordre)
-- Clause WITH pour récupérer les valeurs distinctes comme une table virtuelle
WITH source AS (
    SELECT DISTINCT
    nature AS libelle
    FROM z_formation.lieu_dit_habite
    WHERE nature IS NOT NULL
    ORDER BY nature
)
-- Sélection des données dans cette table virtuelle "source"
SELECT
-- on crée un code à partir de l'ordre d'arrive.
-- row_number() OVER() permet de récupérer l'identifiant de la ligne dans l'ordre d'arrivée
-- (un_champ)::text permet de convertir un champ ou un calcul en texte
-- lpad permet de compléter le chiffre avec des zéro. 1 devient 01
lpad( (row_number() OVER())::text, 2, '0' ) AS code,
libelle,
row_number() OVER() AS ordre
FROM source
;
```

Le résultat est le suivant:

| code | libelle         | ordre |
|------|-----------------|-------|
| 01   | Château         | 1     |
| 02   | Lieu-dit habité | 2     |
| 03   | Moulin          | 3     |
| 04   | Quartier        | 4     |
| 05   | Refuge          | 5     |
| 06   | Ruines          | 6     |


### Exemple 3 - créer une table avec l'extraction des parcelles sur une commune

On utilise le champ `commune` pour filtrer. On n'oublie pas de créer l'index spatial, qui sera utilisé pour améliorer les performances lors des jointures spatiales.

```sql
-- supprimer la table si elle existe déjà
DROP TABLE IF EXISTS z_formation.parcelle_havre ;

-- Créer la table via filtre sur le champ commune
CREATE TABLE z_formation.parcelle_havre AS
SELECT p.*
FROM z_formation.parcelle AS p
WHERE p.commune = '76351';

-- Ajouter la clé primaire
ALTER TABLE z_formation.parcelle_havre ADD PRIMARY KEY (id_parcelle);

-- Ajouter l'index spatial
CREATE INDEX ON z_formation.parcelle_havre USING GIST (geom);
```

## Enregistrer une requête comme une vue matérialisée


```sql
-- On supprime d'abord la vue matérialisée si elle existe
DROP MATERIALIZED VIEW IF EXISTS z_formation.vm_voies;
-- On crée la vue en récupérant les routes de plus de 5 km
CREATE MATERIALIZED VIEW z_formation.vm_voies AS
SELECT id_route, id AS code, ST_Length(geom) AS longueur, geom
FROM z_formation.route
WHERE ST_Length(geom) > 6000

-- Ajout des indexes sur le champ id_route et de géométrie
CREATE INDEX ON z_formation.vm_voies (id_route);
CREATE INDEX ON z_formation.vm_voies USING GIST (geom);

-- On rafraîchit la vue matérialisée quand on en a besoin
-- par exemple quand les données source ont été modifiées
REFRESH MATERIALIZED VIEW z_formation.vm_voies;

```

Continuer vers [Réaliser des jointures attributaires et spatiales; JOIN](./join_data.md)
