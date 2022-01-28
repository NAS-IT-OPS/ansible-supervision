Role BASE SETUP
==================

L'objectif de ce rôle est d'installé une première brique de sécurité au nieau système. L'idée est de le jouer sur toutes les machines à chaque run pour notamment :
- définir le hostname
- définir les packages par défaut
- créer les users admin et dev
- déployer les clefs ssh
- configurer sshd
- configurer le sudoers (activation des logs)


Requirements
------------

Fonctionne sur debian - ubuntu - centos - rhel 

Role Variables
--------------

Les variables par défault

```
# set default packages
base_setup_packages:
```

Author Information
------------------

P.BAUDRIER
