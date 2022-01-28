Role Vault
==================

Administrer le Vault.
Gérer la création de group ldap pour vault
Gérer les policy 
Gérer les ssh-engine permettant de gérer la connexion ssh sur les machines de l’icm.

- Utilisation du module shell de Ansible
- Templatiser la gestion des policy (.j2) permettant la création de policy à partir d’un template / liste de noms (variables)
- Templatiser la gestion des groupes (LDAP) (.j2) permettant la création de groupes à partir d’une liste de noms (variables)
- Templatiser la gestion des authorité SSH (connexion SSH aux machines) permettant la création d’une authorité SSH sur le vault à partir d’une liste de noms et de clés SSH.
- Permet une administration UNIQUE via Ansible, l’ensembles des policy/groupes/ssh étant supprimé puis recrée afin de s’assurer de l’état
- Permet de retrouver l’état du vault (groupes, policy, ssh) en cas de corruption

Requirements
------------

Fonctionne sur debian - ubuntu - centos - rhel 
Target a Vault server (like vault01 in ansible host)

Author Information
------------------

P.BAUDRIER
