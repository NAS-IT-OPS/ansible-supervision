Role Prometheus
==================

Installer prometheus
Configurer prometheus
Templatiser la configuration (.j2) (Exporter / Alterting)

- Installation via apt/yum depuis le repo du Nexus de l'ICM
- Mise en place du fichier d’arguments complémentaires au service systemd prometheus (notamment activation du reload, persistance de la data durant 2 ans, activation des alertes)
- Création d’un répertoire de rules pour l’alerting
- Mise en place du fichier de configuration via template et reload de prometheus
- Copie des fichiers de rules (en prévision de plusieurs)
- Première rules prévoyant le template alertmanager pour alerting par mail
- Passage de variable : url/description/summary/grafana/documentation

Requirements
------------

Fonctionne sur debian - ubuntu - centos - rhel 


Author Information
------------------

P.BAUDRIER
