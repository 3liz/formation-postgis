## Filtrer les données: la clause WHERE

Récupérer les données à partir de la **valeur exacte d'un champ**. Ici le nom de la commune

```sql
-- Récupérer seulement la commune de Bastia
SELECT id_commune, code_insee, nom,
population
FROM z_formation.commune
WHERE nom = 'Le Havre'
```

On peut chercher les lignes dont le champ correspondant à **plusieurs valeurs**

```sql
-- Récupérer la commune de Bastia et d'Ajaccio
SELECT id_commune, code_insee, nom,
population
FROM z_formation.commune
WHERE nom IN ('Le Havre', 'Rouen')
```

On peut aussi filtrer sur des champs de type **entier ou nombres réels**, et faire des conditions comme des inégalités.

```sql
-- Filtrer les données, par exemple par département et population
SELECT *
FROM z_formation.commune
WHERE True
AND depart = 'SEINE-MARITIME'
AND population > 1000
;
```

On peut chercher des lignes dont un champ **commence et/ou se termine** par un texte

```sql
-- Filtrer les données, par exemple par département et début et/ou fin de nom
SELECT *
FROM z_formation.commune
WHERE True
AND depart = 'SEINE-MARITIME'
-- commence par C
AND nom LIKE 'C%'
-- se termine par ville
AND nom ILIKE '%ville'
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

Continuer vers [Regrouper des données: GROUP BY](./group_data.md)
