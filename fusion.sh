#!/bin/bash -e

# Auteur :   Jean-Philippe Guérard
# Adr. él. : jean TIRET philippe POINT guerard CHEZ tigreraye POINT org

# Ce script lit les listes noires de plusieurs
# sites phpBB et les synchronise.

# Les listes synchronisées sont les listes des adresses IP
# et des adresses électroniques bannies. Les noms
# d'utilisateurs bannis ne sont pas synchronisés, car phpBB
# gère une liste de noms de comptes locale à la base qu'il
# n'est pas possible simplement de transposer dans une autre
# base.

# Liste des bases (remplacez ces bases par vos propres bases).
# Le nom de chaque base doit être suivi d'une barre oblique,
# puis du préfixe des tables.
BASES="forum1/phpbb forum2/phpbb3 forum3/phpbb"

# Version de référence de la liste noire
LISTE_REFERENCE="${HOME}/var/liste_noire_phpbb.txt"

# Choix du niveau de détail par défaut
# 0 -> Pas d'information, à part les messages d'erreur
#      des commandes utilisées.
# 1 -> Affichage en clair des entrées ajoutées

[ -z "${NIVEAU_DE_DETAIL}" ] && NIVEAU_DE_DETAIL=1

# Création du répertoire de travail

TEMP=$(/bin/mktemp -d) || exit 1

nettoyage() {

  /bin/rm -rf "${TEMP}"
  trap - EXIT

}

trap nettoyage EXIT

/bin/mkdir -p "${TEMP}/ajouts"

# Vidage du contenu de la table de bannissement
# L'utilisation de la fonction COPY permet de gérer
# proprement l'échappement des caractères

extraction() {

  typeset BASE="${1}"
  typeset EN_TETE_TABLES="${2}"

  /usr/bin/psql "${BASE}" -A -t \
      -c "COPY ${EN_TETE_TABLES}_banlist ( ban_ip , ban_email ) TO STDOUT" | \
    /usr/bin/gawk -F '\t' '( $1 != "" ) || ( $2 != "" ) { print }'

}

# Création de la liste globale et des listes propres à chaque
# base (merci tee). La liste globale et les listes par base
# sont triées et les entrées en double sont supprimées.

LISTE_GLOBALE="${TEMP}/liste-globale.txt"

creation_listes() {

  ( for i in ${BASES} ; do

    NOM_DE_LA_BASE="$( echo "${i}" | gawk -v FS="/" '{ print $1 }' )"
    EN_TETE_TABLES="$( echo "${i}" | gawk -v FS="/" '{ print $2 }' )"

    extraction "${NOM_DE_LA_BASE}" "${EN_TETE_TABLES}" | \
      /usr/bin/sort | \
      /usr/bin/uniq | \
      /usr/bin/tee "${TEMP}/${NOM_DE_LA_BASE}.txt"

    done ) | /usr/bin/sort | /usr/bin/uniq > "${LISTE_GLOBALE}"

}

# Nettoyage

