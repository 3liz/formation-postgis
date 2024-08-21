# Gestion des droits

Dans PostgreSQL, on peut créer des rôles (des utilisateurs) et gérer les droits sur les différents objets :
base, schémas, tables, fonctions, etc.

La [documentation officielle de PostgreSQL](https://www.postgresql.org/docs/current/sql-grant.html) est complète, et propose plusieurs exemples.

Nous montrons ci-dessous quelques utilisations possibles.
Attention, pour pouvoir réaliser certaines opérations, vous devez :

* soit être **super-utilisateur** (créer un rôle de connexion)
* soit être **propriétaire** des objets pour lesquels modifier les droits (schémas, tables)

## Donner ou retirer des droits sur des objets existants

Création d'un schéma de test et d'un rôle de connexion, en tant qu'utilisateur avec des droits forts sur la base de données (création de schémas, de tables, etc.).

```sql
-- création d'un schéma de test
CREATE SCHEMA IF NOT EXISTS nouveau_schema;

-- création de tables pour tester
CREATE TABLE IF NOT EXISTS nouveau_schema.observation (id serial primary key, nom text, geom geometry(point, 2154));
CREATE TABLE IF NOT EXISTS nouveau_schema.nomenclature (id serial primary key, code text, libelle text);
```

Création d'un rôle de connexion (en tant que super-utilisateur, ou en tant qu'utilisateur ayant le droit de créer des rôles)

```sql
-- création d'un rôle nommé invite
CREATE ROLE invite WITH PASSWORD 'mot_de_passe_a_changer' LOGIN;
```

On donne le droit de connexion sur la base (nommée ici qgis)

```sql
-- on donne le droit de connexion sur la base
GRANT CONNECT ON DATABASE qgis TO invite;
```

