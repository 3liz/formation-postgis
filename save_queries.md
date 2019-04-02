## Enregistrer une requête

### Les vues

Une vue est l'enregistrement d'une requête, appelée **définition de la vue**, qui est stocké dans la base, et peut être **utilisée comme une table**.

Créer une vue via **CREATE VIEW**

```sql
-- Créer une vue pour stocker la requête et pouvoir l'utiliser comme une table
-- (mais avec des données dynamiques)
DROP VIEW IF EXISTS "z_formation".v_voies;
CREATE VIEW "z_formation".v_voies AS
SELECT
-- on récupère tous les champs
source.*,
-- on calcule la longueur après rassemblement des données
st_length(geom) AS longueur
FROM (
        SELECT id, geom
        FROM z_formation.chemin
        UNION ALL
        SELECT id, geom
        FROM z_formation.route
) AS source
ORDER BY longueur
;
```

Utiliser cette vue dans une autre requête

* pour faire des statistiques

```sql
-- On peut ensuite utiliser cette vue pour faire des stats
SELECT source, count(*) AS nb, sum(longueur) AS longueur_totale
FROM "z_formation".v_voies
GROUP BY source
```

* pour filtrer les données

```sql
-- Ou filtrer les données
SELECT * FROM z_formation.v_voies
WHERE longueur < 10
```

### Enregistrer une requête comme une table

C'est la même chose que pour enregistrer une vue, sauf qu'on crée une table: les données sont donc stockées en base, et n'évoluent plus en fonction des données source.

Cela permet d'accéder rapidement aux données, car la requête sous-jacente n'est plus exécutée une fois la table créée.

Créer la table des voies

```sql
DROP TABLE IF EXISTS "z_formation".t_voies;
CREATE TABLE "z_formation".t_voies AS
SELECT
-- on récupère tous les champs
source.*,
-- on calcule la longueur après rassemblement des données
st_length(geom) AS longueur
FROM (
        SELECT id, geom
        FROM z_formation.chemin
        UNION ALL
        SELECT id, geom
        FROM z_formation.route
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
