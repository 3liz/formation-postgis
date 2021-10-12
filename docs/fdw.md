# Accéder à des données externes : les Foreign Data Wrapper (FDW)

L'utilisation d'un FDW permet de **consulter des données externes** à la base comme si elles étaient stockées dans des tables. On peut lancer des requêtes pour récupérer seulement certains champs, filtrer les données, etc.

Des **tables étrangères** sont créées, qui pointent vers les données externes. A chaque requête sur ces tables, PostgreSQL récupère les données depuis la connexion au serveur externe.

On passe classiquement par les étapes suivantes:

* Ajout de l'**extension** correspondant au format souhaité: `postgres_fdw` (bases PostgreSQL externes), `ogr_fdw` (données vectorielles via ogr2ogr), etc.
* Création d'un **serveur** qui permet de configurer les informations de connexion au serveur externe
* Création optionnelle d'un **schéma** pour y stocker les tables de ce serveur
* Création manuelle ou automatique de **tables étrangères** qui pointent vers les données externes
* **Requêtes** sur ces tables étrangères


## Le FDW ogr_fdw pour lire des données vectorielles

Avec ce Foreign Data Wrapper **ogr_fdw**, on peut appeler n'importe quelle source de données externe compatible avec la librairie **ogr2ogr** et les exploiter comme des tables: fichiers GeoJSON ou Shapefile, GPX, CSV, mais aussi les protocoles comme le WFS.

