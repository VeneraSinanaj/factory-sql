# Sweet Factory — Base de données SQL

Projet final — M1 DS2E
**Venera SINANAJ** & **Chimène NOUICER**

---

## Contexte

Sweet Factory est une confiserie française qui vend des chocolats, bonbons et biscuits à des particuliers et à des entreprises (épiceries fines, restaurants, revendeurs).

Ce projet modélise le système de gestion interne de la confiserie : clients, commandes, catalogue produits, recettes de fabrication, suivi des stocks d'ingrédients et stock des produits finis.

## Utilisateurs cibles

- **Gestionnaire des commandes** — suivi des commandes en cours, modification des statuts, gestion des clients
- **Responsable des stocks** — surveillance des niveaux d'ingrédients et de produits finis, alertes de réapprovisionnement et de production
- **Direction** — analyse des ventes, chiffre d'affaires mensuel, produits les plus vendus

## Sources de données

Toutes les données ont été générées avec Claude (Anthropic) — elles sont fictives mais réalistes. Aucune donnée réelle n'a été utilisée.

---

## Structure du projet

```
sweetfactory/
├── schema.sql          # Création des tables, index et vues
├── seed.sql            # Données de test (INSERT)
├── queries.sql         # Requêtes de manipulation quotidienne
├── analysis.sql        # Requêtes d'analyse et statistiques
├── DESIGN.md           # Conception, diagramme ER et choix techniques
├── design.png          # Diagramme entité-relation
├── simulation.html     # Simulation interactive d'une commande
├── dashboard.pbix      # Tableau de bord Power BI
├── dashboard.pdf       # Export PDF du tableau de bord
├── report.py           # Script Python : export CSV (CA, ventes, stocks)
├── alert_stock.py      # Script Python : rapport HTML d'alerte stock (ingrédients + produits finis)
├── requirements.txt    # Dépendances Python
└── exports/            # Fichiers générés par les scripts Python
```

---

## Moteur de base de données

SQLite — fichier `sweetfactory.db` à créer via `schema.sql` puis `seed.sql`.

---

## Lancer la base de données

1. Ouvrir [DB Browser for SQLite](https://sqlitebrowser.org/)
2. Créer une nouvelle base → exécuter `schema.sql`
3. Exécuter `seed.sql` pour charger les données

---

## Scripts Python

### Prérequis

```bash
pip install -r requirements.txt
```

### `report.py` — Rapport mensuel CSV

Génère trois fichiers CSV dans le dossier `exports/` :
- Chiffre d'affaires par mois
- Produits les plus vendus
- État complet des stocks (ingrédients + produits finis)

```bash
python report.py
```

### `alert_stock.py` — Alerte stock HTML

Vérifie les deux niveaux de stock :
- **Ingrédients** en dessous du seuil minimum (à réapprovisionner)
- **Produits finis** en dessous du seuil minimum (à produire)

Génère un rapport HTML dans `exports/` et l'ouvre automatiquement dans le navigateur.

```bash
python alert_stock.py
```

---

## Tableau de bord Power BI

Le fichier `dashboard.pbix` contient plusieurs visuels :
- Chiffre d'affaires mensuel (courbe)
- Produits les plus vendus (barres)
- Répartition des commandes par statut (camembert)
- Alertes stock ingrédients avec mise en forme conditionnelle (tableau)
- Alertes stock produits finis (tableau)

Pour l'ouvrir, installer [Power BI Desktop](https://powerbi.microsoft.com/fr-fr/desktop/) (gratuit).

---

## Simulation interactive

Le fichier `simulation.html` est une page web interactive qui illustre le cycle complet d'une commande étape par étape, en montrant quelles tables sont affectées à chaque action.

Ouvrir directement dans un navigateur — aucune installation requise.
