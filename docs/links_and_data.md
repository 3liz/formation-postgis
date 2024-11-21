# Liens utiles

## Documentation

Documentation de PostgreSQL : https://docs.postgresql.fr/current/

Documentation des fonctions PostGIS:

* en anglais : https://postgis.net/docs/reference.html
* en français https://postgis.net/docs/postgis-fr.html notamment la référence des fonctions spatiales : https://postgis.net/docs/postgis-fr.html#reference

## Base de données

Nous présupposons qu'une **base de données** est accessible pour la formation, via un **rôle PostgreSQL** avec des droits élevés (notamment pour créer des schémas et des tables). L'extension **PostGIS** doit aussi être activée sur cette base de données.

## Jeux de données

Pour cette formation, nous utilisons des données libres de droit :

* Un dump est téléchargeable en cliquant sur ce [lien](https://github.com/3liz/formation-postgis/releases/download/1.0/data_formation.dump).

Il peut est chargé en base avec cette commande :
```bash
pg_restore -h URL_SERVEUR -p 5432 -U NOM_UTILISATEUR -d NOM_BASE --no-owner --no-acl data_formation.dump
```

Ce jeu de données a pour sources :

* Extraction de données d'**OpenStreetMap** dans un format SIG, sous licence "ODBL" (site https://github.com/igeofr/osm2igeo ). On utilisera par exemple les données de l'ancienne région Haute-Normandie.

* Données cadastrales (site https://cadastre.data.gouv.fr ), sous licence "Licence Ouverte 2.0" Par exemple pour la Seine-Maritime :
https://cadastre.data.gouv.fr/data/etalab-cadastre/2024-10-01/shp/departements/76/

* PLU (site https://www.geoportail-urbanisme.gouv.fr/map/ ). Par exemple les données de la ville du Havre. Cliquer sur la commune, et utiliser le lien de téléchargement.

Ces données peuvent aussi être importées dans la base de formation via les outils de QGIS.

## Concepts de base de données

Un rappel sur les concepts de table, champs, relations.

* Documentation de QGIS : https://docs.qgis.org/latest/fr/docs/training_manual/database_concepts/index.html


## Quelques extensions QGIS

[Lire la formation QGIS également](https://3liz.github.io/formation-qgis/extensions.html)

* **Autosaver** : sauvegarde automatique du projet QGIS toutes les N minutes
* **Layer Board** : liste l'ensemble des couches du projet et permet de modifier des caractéristiques pour plusieurs couches à la fois
* **Cadastre** : import et exploitation des données EDIGEO ET MAJIC dans PostgreSQL

Continuer vers [Gestion des données PostgreSQL dans QGIS](./postgresql_in_qgis.md)
