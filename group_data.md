## Grouper des données et calculer des statistiques

### Valeurs distinctes d'un champ

On souaite récupérer **toutes les valeurs possibles** d'un champ

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

Cela peut être par exemple utile pour **construire une table de nomenclature** à partir de données existantes. Dans l'exemple ci-dessous, on souhaite stocker la nomenclature de toutes les données dans une seule table.

On crée la table si besoin.

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

On ajoute ensuite les données. La clause **WITH** permet de réaliser une sous-requête, et de l'utiliser ensuite comme une table. La clause **INSERT INTO** permet d'ajouter les données. On ne lui passe pas le champ id, car c'est un **serial**, c'est-à-dire un entier **auto-incrémenté**.

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


### Regrouper des données en spécifiant les champs de regroupement

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
min(ST_Area(geom)/1000)::int AS min_aire_ha,
max(ST_Area(geom)/1000)::int AS max_aire_ha,
avg(ST_Area(geom)/1000)::int AS moy_aire_ha,
sum(ST_Area(geom)/1000)::int AS total_aire_ha
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

Les caculs sur des ensembles groupés peuvent aussi être réalisé **sur les géométries.**. Le plus utilisé est **ST_Collect** qui regroupe les géométries dans une multi-géométrie.

Par exemple, on peut souhaiter trouver l'**enveloppe convexe** autour de points (élastique tendu autour d'un groupe de points). Ici, nous regroupons les lieux-dits par nature. Dans ce cas, il faut faire une sous-requête pour filtrer seulement les résultats de type polygone (car s'il y a seulement 1 ou 2 objets par nature, alors on ne peut créer de polygone)


```sql
SELECT *
FROM (
        SELECT
        nature,
        -- ST_Convexhull renvoit l'enveloppe convexe
        ST_Convexhull(ST_Collect(geom)) AS geom
        FROM z_formation.lieu_dit_habite
        GROUP BY nature
) AS source
-- GeometryType renvoit le type de géométrie
WHERE Geometrytype(geom) = 'POLYGON'
```

Attention, on doit donner un alias à la sous-requête (ici source)


