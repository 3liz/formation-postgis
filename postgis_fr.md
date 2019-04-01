# Formation PostGIS

**Auteur**: 3liz
**Date**: mars 2019

## Liens utiles

Documentation de PostgreSQL : https://docs.postgresql.fr/9.6/

Documentation des fonctions PostGIS:

* en anglais : https://postgis.net/docs/reference.html
* en français https://postgis.net/docs/manual-2.4/postgis-fr.html notamment la référence des fonctions spatiales : https://postgis.net/docs/manual-2.4/postgis-fr.html#reference

Extraction de données d'OpenStreetMap dans un format SIG:

* https://github.com/igeofr/osm2igeo

Pour la plupart des requêtes présentées dans ce document, nous utilisons les données OpenStreetMap issues du jeu de données de Corse (actuellement téléchargeable à l'adresse : https://cloud.data-wax.com/index.php/s/myFFjcLzMFk9QB7/download?path=%2FFRANCE&files=201812_94_CORSE_SHP_L93_2154.zip )

## Concepts de base de données:

Un rappel sur les concepts de table, champs, relations.

* Documentation de QGIS : https://docs.qgis.org/2.18/fr/docs/training_manual/database_concepts/index.html


## Plugins utiles

* **Cadastre** : import et exploitation des données EDIGEO ET MAJIC dans PostgreSQL
* **Autosaver** : sauvegarde automatique du projet QGIS toutes les N minues
* **Layer Board** : liste l'ensemble des couches du projet et permet de modifier des caractéristiques pour plusieurs couches à la fois

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

### Gestionnaire de base de données

On travaille via QGIS, avec le gestionnaire de bases de données : menu **Base de données > gestionnaire de base de données** (sinon barre d’outil base de données).

NB: On pourrait aussi travailler avec PgAdmin 4, si on a besoin de réaliser des opérations de maintenance (gestion des droits, des utilisateurs, etc.)

Dans l'arbre qui se présente à gauche du gestionnaire de bdd, on peut **choisir sa connexion**, puis double-cliquer, ce qui montre l'ensemble des **schémas**. Les menus du gestionnaire permettent de créer ou d'éditer des objets (schémas, tables).

Une **fenêtre SQL** permet de lancer manuellement des requêtes SQL. Nous allons principalement utiliser cet outil : menu "Base de données > fenêtre SQL" (ou F2). :

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

## Importer des données

Pour la formation, on doit importer des données pour pouvoir travailler. On va faire cela avec différentes méthodes :

### Import d'une couche depuis QGIS

On  doit charger au préalable la couche dans QGIS, puis on doit vérifier :

* la **projection**, idéalement EPSG:2154 ou EPSG:3948
* l'**encodage** : UTF-8, ISO-8859-15 ? Il faut ouvrir la table attributaire, et vérifier si les accents sont bien affichés. Sinon choisir le bon encodage dans l'onglet **Général** des **propriétés de la couche**
* les **champs**: noms, type, contenu

Pour importer, on utilise le bouton d’import du gestionnaire de bdd. On choisit par exemple le fichier des communes:

* on clique sur **Mettre à jour les options**
* on choisit le **nom** de la couche et le schéma **z_formation**
* on coche bien les 2 cases du bas pour **convertir les champs en minuscule** (Convert fieldnames to lowercase) et pour **créer l'index spatial**

Après l'import, on peut cliquer, dans le panneau de gauche, sur le nom de la couche créée et parcourir les données avec l'onglet **Table**. Si on souhaite comparer avec la couche d'origine, il suffit de charger la table, en double-cliquant dessus dans l'arbre (ou via les autres outils de QGIS)

**NB**: si un champ s'appelle déjà id dans la donnée source, et qui contient des valeurs dupliquées, ou des valeurs textuelles, alors il faut cocher la case **Clé primaire** dans l'outil d'import, puis choisir un nom différent pour que QGIS crée ce nouvel identifiant dans le bon format (entier autoincrémenté via une séquence, qu'on appelle aussi serial). Par ex: id_commune

### Réimporter une donnée dans une table existante.

#### Avec suppression de la table puis recréation.

Il suffit d'utiliser le même **outil d'import** via le gestionnaire de bdd, et cocher la case **Remplacer la table de destination si existante**.

Attention, cela supprime la table avant de la recréer et de la remplir, ce qui peut entraîner des effets de bord (par exemple, on perd les droits définis)

#### Avec vidage puis ajout des nouvelles données

Imaginons qu'on ait donné tous les droits sur les tables du schéma, par exemple via cette requête

```sql
-- Ajout des droits un schéma et sur toutes les tables d'un schéma
GRANT ALL ON SCHEMA z_formation TO "unutilisateur";
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA z_formation TO "unutilisateur";
GRANT ALL ON SCHEMA z_formation TO "unepersonne";
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA z_formation TO "unepersonne";
```

