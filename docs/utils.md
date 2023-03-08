# Fonctions utiles

Nous regroupons ici quelques fonctions réalisées au cours de formations ou d'accompagnements d'utilisateurs de PostgreSQL.

## Ajout de l'auto-incrémentation sur un champ entier

Lorsqu'on importe une couche dans une table via les outils de QGIS, le champ d'identifiant choisi n'a pas le support de l'auto-incrémentation, ce qui peut poser des problèmes de l'ajout de nouvelles données.

Par exemple, pour une séquence `monschema.ma_sequence`, si la requête suivante échoue, c'est que la séquence n'est en effet pas correctement configurée :

```sql
SELECT currval('"monschema"."test_id_seq"');
```

Pour ajouter le support de l'auto-incrémentation sur un champ entier à une table existante, on peut utiliser les commandes suivantes:

```sql
-- Création de la séquence
CREATE SEQUENCE monschema.test_id_seq;

-- Modification du champ pour ajouter la valeur par défaut
ALTER TABLE monschema.test ALTER COLUMN id SET DEFAULT nextval('"monschema"."test_id_seq"');

-- Modification de la valeur actuelle de la séquence au maximum du champ id
SELECT setval('"monschema"."test_id_seq"', (SELECT max(id) FROM monschema.test));

-- Déclarer à PostgreSQL que la séquence et le champ sont liés
ALTER SEQUENCE monschema.test_id_seq OWNED BY monschema.test.id;
```

Dans l'exemple ci-dessus, le schéma est précisé.

## Création automatique d'indexes spatiaux

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

## Trouver toutes les tables sans clé primaire

Il est très important de déclarer une clé primaire pour vos tables stockées dans PostgreSQL. Cela fournit un moyen aux logiciels comme QGIS d'identifier de manière performante les lignes dans une table. Sans clé primaire, les performances d'accès aux données peuvent être dégradées.

Vous pouvez trouver l'ensemble des tables de votre base de données sans clé primaire en construisant cette vue PostgreSQL `tables_without_primary_key`:

```sql
DROP VIEW IF EXISTS tables_without_primary_key;
CREATE VIEW tables_without_primary_key AS
SELECT t.table_schema, t.table_name
FROM information_schema.tables AS t
LEFT JOIN information_schema.table_constraints AS c
    ON t.table_schema = c.table_schema
    AND t.table_name = c.table_name
    AND c.constraint_type = 'PRIMARY KEY'
WHERE True
AND t.table_type = 'BASE TABLE'
AND t.table_schema not in ('pg_catalog', 'information_schema')
AND c.constraint_name IS NULL
ORDER BY table_schema, table_name
;
```

* Pour lister les tables sans géométries, vous pouvez ensuite lancer la requête suivante:

```sql
SELECT *
FROM tables_without_primary_key;
```

Ce qui peut donner par exemple:

| table_schema  | table_name     |
|---------------|----------------|
| agriculture   | parcelles      |
| agriculture   | puits          |
| cadastre      | sections       |
| environnement | znieff         |
| environnement | parcs_naturels |


* Pour lister les tables sans géométries d'un seul schéma, par exemple `cadastre`, vous pouvez ensuite lancer la requête:

```sql
SELECT *
FROM tables_without_primary_key
WHERE table_schema IN ('cadastre');
```

Ce qui peut alors donner:

| table_schema  | table_name     |
|---------------|----------------|
| cadastre      | sections       |



## Ajouter automatiquement plusieurs champs à plusieurs tables

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

## Vérifier la taille des bases, tables et schémas

### Connaître la taille des bases de données

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

### Calculer la taille des tables

On crée une fonction `get_table_info` qui utilise les tables système pour lister les tables, récupérer leur schéma et les informations de taille.

