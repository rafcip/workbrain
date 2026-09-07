#!/bin/sh
# Unico compito: fissare la umask a 002 prima di cedere il controllo allo step.
#
# Perche' serve: i container girano con uid 10001 e gid 0, che nel rootless corrisponde al
# GRUPPO `ubuntu` sull'host. Con la umask di default (022) i file prodotti nascerebbero 0644
# e l'utente `ubuntu` potrebbe leggerli ma non modificarli piu'. Con 002 nascono 0664 e il
# vault resta un vault, non un museo.
#
# Non decide, non orchestra, non sceglie il comando: quello arriva dal servizio systemd che
# lancia lo step, cosi' `ps` e `journalctl` mostrano quale step sta girando.
umask 002
exec "$@"
