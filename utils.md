## Fonctions utiles

Nous regroupons ici quelques fonctions réalisées au cours de formations ou d'accompagnements d'utilisateurs de PostgreSQL.

### Création automatique d'indexes spatiaux

Pour des données spatiales volumineuses, les performances d'affichage sont bien meilleures à grande échelle si on a ajouté un **index spatial**. On peut le faire table par table, mais parfois on souhaite aussi automatiser cette création, c'est-à-dire créer les indexes spatiaux **pour toutes les tables qui n'en ont pas**.

Pour cela, nous avons conçu une fonction, téléchargeable ici: https://gist.github.com/mdouchin/cfa0e37058bcf102ed490bc59d762042

On doit copier/coller le script SQL de cette page "gist" dans la **fenêtre SQL** du Gestionnaire de bases de données de QGIS, puis lancer la requête avec **Exécuter**. On peut ensuite vider le contenu de la fenêtre, puis appeler la fonction `create_missing_spatial_indexes` via le code SQL suivant:

```sql
-- On lance avec le paramètre à True si on veut juste voir les tables qui n'ont pas d'index spatial
-- On lance avec False si on veut créer les indexes automatiquement

-- Vérification
SELECT * FROM create_missing_spatial_indexes(  True );

-- Création
SELECT * FROM create_missing_spatial_indexes(  False );
```

### Ajouter automatiquement plusieurs champs à plusieurs tables

Il est parfois nécessaire d'**ajouter des champs à une ou plusieurs tables**, par exemple pour y stocker ensuite des métadonnées (date de modification, date d'ajout, utilisateur, lien, etc).

Nous proposons pour cela la fonction `ajout_champs_dynamiques` qui permet de fournir un nom de schéma, un nom de table, et une chaîne de caractère contenant la liste séparée par virgule des champs et de leur type.

La fonction est accessible ici: https://gist.github.com/mdouchin/50234f1f33801aed6f4f2cbab9f4887c

* Exemple d'utilisation **pour une table** `commune` du schéma `test`: on ajoute les champs `date_creation`, `date_modification` et `utilisateur`

```sql
SELECT
ajout_champs_dynamiques('test', 'commune', 'date_creation timestamp DEFAULT now(), date_modification timestamp DEFAULT now(), utilisateur text')
;
```

* Exemple d'utilisation pour **toutes les tables d'un schéma**, ici le schéma `test`. On utilise dans cette exemple la vue `geometry_columns` qui liste les tables spatiales, car on souhaite aussi ne faire cet ajout que pour les données de type **POINT**

```sql
-- Lancer la création de champs sur toutes les tables
-- du schéma test
-- contenant des géométries de type Point
SELECT f_table_schema, f_table_name,
ajout_champs_dynamiques(
    -- schéma
    f_table_schema,
    -- table
    f_table_name,
    -- liste des champs, au format nom_du_champ TYPE
    'date_creation timestamp DEFAULT now(), date_modification timestamp DEFAULT now(), utilisateur text'
)
FROM geometry_columns
WHERE True
AND "type" LIKE '%POINT'
AND f_table_schema IN ('test')
ORDER BY f_table_schema, f_table_name
;
```
