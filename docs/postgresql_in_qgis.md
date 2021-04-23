# Gestion des données PostgreSQL dans QGIS

## Introduction

Lorsqu'on travaille avec des données **PostgreSQL**, QGIS n'accède pas à la donnée en lisant un ou plusieurs fichiers, mais fait des **requêtes** à la base, à chaque fois qu'il en a besoin: déplacement de carte, zoom, ouverture de la table attributaire, sélection par expression, etc.

* QGIS se connecte à la base de données, et récupère des données qui sont stockées dans des tables. Il doit donc **télécharger la donnée** à chaque action (pas de cache car la donnée peut changer entre temps).
* une table équivaut à une couche SIG, définie par un nom, une liste de champs typés, et une ou plusieurs champs de géométrie.
* une géométrie est caractérisée par un type (polygone, point, ligne, etc.), une dimension (2D ou 3D) et une projection (Ex: EPSG:2154) codifiée via un SRID ( Ex: 2154)
* certaines tables n'ont pas de géométrie: on les appelle alors non spatiales. QGIS sait les exploiter, ce qui permet de stocker des informations de contexte (nomenclature, événements).

La base de données fournit donc un lieu de stockage des données centralisé. On peut gérer les droits d'accès ou d'écriture sur les schémas et les tables.


## Créer une connexion QGIS à la base de données

Dans QGIS, il faut **créer une nouvelle connexion** à PostgreSQL, via l'outil "Eléphant" : menu **Couches / Ajouter une couche / Ajouter une couche PostgreSQL** . Configurer les options suivantes:

* laisser le champ **Service** vide
* cocher les cases **Enregistrer** à côté de l'utilisateur et du mot de passe, après avoir **Tester la connexion** (via le bouton dédié)
* cocher la dernière case tout en base **Utiliser la table de métadonnées estimées**
* Valider

**Attention** Pour plus de sécurité, privilégier l'usage d'un service PostgreSQL: 
https://docs.qgis.org/3.10/fr/docs/user_manual/managing_data_source/opening_data.html#pg-service-file

Il est aussi intéressant pour les **performances** d'accès aux données PostgreSQL de modifier une option dans les options de QGIS, onglet **Rendu**: il faut cocher la case **Réaliser la simplification par le fournisseur de données lorsque c'est possible**. Cela permet de télécharger des versions allégées des données aux petites échelles.

**NB** Pour les couches PostGIS qui auraient déjà été ajoutées avant d'avoir activé cette option, vous pouvez manuellement changer dans vos projets via l'onglet **Rendu** de la boîte de dialogue des propriétés de chaque couche PostGIS.

## Ouvrir une couche PostgreSQL dans QGIS

Trois solutions sont possibles:

* **utiliser l'explorateur** : seulement pour les tables spatiales, sauf si on a coché **Lister les tables sans géométries** dans les propriétés de la connexion. Le panneau présente un arbre qui liste les schémas, puis les tables ou vues exploitables.
* utiliser le menu **Couches / Ajouter une couche**. La boite de dialogue propose de se connecter, puis liste les schémas et les tables
* utiliser le **Gestionnaire de base de données**, qui présente une fenêtre QGIS séparée dédiée aux manipulations sur les données.

## Le Gestionnaire de base de données