Ensuite, on souhaite réimporter le SHP, **sans perdre les droits**: on doit d'abord **vider la table** puis **reimporter les données**, sans cocher la case *Remplacer la table de destination si existante*

```sql
-- Vider une table en remettant à zéro la séquence
-- qui permet d'autoincrémenter le champ id (la clé primaire)
TRUNCATE TABLE z_formation.commune RESTART IDENTITY;
```

Ensuite, on importe via l'outil spécifique du menu **Traitement / Boîte à outil**. Chercher "import" dans le champ du haut, et lancer l'algorithme **Importer un vecteur vers une base de données PostGIS (connexions disponibles)**. Il faut choisir les options suivantes:

* Choisir la bonne **connexion**, la couche en entrée, etc.
* choisir le **schéma**, par exemple z_formation
* choisir le **nom de la table**, par exemple commune
* laisser id dans le champ **Clef primaire** ou choisir le champ approprié
* décocher **Écraser la table existante**
* cocher **Ajouter à la table existante**
* laisser le reste par défaut.

Lancer l'algorithme, et vérifier une fois les données importées que les nouvelles données ont bien été ajoutées à la table.

## Les Requêtes SQL: lire, filtrer, croiser les données

Nous allons présenter des **requêtes SQL** de plus en plus complexes pour accéder aux données, et exploiter les capacités de PostgreSQL/PostGIS. Une requête est contruite avec des instructions standardisées, appelées **clauses**

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

### Sélectionner

Tous les objets d'une couche

```sql
-- Sélectionner l'ensemble des données d'une couche: l'étoire veut dire "tous les champs de la table"
SELECT *
FROM z_formation.commune
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

On peut donc facilement, à partir de la clause SELECT, choisir quels champs on souhaite récupérer, dans l'ordre qu'on veut, et renommer le champ en sortie.


### Visualiser une requête dans QGIS

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


### Faire des calculs

Le SQL permet de réaliser des calculs ou des modifications à partir de champs. On peut donc faire des calculs sur des nombres, ou des modifications (remplacement de texte, mise en majuscule, etc.)

Faire un calcul très simple, ave des opérateurs + - / et *, ainsi que des parenthèses

```sql
-- On multiplie 10 par 2
SELECT
10 * 2 AS vingt,
(2.5 -1) * 10 AS quinze
```

Il est aussi possible de faire des calculs à partir d'un ou plusieurs champs.

Nous souhaitons par exemple créer un champ qui contiendra la **population** des communes. Dans la donnée source, le champ **popul** est de type chaîne de caractère, car il contient parfois la valeur 'NC' lorsque la population n'est pas connue.

Nous ne pouvons pas faire de calculs à partir d'un champ texte. On souhaite donc **créer un nouveau champ** population pour y stoker les valeurs entières.

```sql
-- Ajout d'un champ de type entier dans la table
ALTER TABLE z_formation.commune ADD COLUMN population integer;
```

**Modifier** le nouveau champ population pour y mettre la valeur entière lorsqu'elle est connue. La modification d'une table se fait avec la requête **UPDATE**, en passant les champs à modifier et leur nouvelle valeur via **SET**

```sql
-- Mise à jour d'un champ à partir d'un calcul
UPDATE z_formation.commune SET population =
CASE
        WHEN popul != 'NC' THEN popul::integer
        ELSE NULL
END
;
```

Dans cette requête, le **CASE WHEN condition THEN valeur ELSE autre_valeur END** permet de faire un test sur la valeur d'origine, et de proposer une valeur si la condition est remplie ( https://sql.sh/cours/case )

Une fois ce champ **population** renseigné correctement, dans un type entier, on peut réaliser un calcul très simple, par exemple **doubler la population**:

```sql
-- Calcul simple : on peut utiliser les opérateurs mathématiques
SELECT id_commune, code_insee, nom, geom,
population,
population * 2 AS double_population
FROM z_formation.commune
LIMIT 10
```

Il est possible de **combiner plusieurs champs** pour réaliser un calcul. Nous verrons plus loin comment calculer la **densité de population** à partir de la population et de la surface des communes.

### Calculer des caractéristiques spatiales

Par exemple la **longueur** ou la **surface**

Calculer la longueur d'objets linéaires

```sql
-- Calcul des longueurs de route
SELECT id_route, id, nature,
ST_Length(geom) AS longueur_m
FROM z_formation.route
LIMIT 100
```

Calculer la **surface** de polygones, et utiliser ce résultat dans un calcul. Par exemple ici la **densité de population**:

```sql
-- Calculer des données à partir de champs et de fonctions spatiales
SELECT id_commune, code_insee, nom, geom,
population,
ST_Area(geom) AS surface,
population / ( ST_Area(geom) / 1000000 ) AS densite_hab_km
FROM z_formation.commune
LIMIT 10
```

### Créer des géométries à partir de géométries

On peut modifier les géométries avec des fonctions spatiales, ce qui revient à effectuer un calcul sur les géométries. Deux exemples classiques : **centroides** et **tampons**

Calculer le **centroïde** de polygones

```sql
-- Centroides des communes
SELECT id_commune, code_insee, nom,
ST_Centroid(geom) AS geom
FROM z_formation.commune
```

Forcer le **centroïde à l'intérieur du polygone**. Attention, ce calcul est plus long.

```sql
-- Centroides à l'intérieur des communes
-- Attention, c'est plus long à calculer
SELECT id_commune, code_insee, nom,
ST_PointOnSurface(geom) AS geom
FROM z_formation.commune
```

Calculer le **tampon** autour d'objets

```sql
-- Tampons de 10km autour des commues
SELECT id_commune, nom, population,
ST_Buffer(geom, 1000) AS geom
FROM z_formation.commune
LIMIT 10
```


### Valeurs distinctes d'un champ

On souaite récupérer **toutes les valeurs possibles** d'un champ

```sql
-- Vérifier les valeurs distinctes d'un champ: table commune
SELECT DISTINCT depart
FROM z_formation.commune
ORDER BY depart