if [ -f "${LISTE_REFERENCE}" ] ; then

  creation_listes

  # Création d'une liste globale de produits supprimés
  # depuis la dernière exécution

  for i in ${BASES} ; do

    NOM_DE_LA_BASE="$( echo "${i}" | gawk -v FS="/" '{ print $1 }' )"

    /usr/bin/diff "${LISTE_REFERENCE}" "${TEMP}/${NOM_DE_LA_BASE}.txt" \
    | gawk '/^</ { sub( "^< " , "" ) ; print }' >> "${TEMP}/suppressions.txt"

  done

  if [ -s "${TEMP}/suppressions.txt" ] ; then

    # Création d'une liste d'adresse IP et
    # d'une liste d'adresses électroniques

    cat "${TEMP}/suppressions.txt" \
    | sort \
    | uniq \
    | gawk -v TEMP="${TEMP}" -v FS="[[:space:]]" '$1 { print $1 > TEMP "/suppr-ip.txt" } ; $2 { print $2 > TEMP "/suppr-email.txt" }'

    # Impression du résultat

    if [ -s "${TEMP}/suppr-ip.txt" ] ; then
      /bin/echo "IP à supprimer"
      /bin/cat "${TEMP}/suppr-ip.txt"
    fi
    if [ -s "${TEMP}/suppr-email.txt" ] ; then
      /bin/echo "Adr. él. à supprimer"
      /bin/cat "${TEMP}/suppr-email.txt"
    fi
    /bin/echo

    # Suppression dans les bases

    for i in ${BASES} ; do

      NOM_DE_LA_BASE="$( echo "${i}" | gawk -v FS="/" '{ print $1 }' )"
      EN_TETE_TABLES="$( echo "${i}" | gawk -v FS="/" '{ print $2 }' )"

      if [ -s "${TEMP}/suppr-ip.txt" ] ; then

        /bin/cat "${TEMP}/suppr-ip.txt" \
        |  /usr/bin/xargs -l1 -r -IADR_IP \
           /usr/bin/psql "${NOM_DE_LA_BASE}" -q -c "delete from ${EN_TETE_TABLES}_banlist where ban_ip='ADR_IP' ;"

      fi
      if [ -s "${TEMP}/suppr-email.txt" ] ; then

        /bin/cat "${TEMP}/suppr-email.txt" | \
          /usr/bin/xargs -l1 -r -IADR_EL /usr/bin/psql "${NOM_DE_LA_BASE}" -q \
             -c "delete from ${EN_TETE_TABLES}_banlist where ban_email='ADR_EL' ;"

      fi

    done

  fi

fi

# Recherche des entrées manquantes

creation_listes

for i in ${BASES} ; do

  NOM_DE_LA_BASE="$( echo "${i}" | gawk -v FS="/" '{ print $1 }' )"
  EN_TETE_TABLES="$( echo "${i}" | gawk -v FS="/" '{ print $2 }' )"


  # On calcule la liste des entrées manquantes de
  # la base en cours, tout simplement en utilisant
  # la commande diff

  /usr/bin/diff "${TEMP}/${NOM_DE_LA_BASE}.txt" "${LISTE_GLOBALE}" | \
    gawk '/^>/ { sub( "^> " , "" ) ; print }' > "${TEMP}/ajouts/${NOM_DE_LA_BASE}.txt"

  # Si il y a des lignes à ajouter, impression
  # des entres à ajouter

  if [ -s "${TEMP}/ajouts/${NOM_DE_LA_BASE}.txt" ] ; then

    if [ "${NIVEAU_DE_DETAIL}" -ge 1 ] ; then

      # Calcul du nombre de ligne pour
      # l'affichage du bilan

      NB_LIGNES=$(/usr/bin/wc -l "${TEMP}/ajouts/${NOM_DE_LA_BASE}.txt" \
                  | gawk '{ print $1 }')

      if [ "${NB_LIGNES}" -ge 2 ] ; then
        LIGNES="lignes"
      else
        LIGNES="ligne"
      fi

      /bin/echo
      /bin/echo "Base ${NOM_DE_LA_BASE} : ${NB_LIGNES} ${LIGNES} à ajouter"
      /bin/echo

     # Impression du résultat

     /bin/echo "Données à ajouter"
     /bin/cat "${TEMP}/ajouts/${NOM_DE_LA_BASE}.txt"
     /bin/echo

   fi

   # Mise à jour de la base de données

   /bin/cat "${TEMP}/ajouts/${NOM_DE_LA_BASE}.txt" | \
     /usr/bin/psql "${NOM_DE_LA_BASE}" -q \
         -c "COPY ${EN_TETE_TABLES}_banlist ( ban_ip , ban_email ) FROM STDOUT ;"

 fi

done

# Mise à jour de la liste de référence

/bin/mv -f "${LISTE_GLOBALE}" "${LISTE_REFERENCE}"

exit 0

