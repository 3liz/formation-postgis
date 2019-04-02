## Gestion des données PostgreSQL dans QGIS

Lorsqu'on travaille avec des données PostgreSQL, QGIS n'accède pas à la donnée en lisant un ou plusieurs fichiers, mais fait des requêtes à la base, à chaque fois qu'il en a besoin: déplacement de carte, zoom, ouverture de la table attributaire, sélection par expression, etc.

* QGIS se connecte à la base de données, et lit des données qui sont stockées dans des tables. Il doit donc télécharger la donnée à chaque action (pas de cache car la donnée peut changer entre temps).
* une table = une couche: 1 nom, une liste de champs, et une géométrie.
* une géométrie est caractérisée par un type (polygone, point, ligne, etc.) et une projection (Ex: EPSG:2154) appelé SRID ( Ex: 2154)
* on peut ne pas avoir de géométrie dans une table, qu'on appelle alors non spatiale. QGIS sait les ouvrir: cela permet de stocker des informations de contexte (nomenclature, événements).

La base de données fournit donc un lieu de stockage unique et centralisé. On peut gérer les droits d'accès ou d'écriture sur les schémas et les tables.


### Créer une connexion à la base de données

Dans QGIS, il faut créer une nouvelle connexion à PostgreSQL, via l'outil "Eléphant" : menu **Couches / Ajouter une couche / Ajouter une couche PostgreSQL** . Configurer les options suivantes:

* laisser le champ "Service" vide
* cocher les cases "Enregistrer" à côté de l'utilisateur et du mot de passe (après avoir "Tester la connexion")
* cocher la dernière case tout en base "Utiliser la table de métadonnées estimées"
* Valider

**Attention** Pour plus de sécurité, privilégier l'usage d'un service PostgreSQL: https://docs.qgis.org/2.18/fr/docs/user_manual/managing_data_source/opening_data.html#pg-service-file

Il est aussi intéressant pour les **performances** d'accès aux données PostgreSQL de modifier une option dans les options de QGIS, onglet **Rendu**: il faut cocher la case **Réaliser la simplification par le fournisseur de données lorsque c'est possible**. Cela permet de télécharger des versions allégées des données aux petites échelles.

**NB** Pour les couches PostGIS qui auraient déjà été ajoutées avant d'avoir activé cette option, vous pouvez manuellement changer dans vos projets via l'onglet **Rendu** de la boîte de dialogue des propriétés de chaque couche PostGIS.

### Ouvrir une couche PostgreSQL

Trois solutions sont possibles:

* **utiliser l'explorateur** : seulement pour les tables spatiales, sauf si on a coché **Lister les tables sans géométries** dans les propriétés de la connexion
* utiliser le menu **Couches / Ajouter une couche**
* utiliser le **gestionnaire de base de données**

### Le gestionnaire de base de données

On travaille via QGIS, avec le gestionnaire de bases de données : menu **Base de données > gestionnaire de base de données** (sinon barre d’outil base de données).

NB: On pourrait aussi travailler avec PgAdmin 4, si on a besoin de réaliser des opérations de maintenance (gestion des droits, des utilisateurs, etc.)

Dans l'arbre qui se présente à gauche du gestionnaire de bdd, on peut **choisir sa connexion**, puis double-cliquer, ce qui montre l'ensemble des **schémas**. Les menus du gestionnaire permettent de créer ou d'éditer des objets (schémas, tables).

Une **fenêtre SQL** permet de lancer manuellement des requêtes SQL. Nous allons principalement utiliser cet outil : menu "Base de données > fenêtre SQL" (ou F2). :

### Création de tables

Depuis **QGIS**: dans le gestionnaire de base de données, menu table, créer une table:

* choisir le **schéma** et le **nom** de la table, en minuscule, sans accents ni caractères complexes
* Via le bouton **Ajouter un champ**, on commence par ajouter un champ **id** de type **serial** (entier auto-incrémenté), puis d'autres champs en choisissant le nom et le type. Choisir des noms de champ simples !
* Choisir dans la liste déroulante le **champ de clé primaire** (ici id)
* Cocher **Créer une colonne géométrique** et choisir le type
* Cocher **Créer un index spatial**

**NB**: on a créé une table dans cet exemple urbanisme.borne_incendie.

**Créer une table en SQL**

```sql
-- création d'un schéma
CREATE SCHEMA IF NOT EXISTS urbanisme;
-- création de la table
CREATE TABLE urbanisme.borne_incendie (
        id_borne serial not null primary key,
        code text NOT NULL,
        debit real,
        geom geometry(Point, 2154)
);
-- Création de l'index spatial
CREATE INDEX ON urbanisme.borne_incendie USING GIST (geom);

```

### Création d’un schéma z_formation dans la base

* ajout du schéma via le gestionnaire de bdd, ou via une requête:

```sql
CREATE SCHEMA IF NOT EXISTS z_formation;
```

* modification des droits d’accès à ce schéma, si besoin:

```sql
-- On donne ici tous les droits à Julie
GRANT ALL PRIVILEGES ON SCHEMA z_formation TO "unutilisateur";
```

* suppression d'un schéma

```sql
-- Suppression du schéma si il est vide
DROP SCHEMA monschema;
-- idem et de toutes les tables de ce schéma (via CASCADE) ATTENTION !!!
DROP SCHEMA monschema CASCADE;
```

* renommer un schéma

```sql
ALTER SCHEMA monschema RENAME TO unschema;
```

### Vérifier et créer les indexes spatiaux

On peut vérifier si chaque table contient un **index spatial** via le gestionnaire de base de données de QGIS, en cliquant sur la table dans l'arbre, puis en regardant les informations de l'onglet **Info**. On peut alors créer l'index spatial via le lien bleu **Aucun index spatial défini (en créer un)**

Si on souhaite faire cela d'un seul coup pour toutes les tables qui n'ont pas d'index spatial, il existe une fonction que j'ai développée: https://gist.github.com/mdouchin/cfa0e37058bcf102ed490bc59d762042

On doit copier/coller le script SQL de cette page dans la **fenêtre SQL** du Gestionnaire, puis lancer la requête avec **Exécuter**. On peut ensuite vider le contenu de la fenêtre, puis appeler la fonction:

```sql
-- On lance avec le paramètre à True si on veut juste voir les tables sans index
-- On lance avec False si on veut créer les indexes automatiquement
-- Vérification
SELECT * FROM create_missing_spatial_indexes(  True );
-- Création
SELECT * FROM create_missing_spatial_indexes(  False );
```