-- idem sur la table lieu_dit_habite
SELECT DISTINCT nature
FROM z_formation.lieu_dit_habite
ORDER BY nature
```

Cela peut être par exemple utile pour **construire une table de nomenclature** à partir de données existantes. Dans l'exemple ci-dessous, on souhaite stocker la nomenclature de toutes les données dans une seule table.

On crée la table si besoin.

```
-- Suppression de la table
DROP TABLE IF EXISTS z_formation.nomenclature;
-- Création de la table
CREATE TABLE z_formation.nomenclature (
    id serial primary key,
    code text,
    libelle text,
    ordre smallint
);

```

On ajoute ensuite les données. La clause **WITH** permet de réaliser une sous-requête, et de l'utiliser ensuite comme une table. La clause **INSERT INTO** permet d'ajouter les données. On ne lui passe pas le champ id, car c'est un **serial**, c'est-à-dire un entier auto-incrémenté.

```sql
-- Ajout des données à partir d'une table via commande INSERT
INSERT INTO z_formation.nomenclature
(code, libelle, ordre)
-- Clause WITH pour récupérer les valeurs distinctes comme une table virtuelle
WITH source AS (
    SELECT DISTINCT
    nature AS libelle
    FROM z_formation.lieu_dit_habite
    WHERE nature IS NOT NULL
    ORDER BY nature
)
-- Sélection des données dans cette table virtuelle "source"
SELECT
-- on crée un code à partir de l'ordre d'arrive.
-- row_number() OVER() permet de récupérer l'identifiant de la ligne dans l'ordre d'arrivée
-- (un_champ)::text permet de convertir un champ ou un calcul en texte
-- lpad permet de compléter le chiffre avec des zéro. 1 devient 01
lpad( (row_number() OVER())::text, 2, '0' ) AS code,
libelle,
row_number() OVER() AS ordre
FROM source
;
```

Le résultat est le suivant:

| code | libelle         | ordre |
|------|-----------------|-------|
| 01   | Château         | 1     |
| 02   | Lieu-dit habité | 2     |
| 03   | Moulin          | 3     |
| 04   | Quartier        | 4     |
| 05   | Refuge          | 5     |
| 06   | Ruines          | 6     |


### Filtrer les données: la clause WHERE

Récupérer les données à partir de la **valeur exacte d'un champ**. Ici le nom de la commune

```sql
-- Récupérer seulement la commune de Bastia
SELECT id_commune, code_insee, nom,
population
FROM z_formation.commune
WHERE nom = 'Bastia'
```

On peut chercher les lignes dont le champ correspondant à **plusieurs valeurs**

```sql
-- Récupérer la commune de Bastia et d'Ajaccio
SELECT id_commune, code_insee, nom,
population
FROM z_formation.commune
WHERE nom IN ('Bastia', 'Ajaccio')
```

On peut aussi filtrer sur des champs de type **entier ou nombres réels**, et faire des conditions comme des inégalités.

```
-- Filtrer les données, par exemple par département et population
SELECT *
FROM z_formation.commune
WHERE True
AND depart = 'HAUTE-CORSE'
AND population > 1000
;
```

On peut chercher des lignes dont un champ **commence et/ou se termine** par un texte

```sql
-- Filtrer les données, par exemple par département et début de nom
SELECT *
FROM z_formation.commune
WHERE True
AND depart = 'CORSE-DU-SUD'
-- commence par C
-- AND nom LIKE 'C%'
-- se termine par na
AND nom ILIKE '%na'
;
```

On peut utiliser les **calculs sur les géométries** pour filtrer les données. Par exemple filtrer par longueur de lignes

```sql
-- Les routes qui font plus que 10km
-- on peut utiliser des fonctions dans la clause WHERE
SELECT id_route, id, geom
FROM z_formation.route
WHERE True
AND ST_Length(geom) > 10000
```

### Grouper des données et calculer des statistiques

Certains calculs nécessitent le regroupement de lignes, comme les moyennes, les sommes ou les totaux. Pour cela, il faut réaliser un **regroupement** via la clause **GROUP BY**

**Compter** les communes par département et calculer la **population totale**

```sql
-- Regrouper des données
-- Compter le nombre de communes par département
SELECT depart,
count(code_insee) AS nb_commune,
sum(population) AS total_population
FROM z_formation.commune
WHERE True
GROUP BY depart
ORDER BY nb_commune DESC
```

Calculer des **statistiques sur l'aire** des communes pour chaque département


```sql
SELECT depart,
count(id_commune) AS nb,
min(ST_Area(geom)/1000)::int AS min_aire_ha,
max(ST_Area(geom)/1000)::int AS max_aire_ha,
avg(ST_Area(geom)/1000)::int AS moy_aire_ha,
sum(ST_Area(geom)/1000)::int AS total_aire_ha
FROM z_formation.commune
GROUP BY depart
```

**Compter** le nombre de routes par nature

```sql
-- Compter le nombre de routes par nature
SELECT count(id_route) AS nb_route, nature
FROM z_formation.route
WHERE True
GROUP BY nature
ORDER BY nb_route DESC
```

Compter le nombre de routes par nature et par sens

```sql
SELECT count(id_route) AS nb_route, nature, sens
FROM z_formation.route
WHERE True
GROUP BY nature, sens
ORDER BY nature, sens DESC
```

Les caculs sur des ensembles groupés peuvent aussi être réalisé **sur les géométries.**. Le plus utilisé est **ST_Collect** qui regroupe les géométries dans une multi-géométrie.

Par exemple, on peut souhaiter trouver l'**enveloppe convexe** autour de points (élastique tendu autour d'un groupe de points). Ici, nous regroupons les lieux-dits par nature. Dans ce cas, il faut faire une sous-requête pour filtrer seulement les résultats de type polygone (car s'il y a seulement 1 ou 2 objets par nature, alors on ne peut créer de polygone)


```sql
SELECT *
FROM (
        SELECT
        nature,
        -- ST_Convexhull renvoit l'enveloppe convexe
        ST_Convexhull(ST_Collect(geom)) AS geom
        FROM z_formation.lieu_dit_habite
        GROUP BY nature
) AS source
-- GeometryType renvoit le type de géométrie
WHERE Geometrytype(geom) = 'POLYGON'
```

Attention, on doit donner un alias à la sous-requête (ici source)

### Rassembler des données de plusieurs tables

La clause **UNION** peut être utilisée pour regrouper les données de sources différentes dans une même table. Le **UNION ALL** fait la même choses, mais sans réaliser de dédoublonnement, ce qui est plus rapide.

**Rassembler les routes et les chemins** ensemble, en ajoutant un champ "nature" pour les différencier

```sql
-- Rassembler des données de tables différentes
-- On utilise une UNION ALL
SELECT 'chemin' AS nature, geom, round(st_length(geom))::integer AS longueur
FROM "z_formation".chemin
-- UNION ALL est placé entre 2 SELECT
UNION ALL
SELECT 'route' AS nature, geom, round(st_length(geom))::integer AS longueur
FROM "z_formation".route
-- Le ORDER BY doit être réalisé à la fin, et non sur chaque SELECT
ORDER BY longueur
```

Si on doit réaliser le même calcul sur chaque sous-ensemble (chaque SELECT), on peut le faire en 2 étapes via une sous-requête (ou une clause WITH)

```sql
SELECT
-- on récupère tous les champs
source.*,
-- on calcule la longueur après rassemblement des données
st_length(geom) AS longueur
FROM (
        SELECT id, geom
        FROM z_formation.chemin
        UNION ALL
        SELECT id, geom
        FROM z_formation.route
) AS source
ORDER BY longueur
;
```

### Enregistrer une requête : les vues

Une vue est l'enregistrement d'une requête, appelée **définition de la vue**, qui est stocké dans la base, et peut être **utilisée comme une table**.

Créer une vue via **CREATE VIEW**

```sql
-- Créer une vue pour stocker la requête et pouvoir l'utiliser comme une table
-- (mais avec des données dynamiques)
DROP VIEW IF EXISTS "z_formation".v_voies;
CREATE VIEW "z_formation".v_voies AS
SELECT
-- on récupère tous les champs
source.*,
-- on calcule la longueur après rassemblement des données
st_length(geom) AS longueur
FROM (
        SELECT id, geom
        FROM z_formation.chemin
        UNION ALL
        SELECT id, geom
        FROM z_formation.route
) AS source
ORDER BY longueur
;
```

Utiliser cette vue dans une autre requête

* pour faire des statistiques

```sql
-- On peut ensuite utiliser cette vue pour faire des stats
SELECT source, count(*) AS nb, sum(longueur) AS longueur_totale
FROM "z_formation".v_voies
GROUP BY source
```

* pour filtrer les données

```sql
-- Ou filtrer les données
SELECT * FROM z_formation.v_voies
WHERE longueur < 10
```

### Enregistrer une requête comme une table

C'est la même chose que pour enregistrer une vue, sauf qu'on crée une table: les données sont donc stockées en base, et n'évoluent plus en fonction des données source.

Cela permet d'accéder rapidement aux données, car la requête sous-jacente n'est plus exécutée une fois la table créée.

Créer la table des voies

```sql
DROP TABLE IF EXISTS "z_formation".t_voies;
CREATE TABLE "z_formation".t_voies AS
SELECT
-- on récupère tous les champs
source.*,
-- on calcule la longueur après rassemblement des données
st_length(geom) AS longueur
FROM (
        SELECT id, geom
        FROM z_formation.chemin
        UNION ALL
        SELECT id, geom
        FROM z_formation.route
) AS source
ORDER BY longueur
;
```

Comme c'est une table, il est intéressant d'ajouter un indexe spatial.

```sql
CREATE INDEX ON z_formation.t_voies USING GIST (geom);
```

On peut aussi ajouter une clé primaire

```sql
ALTER TABLE z_formation.t_voies ADD COLUMN gid serial;
ALTER TABLE z_formation.t_voies ADD PRIMARY KEY (gid);
```

**Attention** Les données de la table n'évoluent plus en fonction des données des tables source. Il faut donc supprimer la table puis la recréer si besoin. Pour répondre à ce besoin, il existe les **vues matérialisées**.

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


### Les jointures

Les jointures permettent de récupérer des données en relation les unes par rapport aux autres.

#### Les jointures attributaires

La condition de jointure est faite sur des champs non géométriques. Par exemple une égalité (code, identifiant).

Récupération des informations de la commune pour chaque zonage

```sql
-- Jointure attributaire: récupération du nom de la commune pour chacun des zonages
SELECT z.*, c.libcom
FROM urbanisme.zonage AS z
JOIN urbanisme.commune AS c ON z.insee = c.ccocom
-- IMPORTANT: ne pas oublier le ON cad le critère de jointure,
-- sous peine de "produit cartésien" (calcul couteux de tous les possibles)
;
```

Il est souvent intéressant, pour des données volumineuses, de **créer un index sur le champ de jointure** (par exemple ici sur les champs insee et ccocom.

#### Les jointures spatiales

Le critère de jointure peut être une **condition spatiale**. On réalise souvent une jointure par **intersection** ou par **proximité**.

Récupérer le code commune de chaque chemin, par **intersection entre le chemin et la commune**.

```sql
-- Ici, on peut récupérer plusieurs fois le même chemin
-- s'il passe par plusieurs communes
SELECT
v.*,
c.nom, c.code_insee
FROM "z_formation".chemin AS v
JOIN "z_formation".commune AS c
        ON ST_Intersects(v.geom, c.geom)
