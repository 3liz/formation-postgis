---
Title: Importer
Favicon: logo.svg
Sibling: yes
...

[TOC]

## Importer des données

Pour la formation, on doit importer des données pour pouvoir travailler. QGIS possède plusieurs outils pour réaliser cette importation dans PostgreSQL.

### Import d'une couche depuis QGIS

On  doit **charger au préalable la couche source** dans QGIS (SHP, TAB, etc.), puis on doit vérifier :

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

### Importer plusieurs couches en batch

Il est possible d'utiliser l'outil **Importer un vecteur vers une base de données PostGIS (connexions disponibles)** par lot. Pour cela, une fois la boîte de dialogue de cet algorithme ouverte, cliquer sur le bouton **Exécuter comme processus de lot**. Cela affiche un tableau, ou chaque ligne représente les variables d'entrée d'un algorithme.

Vous pouvez créer manuellement chaque ligne, ou choisir directement les couches depuis votre projet QGIS. Voir la documentation QGIS pour plus de détail:
https://docs.qgis.org/3.10/fr/docs/user_manual/processing/batch.html


Continuer vers [Sélectionner des données: SELECT](./sql_select.md)
