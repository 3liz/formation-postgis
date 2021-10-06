# Gestion des droits

Dans PostgreSQL, on peut créer des roles (des utilisateurs) et gérer les droits sur les différents objets: base, schémas, tables, fonctions, etc.

La [documentation officielle de PostgreSQL](https://www.postgresql.org/docs/current/sql-grant.html) est complète, et propose plusieurs exemples.

Nous montrons ci-dessous quelques utilisations possibles. Attention, pour pouvoir réaliser certaines opérations, vous devez:

* soit être **super-utilisateur** (créer un rôle de connexion)
* soit être **propriétaire** des objets pour lesquels modifier les droits


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
GRANT USAGE ON SCHEMA public, nouveau_schema TO "invite";

-- on permet à invite de lire les données (SELECT)
-- de toutes les tables du schéma nouveau_schema
GRANT SELECT ON ALL TABLES IN SCHEMA nouveau_schema TO "invite";

-- On permet l'ajout et la modification de données sur la table observation seulement
GRANT INSERT OR UPDATE ON TABLE nouveau_schema.observation TO "invite";

-- On peut aussi enlever des droits avec REVOKE.
-- Ex: on enlève la possibilité de faire des suppresions
REVOKE DELETE ON TABLE nouveau_schema.observation FROM "invite";

-- On enlève tous les privilèges sur les tables du schéma public
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM "invite";

-- On donne les droits de sélection sur les tables du schéma public
GRANT SELECT ON ALL TABLES IN SCHEMA public TO "invite";

```

Droits par défaut sur les nouveaux objets créés

```sql
-- TODO
```

Continuer vers [Accéder à des données externes: Foreign Data Wrapper](./fdw.md)