ORDER BY id_chemin, nom
```

On peut utiliser le **centroide de chaque chemin** pour avoir un seul objet par chemin comme résultat.

```sql
-- Jointure spatiale
-- On ne veut qu'une seule ligne par toponyme
-- Donc on fait l'intersection entre chaque toponyme et les communes
SELECT
v.*,
c.nom, c.code_insee
FROM "z_formation".chemin AS v
JOIN "z_formation".commune AS c
        ON ST_Intersects(ST_Centroid(v.geom), c.geom)
```

A l'inverse, on peut vouloir faire des **statistiques pour chaque commune** via jointure spatiale. Par exemple le nombre de chemin et le total des longueurs par commune.

```sql
 -- A l'inverse, on veut récupérer des statistiques par commune
 -- On veut une ligne par commune, avec des données sur les voies
SELECT
c.id_commune, c.nom, c.code_insee,
count(v.id_chemin) AS nb_chemin,
sum(st_length(v.geom)) AS somme_longueur_chemins_entiers
FROM z_formation.commune AS c
JOIN z_formation.chemin AS v
        ON st_intersects(c.geom, st_centroid(v.geom))
GROUP BY c.id_commune, c.nom, c.code_insee
;
```

La requête précédente ne renvoit pas de lignes pour les communes qui n'ont pas de chemin dont le centroide est dans une commune. C'est une jointure de type **INNER JOIN**

Si on veut quand même récupérer ces communes, on fait une jointure **LEFT JOIN**

```sql
SELECT
c.id_commune, c.nom, c.code_insee,
count(v.id_chemin) AS nb_chemin,
sum(st_length(v.geom)) AS somme_longueur_chemins_entiers
FROM z_formation.commune AS c
LEFT JOIN z_formation.chemin AS v
        ON st_intersects(c.geom, st_centroid(v.geom))
