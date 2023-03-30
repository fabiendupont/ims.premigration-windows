IMS - Pre Migration - Windows
=============================

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

The account used to connect to the Windows virtual machine must have permissions to run the script with administrator permissions.

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
    - role: fdupont_redhat.ims_premigration_windows
```

Pre-Migration Script and virt-v2v First Boot
------------------------------

This section provides a primer on how the script is used as part of the migration process.

The pre-migration script `pre-migrate.ps1` captures
information about the VMs network and disk configuration and generates a powershell script to reapply the configuration after migration to OCP. The generated script is written to following path on the VM's system drive `\Program Files\Guestfs\Firstboot\scripts\`.

After the VM has been migrated to OCP virt-v2v runs a series of tasks as part of a process called `first boot`. Part of process is executing scripts stored in above mentioned scripts directory.

Post migration hooks are not required for scripts run as part of the first boot process.

**NOTE:** The first boot directory path is hard coded in virt-v2v, do not change the script paths in the PowerShell file.

**NOTE:** The pre-migration script makes no configuration changes to the VM, only the generated script makes configuration changes.