On travaille via QGIS, avec le gestionnaire de bases de données : menu **Base de données > gestionnaire de base de données** (sinon via l'icône de la barre d’outil base de données).

Dans l'arbre qui se présente à gauche du gestionnaire de bdd, on peut **choisir sa connexion**, puis double-cliquer, ce qui montre l'ensemble des **schémas**, et l'ouverture d'un schéma montre la liste des tables et vues. Les menus du gestionnaire permettent de créer ou d'éditer des objets (schémas, tables).

Une **fenêtre SQL** permet de lancer manuellement des requêtes SQL. Nous allons principalement utiliser cet outil : menu **Base de données / fenêtre SQL** (on peut aussi le lancer via F2). :

### Création de tables

Depuis **QGIS**: dans le gestionnaire de base de données, menu table, créer une table:

* choisir le **schéma** et le **nom** de la table, en minuscule, sans accents ni caractères complexes
* Via le bouton **Ajouter un champ**, on commence par ajouter un champ **id** de type **serial** (entier auto-incrémenté), puis d'autres champs en choisissant le nom et le type. Choisir des noms de champ simples !
* Choisir dans la liste déroulante le **champ de clé primaire** (ici id)
* Cocher **Créer une colonne géométrique** et choisir le type et le SRID (par exemple 2154 pour le Lambert 93)
* Cocher **Créer un index spatial**

**NB**: on a créé une table dans cet exemple `z_formation.borne_incendie` avec les champs **id_borne** (text), **code** (text), **debit** (real) et **geom** (géométrie de type Point, code SRID 2154)

**Créer une table en SQL**

```sql
-- création d'un schéma
CREATE SCHEMA IF NOT EXISTS z_formation;

-- création de la table
CREATE TABLE z_formation.borne_incendie (
    -- un serial est un entier auto-incrémenté
    id_borne serial NOT NULL PRIMARY KEY,
    code text NOT NULL,
    debit real,
    geom geometry(Point, 2154)
);
-- Création de l'index spatial
CREATE INDEX ON z_formation.borne_incendie USING GIST (geom);

```

### Ajouter des données dans une table

On peut bien sûr charger la table dans QGIS, puis utiliser les outils d'édition classique pour créer des nouveaux objets.

En SQL, il est aussi possible d'insérer des données ( https://sql.sh/cours/insert-into ). Par exemple pour les bornes à incendie:


```sql
INSERT INTO z_formation.borne_incendie (code, debit, geom)
 VALUES
 ('ABC',  1.5, ST_SetSRID(ST_MakePoint(490846.0,6936902.7), 2154)),
 ('XYZ',  4.1, ST_SetSRID(ST_MakePoint(491284.9,6936551.6), 2154)),
 ('FGH',  2.9, ST_SetSRID(ST_MakePoint(490839.8,6937794.8), 2154)),
 ('IOP',  3.6, ST_SetSRID(ST_MakePoint(491203.3,6937488.1), 2154))
;
```

**NB**: Nous verrons plus loin l'utlisation de fonctions de création de géométrie, comme **ST_MakePoint**


## Création d’un schéma z_formation dans la base

* ajout du schéma via le gestionnaire de bdd, ou via une requête:

```sql
CREATE SCHEMA IF NOT EXISTS z_formation;
```

* modification des droits d’accès à ce schéma, si besoin:

```sql
-- On donne ici tous les droits à "utilisateur"
GRANT ALL PRIVILEGES ON SCHEMA z_formation TO "utilisateur";
```

* suppression d'un schéma

```sql
-- Suppression du schéma si il est vide
DROP SCHEMA monschema;

-- suppression du schéma et de toutes les tables de ce schéma (via CASCADE) !!! ATTENTION !!!
DROP SCHEMA monschema CASCADE;
```

* renommer un schéma

```sql
ALTER SCHEMA monschema RENAME TO unschema;
```

## Vérifier et créer les indexes spatiaux

On peut vérifier si chaque table contient un **index spatial** via le gestionnaire de base de données de QGIS, en cliquant sur la table dans l'arbre, puis en regardant les informations de l'onglet **Info**. On peut alors créer l'index spatial via le lien bleu **Aucun index spatial défini (en créer un)**.

Sinon, il est possible de le faire en SQL via la requête suivante:

```sql
CREATE INDEX ON nom_du_schema.nom_de_la_table USING GIST (geom);
```

Si on souhaite automatiser la création des indexes pour toutes les tables qui n'en ont pas, on peut utiliser une fonction, décrite dans la partie [Fonctions utiles](./utils.md)

Continuer vers l'[Import des données dans PostgreSQL](./import_data.md)