GROUP BY c.id_commune, c.nom, c.code_insee
;
```

Dans la requête précédente, on calculait la longueur totale de chaque chemin, pas le **morceau exacte qui est sur chaque commune**. On peut le faire (mais c'est plus long: j'ai donc ici simplifié les géométries des communes pour accélérer le calcul):

```sql
SELECT
c.id_commune, c.nom, c.code_insee,
count(v.id_chemin) AS nb_chemin,
sum(st_length(
        ST_Intersection(v.geom,ST_MakeValid(st_simplify(c.geom,100)))
)) AS somme_longueur_chemins_decoupe_par_commune
FROM z_formation.commune AS c
LEFT JOIN z_formation.chemin AS v
        ON st_intersects(c.geom, st_centroid(v.geom))
GROUP BY c.id_commune, c.nom, c.code_insee
```

**NB**: Attention à ne pas confondre **ST_Intersects** qui renvoit vrai ou faux, et **ST_Intersection** qui renvoit la géométrie issue du découpage d'une géométrie par une autre.

On peut bien sûr réaliser des **jointures spatiales** entre 2 couches de **polygones**, et découper les polygones par intersection.

Trouver l'ensemble des zonages PLU pour les parcelles d'une commune

```sql
-- Jointure spatiale
-- Découper les zonages par parcelle
-- pour calculer le pourcentage de chaque type de zonage sur chaque parcelle
-- On peut donc avoir plusieurs résultats par parcelle (si elle a plusieurs zones), ou aucune
-- On peut aussi avoir des erreurs de petits morceaux ou de parcelle couverte à 99,99% pour des soucis de géométries
SELECT
p.idpar,
z.libelle, z.libelong, z.typezone
FROM urbanisme.parcelle AS p
JOIN urbanisme.zonage AS z ON st_intersects(z.geom, p.geom)
WHERE True
ORDER BY p.idpar

