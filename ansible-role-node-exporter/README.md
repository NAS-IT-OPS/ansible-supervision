Role NODE EXPORTER
===============

This role install node exporter to export metrics system (CPU, RAM, Disk, Network, ...) on Linux

Requirements
------------

No requirements only run ansible

Role Variables
--------------

This variables are default but you can overwrite them.

```
# user name to run node exporter process
node_exporter_user: "nodexporter"

# group name for this user (the same by default)
node_exporter_group: "{{ node_exporter_user }}"

# where store the node exporter process
node_exporter_dir: "/usr/bin/"
```

Dependencies
------------

Nothing

Author Information
------------------

Paul BAUDRIER
