## Rassembler des données de plusieurs tables

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
ORDER BY longueur DESC
;
```

Continuer vers [Enregistrer les requêtes: VIEW](./save_queries.md)