```

Compter pour chaque parcelle le nombre de zonage en intersection: on veut une seule ligne par parcelle

```sql
SELECT
p.idpar,
count(z.libelle) AS nombre_zonage
FROM urbanisme.parcelle AS p
JOIN urbanisme.zonage AS z ON st_intersects(z.geom, p.geom)
WHERE True
GROUP BY p.idpar
ORDER BY nombre_zonage DESC
```

Découper les parcelles par les zonages, et pouvoir calculer les surfaces des zonages, et le pourcentage par rapport à la surface de chaque parcelle. On essaye le SQL suivant


```sql
SELECT
p.idpar,
z.libelle, z.libelong, z.typezone,
-- découper les géométries
st_intersection(z.geom, p.geom) AS geom
FROM urbanisme.parcelle AS p
JOIN urbanisme.zonage AS z ON st_intersects(z.geom, p.geom)
WHERE True
ORDER BY p.idpar
```

Il renvoit l'erreur

```
ERREUR:  Error performing intersection: TopologyException: Input geom 0 is invalid: Self-intersection at or near point 710908.28634840855 7046791.8007033626 at 710908.28634840855 7046791.8007033626
```

On a des soucis de validité de géométrie. Il nous faut donc corriger les géométries avant de poursuivre. Voir chapitre sur la validation des géométries.

Une fois les géométries validées, la requête fonctionne. On l'utilise dans une sous-requête pour créer une table et calculer les surfaces

```sql
-- suppression de la table
DROP TABLE IF EXISTS urbanisme.decoupe_zonage_parcelle;
-- création de la table avec calcul de pourcentage de surface
CREATE TABLE urbanisme.decoupe_zonage_parcelle AS
SELECT row_number() OVER() AS id,
source.*,
ST_Area(geom) AS aire,
100 * ST_Area(geom) / aire_parcelle AS pourcentage
FROM (
SELECT
        p.id_parcelle, p.idpar, ST_Area(p.geom) AS aire_parcelle,
        z.id_zonage, z.libelle, z.libelong, z.typezone,
        -- découper les géométries
        (ST_Multi(st_intersection(z.geom, p.geom)))::geometry(MultiPolygon,2154) AS geom
        FROM urbanisme.parcelle AS p
        JOIN urbanisme.zonage AS z ON st_intersects(z.geom, p.geom)
        WHERE True
) AS source;

-- Ajout de la clé primaire
ALTER TABLE urbanisme.decoupe_zonage_parcelle ADD PRIMARY KEY (id);

