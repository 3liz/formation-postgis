## Fonctions utiles

Nous regroupons ici quelques fonctions réalisées au cours de formations ou d'accompagnements d'utilisateurs de PostgreSQL.

### Ajout de l'auto-incrémentation sur un champ entier

Lorsqu'on importe une couche dans une table via les outils de QGIS, le champ d'identifiant choisi n'a pas le support de l'auto-incrémentation, ce qui peut poser des problèmes de l'ajout de nouvelles données.

Pour ajouter le support de l'auto-incrémentation sur un champ entier à une table existante, on peut utiliser les commandes suivantes:

```sql
-- Création de la séquence
CREATE SEQUENCE test_id_seq;

-- Modification du champ pour ajouter la valeur par défaut
ALTER TABLE test ALTER COLUMN id SET DEFAULT nextval('test_id_seq');

-- Modification de la valeur actuelle de la séquence au maximum du champ id
SELECT setval('test_id_seq', (SELECT max(id from test));

-- Déclarer à PostgreSQL que la séquence et le champ sont liés
ALTER SEQUENCE test_id_seq OWNED BY test.id;
```

### Création automatique d'indexes spatiaux

Pour des données spatiales volumineuses, les performances d'affichage sont bien meilleures à grande échelle si on a ajouté un **index spatial**. L'index est aussi beaucoup utilisé pour améliorer les performances d'analyses spatiales.

On peut créer l'index spatial table par table, ou bien automatiser cette création, c'est-à-dire créer les indexes spatiaux **pour toutes les tables qui n'en ont pas**.

Pour cela, nous avons conçu une fonction, téléchargeable ici: https://gist.github.com/mdouchin/cfa0e37058bcf102ed490bc59d762042

On doit copier/coller le script SQL de cette page "gist" dans la **fenêtre SQL** du Gestionnaire de bases de données de QGIS, puis lancer la requête avec **Exécuter**. On peut ensuite vider le contenu de la fenêtre, puis appeler la fonction `create_missing_spatial_indexes` via le code SQL suivant:

```sql
-- On lance avec le paramètre à True si on veut juste voir les tables qui n'ont pas d'index spatial
-- On lance avec False si on veut créer les indexes automatiquement

-- Vérification
SELECT * FROM create_missing_spatial_indexes(  True );

-- Création
SELECT * FROM create_missing_spatial_indexes(  False );
```

### Ajouter automatiquement plusieurs champs à plusieurs tables

Il est parfois nécessaire d'**ajouter des champs à une ou plusieurs tables**, par exemple pour y stocker ensuite des métadonnées (date de modification, date d'ajout, utilisateur, lien, etc).

Nous proposons pour cela la fonction `ajout_champs_dynamiques` qui permet de fournir un nom de schéma, un nom de table, et une chaîne de caractère contenant la liste séparée par virgule des champs et de leur type.

La fonction est accessible ici: https://gist.github.com/mdouchin/50234f1f33801aed6f4f2cbab9f4887c

* Exemple d'utilisation **pour une table** `commune` du schéma `test`: on ajoute les champs `date_creation`, `date_modification` et `utilisateur`

```sql
SELECT
ajout_champs_dynamiques('test', 'commune', 'date_creation timestamp DEFAULT now(), date_modification timestamp DEFAULT now(), utilisateur text')
;
```

* Exemple d'utilisation pour **toutes les tables d'un schéma**, ici le schéma `test`. On utilise dans cette exemple la vue `geometry_columns` qui liste les tables spatiales, car on souhaite aussi ne faire cet ajout que pour les données de type **POINT**

```sql
-- Lancer la création de champs sur toutes les tables
-- du schéma test
-- contenant des géométries de type Point
SELECT f_table_schema, f_table_name,
ajout_champs_dynamiques(
    -- schéma
    f_table_schema,
    -- table
    f_table_name,
    -- liste des champs, au format nom_du_champ TYPE
    'date_creation timestamp DEFAULT now(), date_modification timestamp DEFAULT now(), utilisateur text'
)
FROM geometry_columns
WHERE True
AND "type" LIKE '%POINT'
AND f_table_schema IN ('test')
ORDER BY f_table_schema, f_table_name
;
```

### Vérifier la taille des bases, tables et schémas

#### Connaître la taille des bases de données

On peut lancer la requête suivante, qui renvoit les bases de données ordonnées par taille descendante.

```sql
SELECT
pg_database.datname AS db_name,
pg_database_size(pg_database.datname) AS db_size,
pg_size_pretty(pg_database_size(pg_database.datname)) AS db_pretty_size
FROM pg_database
WHERE datname NOT IN ('postgres', 'template0', 'template1')
ORDER BY db_size DESC;
```

#### Calculer la taille des tables

On crée une fonction `get_table_info` qui utilise les tables système pour lister les tables, récupérer leur schéma et les informations de taille.

```sql
CREATE OR REPLACE FUNCTION get_table_info()
RETURNS TABLE (
    oid oid,
    schema_name text,
    table_name text,
    row_count integer,
    total_size integer,
    pretty_total_size text
)
AS $$
BEGIN
    RETURN QUERY
    SELECT
        b.oid, b.schema_name::text, b.table_name::text,
        b.row_count::integer,
        b.total_size::integer,
        pg_size_pretty(b.total_size) AS pretty_total_size
    FROM (
        SELECT *,
        a.total_size - index_bytes - COALESCE(toast_bytes,0) AS table_bytes
        FROM (
            SELECT
            c.oid,
            nspname AS schema_name,
            relname AS TABLE_NAME,
            c.reltuples AS row_count,
            pg_total_relation_size(c.oid) AS total_size,
            pg_indexes_size(c.oid) AS index_bytes,
            pg_total_relation_size(reltoastrelid) AS toast_bytes
            FROM pg_class c
            LEFT JOIN pg_namespace n
                ON n.oid = c.relnamespace
            WHERE relkind = 'r'
            AND nspname NOT IN ('pg_catalog', 'information_schema')
        ) AS a
    ) AS b
    ;
END; $$
LANGUAGE 'plpgsql';
```

On peut l'utiliser simplement de la manière suivante

```sql
-- Liste les tables
SELECT * FROM get_table_info() ORDER BY schema_name, table_name DESC;

-- Lister les tables dans l'ordre inverse de taille
SELECT * FROM get_table_info() ORDER BY total_size DESC;

```

#### Calculer la taille des schémas

On crée une simple fonction qui renvoit la somme des tailles des tables d'un schéma

```sql
-- Fonction pour calculer la taille d'un schéma
CREATE OR REPLACE FUNCTION pg_schema_size(schema_name text)
RETURNS BIGINT AS
$$
    SELECT
        SUM(pg_total_relation_size(quote_ident(schemaname) || '.' || quote_ident(tablename)))::BIGINT
    FROM pg_tables
    WHERE schemaname = schema_name
$$
LANGUAGE SQL;
```

On peut alors l'utiliser pour connaître la taille d'un schéma

```sql
-- utilisation pour un schéma
SELECT pg_size_pretty(pg_schema_size('public')) AS ;
```

Ou lister l'ensemble des schémas

```sql
-- lister les schémas et récupérer leur taille
SELECT schema_name, pg_size_pretty(pg_schema_size(schema_name))
FROM information_schema.schemata
WHERE schema_name NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_schema_size(schema_name) DESC;
```