```sql
DROP FUNCTION IF EXISTS get_table_info();
CREATE OR REPLACE FUNCTION get_table_info()
RETURNS TABLE (
    oid oid,
    schema_name text,
    table_name text,
    row_count integer,
    total_size bigint,
    pretty_total_size text
)
AS $$
BEGIN
    RETURN QUERY
    SELECT
        b.oid, b.schema_name::text, b.table_name::text,
        b.row_count::integer,
        b.total_size::bigint,
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

### Calculer la taille des schémas

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

## Tester les différences entre 2 tables de même structure

Nous souhaitons **comparer deux tables de la base**, par exemple une table de communes en 2021 `communes_2021` et une table de communes en 2022 `communes_2022`.

On peut utiliser une fonction qui utilise les possibilités du format hstore pour comparer les données entre elles.

```sql
-- On ajoute le support du format hstore
CREATE EXTENSION IF NOT EXISTS hstore;

-- On crée la fonction de comparaison
DROP FUNCTION compare_tables(text,text,text,text,text,text[]);
CREATE OR REPLACE FUNCTION compare_tables(
	p_schema_name_a text,
	p_table_name_a text,
	p_schema_name_b text,
	p_table_name_b text,
	p_common_identifier_field text,
	p_excluded_fields text[]

) RETURNS TABLE(
	uid text,
	status text,
	table_a_values hstore,
	table_b_values hstore
)
    LANGUAGE plpgsql
    AS $_$
DECLARE
    sqltemplate text;
BEGIN

    -- Compare data
    sqltemplate = '
    SELECT
        coalesce(ta."%1$s", tb."%1$s") AS "%1$s",
        CASE
            WHEN ta."%1$s" IS NULL THEN ''not in table A''
            WHEN tb."%1$s" IS NULL THEN ''not in table B''
            ELSE ''table A != table B''
        END AS status,
        CASE
            WHEN ta."%1$s" IS NULL THEN NULL
            ELSE (hstore(ta.*) - ''%6$s''::text[]) - (hstore(tb) - ''%6$s''::text[])
        END AS values_in_table_a,
        CASE
            WHEN tb."%1$s" IS NULL THEN NULL
            ELSE (hstore(tb.*) - ''%6$s''::text[]) - (hstore(ta) - ''%6$s''::text[])
        END AS values_in_table_b
    FROM "%2$s"."%3$s" AS ta
    FULL JOIN "%4$s"."%5$s" AS tb
        ON ta."%1$s" = tb."%1$s"
    WHERE
        (hstore(ta.*) - ''%6$s''::text[]) != (hstore(tb.*) - ''%6$s''::text[])
        OR (ta."%1$s" IS NULL)
        OR (tb."%1$s" IS NULL)
    ';

    RETURN QUERY
    EXECUTE format(sqltemplate,
		p_common_identifier_field,
        p_schema_name_a,
        p_table_name_a,
        p_schema_name_b,
        p_table_name_b,
        p_excluded_fields
    );

END;
$_$;
```

Cette fonction attend en paramètres

* le schéma de la **table A**. Ex: `referentiels`
* le nom de la **table A**. Ex: `communes_2021`
* le schéma de la **table B**. Ex: `referentiels`
* le nom de la **table B**. Ex: `communes_2022`
* le nom du champ qui identifie de manière unique la donnée. Ce n'est pas forcément la clé primaire. Ex `code_commune`
* un tableau de champs pour lesquels ne pas vérifier les différences. Ex: `array['region', 'departement']`

La requête à lancer est la suivantes
```sql
SELECT "uid", "status", "table_a_values", "table_b_values"
FROM compare_tables(
    'referentiels', 'commune_2021',
    'referentiels', 'commune_2022',
    'code_commune',
    array['region', 'departement']
)
ORDER BY status, uid
;
```

Exemple de données renvoyées:

| uid   | status             | table_a_values                                                              | table_b_values                                                               |
|-------|--------------------|-----------------------------------------------------------------------------|------------------------------------------------------------------------------|
| 12345 | not in table A     | NULL                                                                        | "annee_ref"=>"2022", "nom_commune"=>"Nouvelle commune", "population"=>"5723" |
| 97612 | not in table B     | "annee_ref"=>"2021", "nom_commune"=>"Ancienne commune", "population"=>"840" | NULL                                                                         |
| 97602 | table A != table B | "annee_ref"=>"2021", "population"=>"1245"                                   | "annee_ref"=>"2022", "population"=>"1322"                                    |

Dans l'affichage ci-dessus, je n'ai pas affiché le champ de géométrie, mais la fonction teste aussi les différences de géométries.

*Attention, les performances de ce type de requête ne sont pas forcément assurées pour des volumes de données importants.*


## Lister les triggers appliqués sur les tables

On peut utiliser la requête suivante pour lister l'ensemble des triggers activés sur les tables

```sql
SELECT
    event_object_schema AS table_schema,
    event_object_table AS table_name,
    trigger_schema,
    trigger_name,
    string_agg(event_manipulation, ',') AS event,
    action_timing AS activation,
    action_condition AS condition,
    action_statement AS definition