-- Ajout de l'index spatial
CREATE INDEX ON urbanisme.decoupe_zonage_parcelle USING GIST (geom);

```



### Distances et tampons entre couches

Pour chaque objets d'une table, on souhaite récupéerer des informations sur les** objets proches d'une autre table**. Au lieu d'utiliser un tampon puis une intersection, on utilise la fonction **ST_DWithin**

On prend comme exemple la table des bornes à incendie créée précédememnt (remplie avec quelques données de test).

Trouver toutes les parcelles **à moins de 200m** d'une borne à incendie

```sql
SELECT
p.id_parcelle, p.idpar, p.geom,
b.id_borne, b.code,
ST_Distance(b.geom, p.geom) AS distance
FROM urbanisme.parcelle AS p
JOIN urbanisme.borne_incendie AS b
        ON ST_DWithin(p.geom, b.geom, 200)
ORDER BY id_parcelle, id_borne
```

Attention, elle peut renvoyer **plusieurs fois la même parcelle** si 2 bornes sont assez proches. Pour ne récupérer que la borne la plus proche, on peut faire la requête suivante. La clause **DISTINCT ON** permet de dire quel champ doit être **unique** (ici id_parcelle).

On **ordonne** ensuite **par ce champ et par la distance** pour prendre seulement la ligne correspondant à la parcelle **la plus proche**

```sql
SELECT DISTINCT ON (p.id_parcelle)
p.id_parcelle, p.idpar, p.geom,
b.id_borne, b.code,
ST_Distance(b.geom, p.geom) AS distance
FROM urbanisme.parcelle AS p
JOIN urbanisme.borne_incendie AS b
        ON ST_DWithin(p.geom, b.geom, 200)
ORDER BY id_parcelle, distance
```

### Fusionner des géométries

On souhaite créer une seule géométrie qui est issue de la **fusion de toutes les géométries** regroupées par un critère (nature, code, etc.)

Par exemple un polygone fusionnant les zonages qui partagent le même type

```sql
SELECT count(id_zonage) AS nb_objets, typezone,
ST_Union(geom) AS geom
FROM urbanisme.zonage
GROUP BY typezone
```

On souhaite parfois **fusionner toutes les géométries qui sont jointives**.
Par exemple, on veut fusionner **toutes les parcelles jointives** pour créer des blocs.

```sql
SELECT row_number() OVER() AS id, string_agg(idpar::text, ',') AS ids, t.geom
FROM (
        SELECT
        (St_Dump(St_Union(a.geom))).geom AS geom
        FROM urbanisme.parcelle AS a
        WHERE TRUE
        AND ST_IsValid(a.geom)
) t
INNER JOIN urbanisme.parcelle AS p
        ON ST_Intersects(p.geom, t.geom)
GROUP BY t.geom
;
```

### Correction des géométries

Avec PostgreSQL on peut **tester la validité des géométries** d'une table, comprendre la raison et localiser les soucis de validité:


```sql
SELECT
id_parcelle,
-- vérifier si la géom est valide
ST_IsValid(geom) AS validite_geom,
-- connaitre la raison d'invalidité
st_isvalidreason(geom) AS validite_raison,
-- sortir un point qui localise le souci de validité
location(st_isvaliddetail(geom)) AS point_invalide
FROM urbanisme.parcelle
WHERE ST_IsValid(geom) IS FALSE
```

PostGIS fournir l'outil **ST_MakeValid** pour corriger automatiquement les géométries invalides. On peut l'utiliser pour les lignes et polygones.

Attention, pour les polygones, cela peut conduire à des géométries de type différent (par exemple une polygone à 2 noeuds devient une ligne). On utilise donc aussi la fonction **ST_CollectionExtract** pour ne récupérer que les polygones.

```sql
-- Corriger les géométries
UPDATE urbanisme.parcelle
SET geom = ST_Multi(ST_CollectionExtract(ST_MakeValid(geom), 3))
WHERE NOT ST_isvalid(geom)

