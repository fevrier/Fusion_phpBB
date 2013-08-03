Fusion.sh
=========

Ce script lit les listes noires de plusieurs sites phpBB
et les synchronise.

Les listes synchronisées sont les listes des adresses IP
et des adresses électroniques bannies. Les noms
d'utilisateurs bannis ne sont pas synchronisés, car phpBB
gère une liste de noms de comptes locale à la base qu'il
n'est pas possible simplement de transposer dans une autre
base.


Précautions d'emploi et avertissements

*Attention !* N'utilisez pas ces commandes sans avoir
préalablement réalisé une sauvegarde de votre base de
données (en plus, avec PostgreSQL, c'est très simple
 -- cf. les commandes pg\_dump et pg\_dumpall).

*Attention !* Dans tous les cas, l'utilisation de ces scripts se
fait à vos risques et périls.

Installation

Éditez le script et modifiez la variable BASES, en
indiquant la liste de vos bases de données phpBB.

Le nom de chaque base doit être suivi d'une barre oblique
et du préfixe des tables utilisé par la base.

Ce script suppose que l'utilisateur en cours peut se
connecter à PostgreSQL sans utiliser de mot de passe. 
Si ce n'est pas le cas, quelques adaptations mineures
sont nécessaires. 
