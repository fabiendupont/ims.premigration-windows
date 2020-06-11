IMS - Pre Migration - Preserve Windows NICs and Disks
=====================================================

This role configures the Windows virtual machine for migration.
For that, it generates a PowerShell script that:

- Restores the IP configuration for network adapters statically configured
- Restores the disks drive letters
- Installs and starts RHEV-APT service if absent

Prerequisites
-------------

The Windows virtual machine must be configured to accept Ansible connection
with WinRM. Please, refer to Ansible documentation:

- [Setting up a Windows Host](https://docs.ansible.com/ansible/latest/user_guide/windows_setup.html)
- [Windows Remote Management](https://docs.ansible.com/ansible/latest/user_guide/windows_winrm.html)

Role Variables
--------------

The role behaviour can be influenced via some variables that are mainly
wrappers for the module used in the role. ***By default, no variable is set***.

The only variables that you may want to customize are the ones configuring
the Ansible WinRM connection.See
[Windows Remote Management > Inventory Options](https://docs.ansible.com/ansible/latest/user_guide/windows_winrm.html#inventory-options)

Example Playbook
----------------

The following playbook will register the virtual machine against a Satellite 6
server and enable the `rhel-7-server-rpms` repository. If no information is
provided in extra_vars, the playbook will assume that repositories are already
configured and will try to install the agent.

```yaml
---
- hosts: all
  vars:
    ansible_connection: winrm
    ansible_winrm_transport: kerberos
    ansible_winrm_server_cert_validation: ignore
  roles:
    - role: ims.premigration-windows-static-ip
```

License
-------

GPLv3

Author Information
------------------

Fabien Dupont <fdupont@redhat.com>