-- Tester
SELECT *
FROM urbanisme.parcelle
WHERE NOT ST_isvalid(geom)
```

### Vérifier la topologie

#### Déplacer les noeuds sur une grille

Avant de vérifier la topologie, il faut au préalable avoir des géométries valides (cf. chapitre précédent).

Certaines micro-erreurs de topologie peuvent peuvent être corrigées en réalisant une simplification des données à l'aide d'une grille, par exemple pour corriger des soucis d'arrondis. Pour cela, PostGIS a une fonction **ST_SnapToGrid**.

On peut utiliser conjointement **ST_Simplify* et **ST_SnapToGrid** pour effectuer une première correction sur les données. Attention, ces fonctions modifient la donnée. A vous de choisir la bonne tolérance, par exemple 5 cm, qui dépend de votre donnée et de votre cas d'utilisation.

Tester la simplification:

```sql
SELECT
ST_SnapToGrid(
    ST_Multi(
        ST_CollectionExtract(
            ST_MakeValid(
                st_simplify(geom,0)
            ),
            3
        )
    ),
    0.05 -- 5 cm
)
FROM urbanisme.plui_parcelles
;
```

Modifier la table avec la version simplifiée des données

```sql
-- Parcelles
UPDATE urbanisme.plui_parcelles
SET geom = ST_SnapToGrid(
    ST_Multi(
        ST_CollectionExtract(
            ST_MakeValid(
                st_simplify(geom,0)
            ),
            3
        )
    ),
    0.05 -- 5 cm
)
;
```

**Attention:** Si vous avez d'autres tables avec des objets en relation spatiale avec cette table, il faut aussi effectuer le même traitement pour que les géométries de toutes les couches se calent sur la même grille.


#### Repérer certaines erreurs de topologies

PostGIS possède de nombreuses fonctions de **relations spatiales* qui permettent de trouver les objets qui se chevauchent, qui se touchent, etc. Ces fonctions peuvent être utilisées pour comparer les objets d'une même table, ou de deux tables différentes. Voir: https://postgis.net/docs/reference.html#Spatial_Relationships_Measurements

Par exemple, trouver les parcelles voisines qui se recouvrent: on utilise la fonction **ST_Overlaps**. On peut créer une couche listant les recouvrements:


```sql
DROP TABLE IF EXISTS urbanisme.recouvrement_parcelle_voisines;
CREATE TABLE urbanisme.recouvrement_parcelle_voisines AS
SELECT DISTINCT ON (geom)
parcelle_a, parcelle_b, aire_a, aire_b, ST_Area(geom) AS aire, geom
FROM (
        SELECT
        a.gid AS parcelle_a, ST_Area(a.geom) AS aire_a,
        b.gid AS parcelle_b, ST_Area(a.geom) AS aire_b,
        (ST_Multi(
                st_collectionextract(
                        ST_MakeValid(ST_Intersection(a.geom, b.geom))
                        , 3)
        ))::geometry(MultiPolygon,2154) AS geom
        FROM urbanisme.plui_parcelles AS a
        JOIN urbanisme.plui_parcelles AS b
                ON a.gid != b.gid
                --ON ST_Intersects(a.geom, b.geom)
                AND ST_Overlaps(a.geom, b.geom)
) AS voisin
ORDER BY geom
;

```

Récupérer la liste des identifiants de ces parcelles:

```sql
SELECT string_agg( parcelle_a::text, ',') FROM urbanisme.recouvrement_parcelle_voisines;
```

On peut utiliser le résultat de cette requête pour sélectionner les parcelles problématiques: on sélectionne le résultat dans le tableau du gestionnaire de base de données, et on copie (CTRL + C). On peut utiliser cette liste dans une **sélection par expression** dans QGIS, avec par exemple l'expression ```"gid" IN (1,2,3,4)```

Une fois les parcelles sélectionnées, on peut utiliser certains outils pour faciliter la correction:

* plugin **Vérifier les géométries** en cochant la case **Uniquement les entités sélectionnées**
* plugin **Accrochage de géométrie**
* etc.


### Accrocher les géométries sur d'autres géométries

Dans PostGIS, on peut utiliser la fonction **ST_Snap** dans une requête SQL pour déplacer les noeuds d'une géométrie et les coller sur ceux d'une autre.

Par exemple, coller les géométries choisies (via identifiants dans le WHERE) de la table de zonage sur les parcelles choisies (via identifiants dans le WHERE):

```sql
WITH a AS (
    SELECT DISTINCT z.id,
    ST_Force2d(
        ST_Multi(
            ST_Snap(
                z.geom,
                ST_Collect(p.geom),
                0.5
            )
        )
    ) AS geom
    FROM urbanisme.plui_parcelles AS p
    INNER JOIN urbanisme.plui_zonage AS z
    ON ST_Dwithin(z.geom, p.geom, 0.6)
    WHERE TRUE
    AND z.id IN (225, 1851)
    AND p.gid IN (11141, 11178)
    GROUP BY z.id
)
UPDATE urbanisme.plui_zonage pz
SET geom = a.geom
FROM a
WHERE pz.id = a.id
```

**Attention:** Cette fonction ne sait coller qu'**aux noeuds** de la table de référence, pas aux segments. Il serait néanmoins possible de créer automatiquement les noeuds situés sur la projection du noeud à déplacer sur la géométrie de référence.

Dans la pratique, il est très souvent fastidieux de corriger les erreurs de topologie d'une couche. Les outils automatiques ( Vérifier les géométries de QGIS ou outil v.clean de Grass) ne permettent pas toujours de bien voir ce qui a été modifié.

Au contraire, une modification manuelle est plus précise, mais prend beaucoup de temps. 

La documentation suivante, 