Exemple de requêtes pratiques pour donner ou retirer des droits (en tant qu'utilisateur propriétaire de la base et des objets)

```sql
-- on donne le droit à invite d'utiliser les schéma public et nouveau_schema
-- Utile pour pouvoir lister les tables
-- Si un rôle n'a pas le droit USAGE sur un schéma,
-- il ne peut pas lire les données des tables
-- même si des droits SELECT on été données sur ces tables
GRANT USAGE ON SCHEMA public, nouveau_schema TO "invite", "autre_role";

-- on permet à invite de lire les données (SELECT)
-- de toutes les tables du schéma nouveau_schema
GRANT SELECT ON ALL TABLES IN SCHEMA nouveau_schema TO "invite", "autre_role";

-- On permet l'ajout et la modification de données sur la table observation seulement
GRANT INSERT OR UPDATE ON TABLE nouveau_schema.observation TO "invite";

-- On peut aussi enlever des droits avec REVOKE.
-- Cela enlève seulement les droits donnés précédemment avec GRANT
-- Ex: On pourrait donner tous les droits sur une table
-- puis retirer la possibilité de faire des suppressions
GRANT ALL ON TABLE nouveau_schema.observation TO "autre_role";
-- on retire les droits DELETE et TRUNCATE
REVOKE DELETE, TRUNCATE ON TABLE nouveau_schema.observation FROM "autre_role";

-- On peut aussi par exemple retirer tous les privilèges sur les tables du schéma public
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM "invite";

```

## Droits par défaut sur les nouveaux objets créés par un utilisateur.

Lorsqu'un utilisateur crée un schéma, une table ou une vue, aucun droit n'est donné
sur cet objet aux autres utilisateurs. Par défaut les autres utilisateurs ne peuvent
donc pas par exemple lire les données de ce nouvel objet.

PostgreSQL fournit un moyen de définir en quelque sorte:
*Donner ce(s) droit(s) sur tous ces objets créés par cet utilisateur à ces autres utilisateurs*

Documentation officielle : https://docs.postgresql.fr/current/sql-alterdefaultprivileges.html

```sql
-- Donner le droit SELECT pour toutes les nouvelles tables créées à l'avenir
-- dans le schéma nouveau_schema
ALTER DEFAULT PRIVILEGES IN SCHEMA "nouveau_schema" GRANT SELECT ON TABLES TO "invite", "autre_role";
```

## Lister tous les droits donnés sur tous les objets de la base

Une requête SQL peut être utilisée pour lister tous les droits accordés
sur plusieurs types d'objets : schéma, tables, fonctions, types, aggrégats, etc.

Un exemple de **résultat** :

 object_schema | object_type | object_name   |  object_owner | grantor  | grantee      |  privileges             | is_grantable  |
---------------|-------------|---------------|---------------|----------|--------------|-------------------------|---------------|
 urbanisme     | schema      | urbanisme     | role_sig      | role_sig | role_urba    | CREATE, USAGE           | f             |
 urbanisme     | table       | zone_urba     | role_sig      | role_sig | role_urba    | INSERT, SELECT, UPDATE  | f             |
 cadastre      | schema      | cadastre      | role_sig      | role_sig | role_lecteur | USAGE                   | f             |
 cadastre      | table       | commune       | role_sig      | role_sig | role_lecteur | SELECT                  | f             |
 cadastre      | table       | parcelle      | role_sig      | role_sig | role_lecteur | SELECT                  | f             |

> Si un objet n'est pas retourné par cette requête,
c'est qu'aucun droit spécifique ne lui a été accordé.

<details>
  <summary>
  Requête SQL permettant de récupérer les droits accordés
  sur tous les objets de la base, ainsi que les propriétaires
  et les rôles qui ont accordé ces privilèges
  </summary>

  ```sql
  -- Adapted from https://dba.stackexchange.com/a/285632
  WITH rol AS (
      SELECT oid,
              rolname::text AS role_name
          FROM pg_roles
      UNION
      SELECT 0::oid AS oid,
              'public'::text
  ),
  schemas AS ( -- Schemas
      SELECT oid AS schema_oid,
              n.nspname::text AS schema_name,
              n.nspowner AS owner_oid,
              'schema'::text AS object_type,
              coalesce ( n.nspacl, acldefault ( 'n'::"char", n.nspowner ) ) AS acl
          FROM pg_catalog.pg_namespace n
          WHERE n.nspname !~ '^pg_'
              AND n.nspname <> 'information_schema'
  ),
  classes AS ( -- Tables, views, etc.
      SELECT schemas.schema_oid,
              schemas.schema_name AS object_schema,
              c.oid,
              c.relname::text AS object_name,
              c.relowner AS owner_oid,
              CASE
                  WHEN c.relkind = 'r' THEN 'table'
                  WHEN c.relkind = 'v' THEN 'view'
                  WHEN c.relkind = 'm' THEN 'materialized view'
                  WHEN c.relkind = 'c' THEN 'type'
                  WHEN c.relkind = 'i' THEN 'index'
                  WHEN c.relkind = 'S' THEN 'sequence'
                  WHEN c.relkind = 's' THEN 'special'
                  WHEN c.relkind = 't' THEN 'TOAST table'
                  WHEN c.relkind = 'f' THEN 'foreign table'
                  WHEN c.relkind = 'p' THEN 'partitioned table'
                  WHEN c.relkind = 'I' THEN 'partitioned index'
                  ELSE c.relkind::text
                  END AS object_type,
              CASE
                  WHEN c.relkind = 'S' THEN coalesce ( c.relacl, acldefault ( 's'::"char", c.relowner ) )
                  ELSE coalesce ( c.relacl, acldefault ( 'r'::"char", c.relowner ) )
                  END AS acl
          FROM pg_class c
          JOIN schemas
              ON ( schemas.schema_oid = c.relnamespace )
          WHERE c.relkind IN ( 'r', 'v', 'm', 'S', 'f', 'p' )
  ),
  cols AS ( -- Columns
      SELECT c.object_schema,
              null::integer AS oid,
              c.object_name || '.' || a.attname::text AS object_name,
              'column' AS object_type,
              c.owner_oid,
              coalesce ( a.attacl, acldefault ( 'c'::"char", c.owner_oid ) ) AS acl
          FROM pg_attribute a
          JOIN classes c
              ON ( a.attrelid = c.oid )
          WHERE a.attnum > 0
              AND NOT a.attisdropped
  ),
  procs AS ( -- Procedures and functions
      SELECT schemas.schema_oid,
              schemas.schema_name AS object_schema,
              p.oid,
              p.proname::text AS object_name,
              p.proowner AS owner_oid,
              CASE p.prokind
                  WHEN 'a' THEN 'aggregate'
                  WHEN 'w' THEN 'window'
                  WHEN 'p' THEN 'procedure'
                  ELSE 'function'
                  END AS object_type,
              pg_catalog.pg_get_function_arguments ( p.oid ) AS calling_arguments,
              coalesce ( p.proacl, acldefault ( 'f'::"char", p.proowner ) ) AS acl
          FROM pg_proc p
          JOIN schemas
              ON ( schemas.schema_oid = p.pronamespace )
  ),
  udts AS ( -- User defined types
      SELECT schemas.schema_oid,
              schemas.schema_name AS object_schema,
              t.oid,
              t.typname::text AS object_name,
              t.typowner AS owner_oid,
              CASE t.typtype
                  WHEN 'b' THEN 'base type'
                  WHEN 'c' THEN 'composite type'
                  WHEN 'd' THEN 'domain'
                  WHEN 'e' THEN 'enum type'
                  WHEN 't' THEN 'pseudo-type'
                  WHEN 'r' THEN 'range type'
                  WHEN 'm' THEN 'multirange'
                  ELSE t.typtype::text
                  END AS object_type,
              coalesce ( t.typacl, acldefault ( 'T'::"char", t.typowner ) ) AS acl
          FROM pg_type t
          JOIN schemas
              ON ( schemas.schema_oid = t.typnamespace )
          WHERE ( t.typrelid = 0
                  OR ( SELECT c.relkind = 'c'
                          FROM pg_catalog.pg_class c
                          WHERE c.oid = t.typrelid ) )
              AND NOT EXISTS (
                  SELECT 1
                      FROM pg_catalog.pg_type el
                      WHERE el.oid = t.typelem
                          AND el.typarray = t.oid )
  ),
  fdws AS ( -- Foreign data wrappers
      SELECT null::oid AS schema_oid,
              null::text AS object_schema,
              p.oid,
              p.fdwname::text AS object_name,
              p.fdwowner AS owner_oid,
              'foreign data wrapper' AS object_type,
              coalesce ( p.fdwacl, acldefault ( 'F'::"char", p.fdwowner ) ) AS acl
          FROM pg_foreign_data_wrapper p
  ),
  fsrvs AS ( -- Foreign servers
      SELECT null::oid AS schema_oid,
              null::text AS object_schema,
              p.oid,
              p.srvname::text AS object_name,
              p.srvowner AS owner_oid,
              'foreign server' AS object_type,
              coalesce ( p.srvacl, acldefault ( 'S'::"char", p.srvowner ) ) AS acl
          FROM pg_foreign_server p
  ),
  all_objects AS (
      SELECT schema_name AS object_schema,
              object_type,
              schema_name AS object_name,
              null::text AS calling_arguments,
              owner_oid,
              acl
          FROM schemas
      UNION
      SELECT object_schema,
              object_type,
              object_name,
              null::text AS calling_arguments,
              owner_oid,
              acl
          FROM classes
      UNION
      SELECT object_schema,
              object_type,
              object_name,
              null::text AS calling_arguments,
              owner_oid,
              acl
          FROM cols
      UNION
      SELECT object_schema,
              object_type,
              object_name,
              calling_arguments,
              owner_oid,
              acl
          FROM procs
      UNION
      SELECT object_schema,
              object_type,
              object_name,
              null::text AS calling_arguments,
              owner_oid,
              acl
          FROM udts
      UNION
      SELECT object_schema,
              object_type,
              object_name,
              null::text AS calling_arguments,
              owner_oid,
              acl
          FROM fdws
      UNION
      SELECT object_schema,
              object_type,
              object_name,
              null::text AS calling_arguments,
              owner_oid,
              acl
          FROM fsrvs
  ),
  acl_base AS (
      SELECT object_schema,
              object_type,
              object_name,
              calling_arguments,
              owner_oid,
              ( aclexplode ( acl ) ).grantor AS grantor_oid,
              ( aclexplode ( acl ) ).grantee AS grantee_oid,
              ( aclexplode ( acl ) ).privilege_type AS privilege_type,
              ( aclexplode ( acl ) ).is_grantable AS is_grantable
          FROM all_objects
  ),
  ungrouped AS (
      SELECT acl_base.object_schema,
          acl_base.object_type,
          acl_base.object_name,
          --acl_base.calling_arguments,
          owner.role_name AS object_owner,
          grantor.role_name AS grantor,
          grantee.role_name AS grantee,
          acl_base.privilege_type,
          acl_base.is_grantable
      FROM acl_base
      JOIN rol owner
          ON ( owner.oid = acl_base.owner_oid )
      JOIN rol grantor
          ON ( grantor.oid = acl_base.grantor_oid )
      JOIN rol grantee
          ON ( grantee.oid = acl_base.grantee_oid )
      WHERE acl_base.grantor_oid <> acl_base.grantee_oid
  )
  SELECT
      object_schema, object_type, object_name, object_owner,
      grantor, grantee,
      -- The same function name can be used many times
      -- Since we do not include the calling_arguments field, we should add a DISTINCT below
      string_agg(DISTINCT privilege_type, ' - ' ORDER BY privilege_type) AS privileges,
      is_grantable
  FROM ungrouped
  WHERE True
  -- Simplify objects returned
  -- You can comment the following line to get these types too
  AND object_type NOT IN ('function', 'window', 'aggregate', 'base type', 'composite type')
  -- You can also filter for specific schemas or object names by uncommenting and adapting the following lines
  -- AND object_schema IN ('cadastre', 'environment')
  -- AND object_type = 'table'
  -- AND object_name ILIKE '%parcelle%'
  GROUP BY object_schema, object_type, object_name, object_owner, grantor, grantee, is_grantable
  ORDER BY object_schema, object_type, grantor, grantee, object_name
  ;
  ```

</details>


Continuer vers [Accéder à des données externes: Foreign Data Wrapper](./fdw.md)