Voir la [documentation officielle de ogr_fdw](https://github.com/pramsey/pgsql-ogr-fdw). 

### Installation

Pour l'installer sur une machine **Linux**, il suffit d'installer le paquet correspondant à la version de PostgreSQL, par exemple `postgresql-11-ogr-fdw`. 

Sous **Windows**, il est disponible avec le paquet PostGIS via l'outil [StackBuilder](https://www.postgresql.org/download/windows/).

### Exemple d'utilisation: récupérer des couches d'un serveur WFS

Nous allons utiliser le FDW pour récupérer des données mises à disposition sur le serveur de l'INPN via le protocole WFS.

Vous pouvez d'abord tester dans QGIS quelles données sont disponibles sur ce serveur en créant une nouvelle connexion WFS avec l'URL `http://ws.carmencarto.fr/WFS/119/fxx_inpn?`

Via QGIS ou un autre client à la base de données, nous pouvons maintenant montrer comment récuperer ces données:

* Ajouter l'**extension** `ogr_fdw`:

```sql
-- Ajouter l'extension pour lire des fichiers SIG
-- Cette commande doit être lancée par un super utilisateur (ou un utilisateur ayant le droit de le faire)
CREATE EXTENSION IF NOT EXISTS ogr_fdw;
```

* Créer le **serveur** de données:

```sql
-- Créer le serveur
DROP SERVER IF EXISTS fdw_ogr_inpn_metropole;
CREATE SERVER fdw_ogr_inpn_metropole FOREIGN DATA WRAPPER ogr_fdw
OPTIONS (
    datasource 'WFS:http://ws.carmencarto.fr/WFS/119/fxx_inpn?',
    format 'WFS'
);
```

* Créer un **schéma** pour y stocker les tables étrangères:

```sql
-- Créer un schéma pour la dreal
CREATE SCHEMA IF NOT EXISTS inpn_metropole;
```

* Créer automatiquement les **tables étrangères** qui "pointent" vers les couches du WFS, via la commande `IMPORT SCHEMA`:

```sql
-- Récupérer l'ensemble des couches WFS comme des tables dans le schéma ref_dreal
IMPORT FOREIGN SCHEMA ogr_all
FROM SERVER fdw_ogr_inpn_metropole
INTO inpn_metropole
OPTIONS (
    -- mettre le nom des tables en minuscule et sans caractères bizares
    launder_table_names 'true',
    -- mettre le nom des champs en minuscule
    launder_column_names 'true'
)
;
```

* Lister les tables récupérées

```sql
SELECT foreign_table_schema, foreign_table_name
FROM information_schema.foreign_tables
WHERE foreign_table_schema = 'inpn_metropole'
ORDER BY foreign_table_schema, foreign_table_name;
```

ce qui montre:

| foreign_table_schema | foreign_table_name                               |
|----------------------|--------------------------------------------------|
| inpn_metropole       | arretes_de_protection_de_biotope                 |
| inpn_metropole       | arretes_de_protection_de_geotope                 |
| inpn_metropole       | bien_du_patrimoine_mondial_de_l_unesco           |
| inpn_metropole       | geoparcs                                         |
| inpn_metropole       | ospar                                            |
| inpn_metropole       | parc_naturel_marin                               |
| inpn_metropole       | parcs_nationaux                                  |
| inpn_metropole       | parcs_naturels_regionaux                         |
| inpn_metropole       | reserves_biologiques                             |
| inpn_metropole       | reserves_de_la_biosphere                         |
| inpn_metropole       | reserves_integrales_de_parcs_nationaux           |
| inpn_metropole       | reserves_nationales_de_chasse_et_faune_sauvage   |
| inpn_metropole       | reserves_naturelles_nationales                   |
| inpn_metropole       | reserves_naturelles_regionales                   |
| inpn_metropole       | rnc                                              |
| inpn_metropole       | sites_d_importance_communautaire                 |
| inpn_metropole       | sites_d_importance_communautaire_joue__zsc_sic_  |
| inpn_metropole       | sites_ramsar                                     |
| inpn_metropole       | terrains_des_conservatoires_des_espaces_naturels |
| inpn_metropole       | terrains_du_conservatoire_du_littoral            |
| inpn_metropole       | zico                                             |
| inpn_metropole       | znieff1                                          |
| inpn_metropole       | znieff1_mer                                      |
| inpn_metropole       | znieff2                                          |
| inpn_metropole       | znieff2_mer                                      |
| inpn_metropole       | zones_de_protection_speciale                     |


* **Lire les données** des couches WFS via une **simple requête** sur les tables étrangères:

```sql
-- Tester
SELECT *
FROM inpn_metropole.zico
LIMIT 1;
```

**Attention**, lorsqu'on accède depuis PostgreSQL à un serveur WFS, on est tributaire 

* des performances de ce serveur, 
* et du temps de transfert des données vers la base.

Nous **déconseillons fortement** dans ce cas de charger le serveur externe en réalisant des requêtes complexes (ou trop fréquentes) sur ces tables étrangères, surtout lorsque les données évoluent peu.

Au contraire, nous conseillons de créer des **vues matérialisées** à partir des tables étrangères pour éviter des requêtes lourdes en stockant les données dans la base:

```sql
-- Pour éviter de requêter à chaque fois le WFS, on peut créer des vues matérialisées

-- suppression de la vue si elle existe déjà
DROP MATERIALIZED VIEW IF EXISTS inpn_metropole.vm_zico;

-- création de la vue: on doit parfois forcer le type de géométrie attendue
CREATE MATERIALIZED VIEW inpn_metropole.vm_zico AS
SELECT *, 
(ST_multi(msgeometry))::geometry(multipolygon, 2154) AS geom
FROM inpn_metropole.zico
;

-- Ajout d'un index spatial sur la géométrie
CREATE INDEX ON inpn_metropole.vm_zico USING GIST (geom);
```

Une fois la vue créée, vous pouvez faire vos requêtes sur cette vue, avec des performances bien meilleures et un allègement de la charge sur le serveur externe.

Pour **rafraîchir** les données à partir du serveur WFS, il suffit de rafraîchir la ou les vues matérialisées:

```sql
-- Rafraîchir la vue, par exemple à lancer une fois par mois
REFRESH MATERIALIZED VIEW inpn_metropole.vm_zico;
```

## Le FDW postgres_fdw pour accéder aux tables d'une autre base de données PostgreSQL

```sql
-- Création du serveur externe
DROP SERVER IF EXISTS foreign_server_test CASCADE;
CREATE SERVER IF NOT EXISTS foreign_server_test
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (host 'mon_serveur_postgresql_externe.com', port '5432', dbname 'external_database')
;

-- on déclare se connecter en tant qu'utilisateur mon_utilisateur externe lorsqu'on récupère des données
CREATE USER MAPPING FOR ""
SERVER foreign_server_test
OPTIONS (user 'mon_utilisateur', password '***********');

-- on stocke les tables étrangères dans un schéma spécifique pour isoler des autres schémas en dur
DROP SCHEMA IF EXISTS fdw_test_schema CASCADE;
CREATE SCHEMA IF NOT EXISTS fdw_test_schema;

-- importer automatiquement les tables d'un schéma de la base distante
IMPORT FOREIGN SCHEMA "un_schema"
LIMIT TO ("une_table", "une_autre_table")
FROM SERVER foreign_server_test
INTO fdw_test_schema;

-- Tester
SELECT * FROM fdw_test_schema.une_table LIMIT 1;
```


Continuer vers [Tutoriels en ligne](./tutoriel.md)