FROM information_schema.triggers
GROUP BY 1,2,3,4,6,7,8
ORDER BY table_schema, table_name
;
```

Cette requête renvoie un tableau de la forme :

| table_schema |       table_name       | trigger_schema |     trigger_name     | event  | activation | condition |                      definition                      |
|--------------|------------------------|----------------|----------------------|--------|------------|-----------|------------------------------------------------------|
| gestion      | acteur                 | gestion        | tr_date_maj          | UPDATE | BEFORE     |           | EXECUTE FUNCTION occtax.maj_date()                   |
| occtax       | organisme              | occtax         | tr_date_maj          | UPDATE | BEFORE     |           | EXECUTE FUNCTION occtax.maj_date()                   |
| taxon        | iso_metadata_reference | taxon          | update_imr_timestamp | UPDATE | BEFORE     |           | EXECUTE FUNCTION taxon.update_imr_timestamp_column() |


## Lister les fonctions installées par les extensions

Il est parfois utile de lister les **fonctions des extensions**, par exemple pour :

* vérifier leur nom et leurs paramètres.
* détecter celles qui n'ont pas le bon propriétaire

La requête suivante permet d'afficher les informations essentielles des fonctions créées
par les extensions installées dans la base :

```sql
SELECT DISTINCT
    ne.nspname AS extension_schema,
    e.extname AS extension_name,
    np.nspname AS function_schema,
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS function_params,
    proowner::regrole AS function_owner
FROM
    pg_catalog.pg_extension AS e
    INNER JOIN pg_catalog.pg_depend AS d ON (d.refobjid = e.oid)
    INNER JOIN pg_catalog.pg_proc AS p ON (p.oid = d.objid)
    INNER JOIN pg_catalog.pg_namespace AS ne ON (ne.oid = e.extnamespace)
    INNER JOIN pg_catalog.pg_namespace AS np ON (np.oid = p.pronamespace)
WHERE
    TRUE
    -- only extensions
    AND d.deptype = 'e'
    -- not in pg_catalog
    AND ne.nspname NOT IN ('pg_catalog')
    -- optionnally filter some extensions
    -- AND e.extname IN ('postgis', 'postgis_raster')
    -- optionnally filter by some owner
    AND proowner::regrole::text IN ('postgres')
    ORDER BY
        extension_name,
        function_name;
;
```

qui renvoie une résultat comme ceci (cet exemple est un extrait de quelques lignes) :


|  extension_schema | extension_name | function_schema |               function_name |                    function_params                   | function_owner  |
|-------------------|----------------|-----------------|-----------------------------|------------------------------------------------------|-----------------|
| public            | fuzzystrmatch  | public          | levenshtein_less_equal      | text, text, integer                                  | johndoe         |
| public            | fuzzystrmatch  | public          | metaphone                   | text, integer                                        | johndoe         |
| public            | fuzzystrmatch  | public          | soundex                     | text                                                 | johndoe         |
| public            | fuzzystrmatch  | public          | text_soundex                | text                                                 | johndoe         |
| public            | hstore         | public          | akeys                       | hstore                                               | johndoe         |
| public            | hstore         | public          | avals                       | hstore                                               | johndoe         |
| public            | hstore         | public          | defined                     | hstore, text                                         | johndoe         |
| public            | postgis        | public          | st_buffer                   | text, double precision, integer                      | johndoe         |
| public            | postgis        | public          | st_buffer                   | geom geometry, radius double precision, options text | johndoe         |
| public            | postgis        | public          | st_buildarea                | geometry                                             | johndoe         |

On peut bien sûr modifier la clause `WHERE` pour filtrer plus ou moins les fonctions renvoyées.

Continuer vers [Gestion des droits](./grant.md)
