# Synthesia

# Table des matières
- [Description](#description)
  - [Objectif](#objectif)
  - [Définitions](#définitions)
- [Composition de l'interface](#composition-de-linterface)
- [Fonctionnalités](#fonctionnalités)
    - [Interactions du clavier](#interactions-du-clavier)
    - [Fonctionnement de la partie cascade](#fonctionnement-de-la-partie-cascade)
    - [Fonctions des boutons](#fonctions-des-boutons)
        - [Effacer](#effacer)
        - [Sauvegarder](#sauvegarder)
        - [Sauvegarder dans un fichier](#sauvegarder-dans-un-fichier)
        - [Mode "Accord"](#mode-accord)
        - [Silence](#silence)
        - [Supprimer un silence](#supprimer-un-silence)
        - [Hauteur par défaut](#hauteur-par-défaut)
        - [Importer](#importer)
        - [Bpm](#bpm)
        - [Jouer la musique](#jouer-la-musique)



# Description

## Objectif
Interface de clavier de piano à 88 touches permettant de créer ses propries cascades de tuile note à note afin de les rejouer pour s'entrainer.

## Définitions
_Tuile_ : désigne un rectangle créé après un clic sur une touche.\
_Session_ : liste des notes créées pendant une session ou depuis la dernière suppression totale.\
_Hauteur_ : longueur (y) du rectangle créé après un clic sur une touche


# Composition de l'interface
- **Format** : paysage 16/9
- **3/9 du bas de l'écran** : 88 touches d'un piano (blanches et noires avec noires plus fine et décalées en hauteur) (partie "clavier")
- **5/9 dessus** : fond noir avec barre fine grise séparant les octaves sur toute la hauteur (partie "cascade")
- **1/9 du haut** : boutons d'interactions avec les notes (partie "interactions")

# Fonctionnalités


## Interactions du clavier
- Chaque touche peut être cliquée.
- Un clic créé un rectangle aligné sur l'axe des abscisses avec la note correspondante


## Fonctionnement de la partie cascade


**Une tuile :**
+ La tuile créée a la même largeur que la touche correspondante
  + Sa longueur est défini par [un input sur la partie interaction](#hauteur-par-défaut)
+ La tuile est cliquable
  + Un clic ouvre une interface permettant de modifier la durée (aussi appelée "hauteur"), la couleur, ou de la supprimer
+ Les couleurs par défaut des tuiles sont :
  + Vert clair pour une touche blanche
  + Bleu pour une touche noire

**La cascade :**
+ La tuile est créée collée au clavier
  + Les tuiles déjà existantes remontent de la hauteur de la note créée
  + Si une tuile atteint le haut de la partie "cascade", elle disparait
+ En [mode accord](#mode-accord), les tuiles apparaissent au même niveau et aucune ne remonte



## Fonctions des boutons

### Effacer

**Bouton one-click : déclenche une action.**\
Supprime toutes les notes de la _session_. Démarre une nouvelle _session_.



### Sauvegarder

**Bouton one-click : déclenche une action.**\
Enregistre en mémoire dans l'application les notes de la session en cours.\
Données sauvegardées : ordre, note, _hauteur_, couleur, mode accord



### Sauvegarder dans un fichier

**Bouton one-click : déclenche une action.**\
Enregistre un fichier à l'emplacement voulu par l'utilisateur et contenant les notes de la session en cours.\
Données sauvegardées : ordre, note, _hauteur_, couleur, mode accord



### Mode "Accord"

**Bouton toggle : Actif (vert) - Inactif (Gris)**\
Quand actif : les notes créées apparaissent à la même hauteur et aucune ne remonte.\
Cette donnée est enregistrée dans la note sous forme d'identifiant de l'accord.\
Cela signifie qu'une note peut être retirée d'un accord mais pas séparée.



### Silence

**Bouton one-click : déclenche une action**\
Affiche une interface demandant la longueur du silence (x = entier entre 1 et 10)\
Créé _x_ tuile invisible de hauteur 1.



### Supprimer un silence

**Bouton one-click : déclenche une action**\
Affiche une message d'erreur à l'utilisateur si la dernière tuile n'est pas un silence.\
Affiche une interface demandant la longueur du silence a retirer (x = entier entre 1 et longueur du dernier silence)\
Supprime les _x_ derniers silences.


### Hauteur par défaut

**Entrée utilisateur : nombre décimal acceptant jusqu'à 1 chiffre après la virgule.**\
Défini le ratio de la hauteur d'une note.\
Exemple : \
- Hauteur de l'utilisateur : 1 ==> Longueur en pixel : 1/8 de la hauteur de l'écran\
- Hauteur de l'utilisateur : 3 ==> Longueur en pixel : 3/8 de la hauteur de l'écran\
Cas particulier :\
Longueur en pixel > hauteur de la partie cascade : La note est affiché mais passe derrière la partie interaction.



### Importer

**Bouton one-click : déclenche une action.**\
Permet d'importer un fichier contenant des notes. \
Sera jouer à la place de l'enregistrement mémoire s'il existe un fichier importé ET un enregistrement mémoire.



### Bpm

**Entrée utilisateur : nombre entier entre 30 et 240**\
Ratio de la vitesse à laquelle les tuiles descendront en [mode jouer](#jouer-la-musique)



### Jouer la musique

**Bouton one-click : déclenche une action.**\

Charge les notes du fichier importé.\
Si pas de fichier importé, charge les notes en mémoire.\
Si pas de notes en mémoire, affiche un message à l'utilisateur et reprends la session en cours.\

En cas de notes à importer :\
Fait disparaitre toutes les tuiles encore visible.\
Lis les tuiles existantes dans l'ordre et effectue les actions suivantes :\
- Fait glisser chaque tuile (ou tuiles d'un même accord) du haut de la partie cascade jusqu'à disparaitre entièrement derrière le clavier\
- Lorsqu'une tuile touche le clavier, la note du clavier correspondante change de couleur (sauf si c'est un silence)\
- Elle redevient blanche ou noire lorsque la tuile n'apparait plus.\
- Une tuile (sauf la première) n'apparait que lorsque la dernière tuile ou le dernier accord a fini d'apparaitre complètement.\
Affiche un message "Musique terminée" lorsque toutes les tuiles ont disparu

