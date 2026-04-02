-- ============================================================
-- analysis.sql — Sweet Factory
-- Requêtes d'analyse pour extraire des informations utiles
-- ============================================================

-- ============================================================
-- 1. PRODUITS LES PLUS VENDUS
-- Utile pour décider quels produits mettre en avant,
-- réapprovisionner en priorité, ou proposer en promotion.
-- ============================================================
SELECT
    p.nom                           AS produit,
    p.categorie,
    SUM(lc.quantite)                AS total_vendu,
    ROUND(SUM(lc.quantite * lc.prix_unitaire * (1 - lc.remise_pct / 100.0)), 2) AS chiffre_affaires
FROM ligne_commande lc
JOIN produit p ON p.id = lc.produit_id
GROUP BY p.id, p.nom, p.categorie
ORDER BY total_vendu DESC;


-- ============================================================
-- 2. CLIENTS QUI ONT LE PLUS DÉPENSÉ
-- Permet d'identifier les clients les plus fidèles
-- pour leur proposer des offres personnalisées.
-- On utilise la vue commande_detail qui calcule déjà montant_ligne.
-- ============================================================
SELECT
    client,
    type_client,
    COUNT(DISTINCT commande_id)     AS nb_commandes,
    ROUND(SUM(montant_ligne), 2)    AS total_depense
FROM commande_detail
GROUP BY client, type_client
ORDER BY total_depense DESC
LIMIT 10;


-- ============================================================
-- 3. CHIFFRE D'AFFAIRES PAR MOIS
-- Permet de suivre l'évolution des ventes dans le temps
-- et d'identifier les pics saisonniers.
-- ============================================================
SELECT
    strftime('%Y-%m', c.date_commande)          AS mois,
    COUNT(DISTINCT c.id)                        AS nb_commandes,
    ROUND(SUM(lc.quantite * lc.prix_unitaire * (1 - lc.remise_pct / 100.0)), 2) AS chiffre_affaires
FROM commande c
JOIN ligne_commande lc ON lc.commande_id = c.id
WHERE c.statut != 'annulé'
GROUP BY mois
ORDER BY mois;


-- ============================================================
-- 4. INGRÉDIENTS EN ALERTE DE STOCK
-- Affiche les ingrédients dont le stock est en dessous
-- du seuil minimum — à réapprovisionner en urgence.
-- On utilise directement la vue stock_alerte.
-- ============================================================
SELECT
    ingredient,
    fournisseur,
    quantite_disponible,
    quantite_minimum,
    quantite_a_commander
FROM stock_alerte
ORDER BY quantite_a_commander DESC;


-- ============================================================
-- 5. COÛT DE FABRICATION PAR PRODUIT
-- Calcule le coût des ingrédients pour produire chaque produit
-- selon sa recette. Utile pour évaluer les marges.
-- ============================================================
SELECT
    p.nom                                           AS produit,
    p.prix_unitaire                                 AS prix_vente,
    ROUND(SUM(r.quantite * i.prix_unitaire), 2)     AS cout_fabrication,
    ROUND(p.prix_unitaire - SUM(r.quantite * i.prix_unitaire), 2) AS marge_estimee
FROM recette r
JOIN produit p      ON p.id = r.produit_id
JOIN ingredient i   ON i.id = r.ingredient_id
GROUP BY p.id, p.nom, p.prix_unitaire
ORDER BY marge_estimee DESC;


-- ============================================================
-- 6. RÉPARTITION DES COMMANDES PAR STATUT
-- Vue d'ensemble de l'état des commandes en cours.
-- Utile pour le suivi logistique quotidien.
-- ============================================================
SELECT
    statut,
    COUNT(*)                        AS nb_commandes,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM commande), 1) AS pourcentage
FROM commande
GROUP BY statut
ORDER BY nb_commandes DESC;


-- ============================================================
-- 7. COMPARAISON PARTICULIERS VS ENTREPRISES
-- Compare le comportement d'achat des deux types de clients :
-- volume de commandes, panier moyen, chiffre d'affaires total.
-- ============================================================
SELECT
    type_client,
    COUNT(DISTINCT commande_id)                     AS nb_commandes,
    ROUND(SUM(montant_ligne), 2)                    AS ca_total,
    ROUND(SUM(montant_ligne) / COUNT(DISTINCT commande_id), 2) AS panier_moyen
FROM commande_detail
GROUP BY type_client;


-- ============================================================
-- 8. ALERTES STOCK PRODUITS FINIS
-- Produits dont le stock disponible est en dessous du seuil minimum.
-- Indique qu'une nouvelle production doit être lancée.
-- ============================================================
SELECT
    p.nom                                               AS produit,
    p.categorie,
    sp.quantite_disponible,
    sp.quantite_minimum,
    (sp.quantite_minimum - sp.quantite_disponible)      AS unites_a_produire,
    sp.date_mise_a_jour
FROM stock_produit sp
JOIN produit p ON p.id = sp.produit_id
WHERE sp.quantite_disponible < sp.quantite_minimum
AND p.actif = 1
ORDER BY unites_a_produire DESC;


-- ============================================================
-- 9. VUE D'ENSEMBLE DES DEUX STOCKS
-- Compare pour chaque produit : le stock de produits finis disponibles
-- et le coût estimé des ingrédients nécessaires pour produire 100 unités.
-- Aide à prioriser la production selon les marges et les besoins.
-- ============================================================
SELECT
    p.nom                                               AS produit,
    sp.quantite_disponible                              AS stock_fini,
    sp.quantite_minimum                                 AS seuil_min,
    CASE WHEN sp.quantite_disponible < sp.quantite_minimum
         THEN '⚠ À produire' ELSE '✓ OK' END            AS statut_stock,
    ROUND(SUM(r.quantite * i.prix_unitaire) * 100, 2)  AS cout_100_unites
FROM stock_produit sp
JOIN produit p      ON p.id = sp.produit_id
LEFT JOIN recette r ON r.produit_id = p.id
LEFT JOIN ingredient i ON i.id = r.ingredient_id
WHERE p.actif = 1
GROUP BY p.id, p.nom, sp.quantite_disponible, sp.quantite_minimum
ORDER BY statut_stock DESC, cout_100_unites;


-- ============================================================
-- 8. CLIENTS FIDÈLES (HAVING)
-- Identifie les clients ayant passé au moins 3 commandes.
-- HAVING filtre sur le résultat du GROUP BY (après agrégation),
-- ce qu'un simple WHERE ne peut pas faire.
-- ============================================================
SELECT
    client,
    type_client,
    COUNT(DISTINCT commande_id)     AS nb_commandes,
    ROUND(SUM(montant_ligne), 2)    AS total_depense
FROM commande_detail
GROUP BY client, type_client
HAVING COUNT(DISTINCT commande_id) >= 3
ORDER BY nb_commandes DESC;
