# Sélectionner

Nous allons présenter des **requêtes SQL** de plus en plus complexes pour accéder aux données, et exploiter les capacités de PostgreSQL/PostGIS. Une requête est construite avec des instructions standardisées, appelées **clauses**

```sql
-- Ordre des clauses SQL
SELECT une_colonne, une_autre_colonne
FROM nom_du_schema.nom_de_la_table
(LEFT) JOIN autre_schema.autre_table
        ON critere_de_jointure
WHERE condition
GROUP BY champs_de_regroupement
ORDER BY champs_d_ordre
LIMIT 10

```
Récupérer tous les objets d'une table, et les valeurs pour toutes les colonnes

```sql
-- Sélectionner l'ensemble des données d'une couche: l'étoile veut dire "tous les champs de la table"
SELECT *
FROM z_formation.borne_incendie
;
```

Les 10 premiers objets

```sql
-- Sélectionner les 10 premières communes par ordre alphabétique
SELECT *
FROM z_formation.commune
ORDER BY nom
LIMIT 10
```

Les 10 premiers objets par ordre alphabétique

```sql
-- Sélectionner les 10 premières communes par ordre alphabétique descendant
SELECT *
FROM z_formation.commune
ORDER BY nom DESC
LIMIT 10
```

Les 10 premiers objets avec un ordre sur plusieurs champs

```sql
-- On peut utiliser plusieurs champs pour l'ordre
SELECT *
FROM z_formation.commune
ORDER BY depart, nom
LIMIT 10
```

Sélectionner seulement certains champs

```sql
-- Sélectionner seulement certains champs, et avec un ordre
SELECT id_commune, code_insee, nom
FROM z_formation.commune
ORDER BY nom
```

Donner un alias (un autre nom) aux champs

```sql
-- Donner des alias aux noms des colonnes
SELECT id_commune AS identifiant,
code_insee AS "code_commune",
nom
FROM z_formation.commune
ORDER BY nom
```

On peut donc facilement, à partir de la clause `SELECT`, choisir quels champs on souhaite récupérer, dans l'ordre voulu, et renommer le champ en sortie.


## Visualiser une requête dans QGIS

Si on veut charger le résultat de la requête dans QGIS, il suffit de cocher la case **Charger en tant que nouvelle couche** puis de choisir le champ d'**identifiant unique**, et si et seulement si c'est une couche spatiale, choisir le **champ de géométrie** .

Attention, si la table est non spatiale, il faut bien penser à décocher **Colonne de géométrie** !

Par exemple, pour afficher les communes avec leur information sommaire:

```sql
-- Ajouter la géométrie pour visualiser les données dans QGIS
SELECT id_commune AS identifiant,
code_insee AS "code_commune",
nom, geom
FROM z_formation.commune
ORDER BY nom
```

On choisira ici le champ **identifiant** comme identifiant unique, et le champ **geom** comme géométrie


Continuer vers [Réaliser des calculs et créer des géométries: FONCTIONS](./perform_calculation.md)
