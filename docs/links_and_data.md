# Liens utiles

## Documentation

Documentation de PostgreSQL : https://docs.postgresql.fr/current/

Documentation des fonctions PostGIS:

* en anglais : https://postgis.net/docs/reference.html
* en français https://postgis.net/docs/manual-2.4/postgis-fr.html notamment la référence des fonctions spatiales : https://postgis.net/docs/manual-2.4/postgis-fr.html#reference

## Base de données

Nous présupposons qu'une **base de données** est accessible pour la formation, via un utilisateur PostgreSQL avec des droits élevés (notamment pour créer des schémas et des tables). L'extension **PostGIS** doit aussi être activée sur cette base de données.

## Jeux de données

Pour cette formation, nous utilisons des données libres de droit:

* Un zip est téléchargable en cliquant sur ce [lien](https://drive.google.com/file/d/1a2JgGRleE4OTMGAUFPkgkMJAaoOLBArL/view?usp=sharing).

Ce jeu de données a pour sources :

* Extraction de données d'**OpenStreetMap** dans un format SIG, sous licence ODBL ( site https://github.com/igeofr/osm2igeo ). On utilisera par exemple les données de l'ancienne région Haute-Normandie:
https://www.data.data-wax.com/OSM2IGEO/FRANCE/202103_OSM2IGEO_23_HAUTE_NORMANDIE_SHP_L93_2154.zip

* Données cadastrales (site https://cadastre.data.gouv.fr ), sous licence  Par exemple pour la Seine-Maritime:
https://cadastre.data.gouv.fr/data/etalab-cadastre/2019-01-01/shp/departements/76/

* PLU (site https://www.geoportail-z_formation.gouv.fr/map/ ). Par exemple les données de la ville du Havre:
https://www.geoportail-z_formation.gouv.fr/map/#tile=1&lon=0.13496041707835396&lat=49.49246433172931&zoom=12&mlon=0.117760&mlat=49.502918
Cliquer sur la commune, et utiliser le lien de téléchargement, actuellement:

Ces données seront importées dans la base de formation via les outils de QGIS.

## Concepts de base de données:

Un rappel sur les concepts de table, champs, relations.

* Documentation de QGIS : https://docs.qgis.org/latest/fr/docs/training_manual/database_concepts/index.html


## Quelques extensions QGIS

[Lire la formation QGIS également](https://3liz.github.io/formation-qgis/extensions.html)

* **Autosaver** : sauvegarde automatique du projet QGIS toutes les N minutes
* **Layer Board** : liste l'ensemble des couches du projet et permet de modifier des caractéristiques pour plusieurs couches à la fois
* **Cadastre** : import et exploitation des données EDIGEO ET MAJIC dans PostgreSQL

Continuer vers [Gestion des données PostgreSQL dans QGIS](./postgresql_in_qgis.md)
