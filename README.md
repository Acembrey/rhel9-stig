# RHEL 9 STIG Automation Project

Modular Ansible project for applying the DISA STIG RHEL 9 (Currently V2R8) role
* Define baselines under `roles/profiles`
* Define targets, and target specific configurations, under `playbooks`
* All tools are self contained and static. Currently and outbound connection is required to build the environment. This can be adjusted later depending on requirements.
* Another task will be created to actually scan the system after the role has been applied. OSCAP will be used currently, but I'd like to get my hands on Evaluate STIG, compare the functionality of the two, and determine which is easier to incorporate in a managed workflow.
* Boot STIGs need to either be applied manually, or in a kickstart file.
* **DO NOT** run the server STIG roles against GUI workstation, it will break things beyond a point worth repairing.
 
---

## Directory Layout

```
rhel9-stig-project/
├── ansible                         ← Python Virtual Environment for Ansible
│   ├── README.md
│   └── setup.sh
├── ansible.cfg
├── collections
├── group_vars
│   └── all
├── host_vars
├── inventory
├── playbooks                       ← Target definitions, can include vars that override profile
│   ├── stig_server.yml
│   ├── stig_template.yml
│   └── stig_workstation.yml
├── README.md
├── requirements.yml
├── roles
├── scripts                         ← Bash scripts to simplify environment actions
│   ├── init.sh
│   └── STIG_workstation.sh
├── tasks                           ← Additional Ansible tasks separate from roles
│   ├── oscap_server.yml
│   └── oscap_workstation.yml
└── vars                            ← Profile definitions (image defaults)
    └── profiles
        ├── stig_administrator.yml
        ├── stig_defaults.yml
        └── stig_developer.yml
```

---

## Quick Start

### 1. Install dependencies

```bash
ansible-galaxy install -r requirements.yml -p ./roles
ansible-galaxy collection install -r requirements.yml -p ./collections
```

Ansible **2.9+** is required (2.14+ recommended). Collections required:
- `ansible.posix >= 1.5.4`
- `community.general >= 8.0.0`

### 2. Verify connectivity

```bash
ansible -i inventory/hosts workstations -m ping
```

### 3. Dry-run

```bash
ansible-playbook -i inventory/hosts playbooks/stig_workstation.yml \
  --check --diff
```

### 4. Apply

```bash
ansible-playbook -i inventory/hosts playbooks/stig_workstation.yml
```

---

## How Control Toggling Works

The role exposes two control layers for each STIG check:

| Layer | Variable type | Example |
|---|---|---|
| STIG ID toggle | `DISA_STIG_RHEL_09_NNNNNN: true/false` | `DISA_STIG_RHEL_09_631020: false` |
| Functional task toggle | `snake_case_name: true/false` | `aide_build_database: false` |

Most checks have **both**. You should set both to `false` together when
disabling a control (see `stig_server.yml` dconf block for an example).

### Variable precedence (highest → lowest)

```
--extra-vars / -e
    ↓
playbook vars: block
    ↓
vars_files: (stig_defaults.yml)
    ↓
role defaults/main.yml
```

### Disable a single control at the command line (no file changes)

```bash
ansible-playbook -i inventory/hosts playbooks/stig_workstation.yml \
  -e "DISA_STIG_RHEL_09_631020=false aide_build_database=false"
```

### Disable a control permanently for a playbook

Add to the playbook's `vars:` block:

```yaml
vars:
  DISA_STIG_RHEL_09_631020: false  # skip AIDE DB build — run manually POA&M-042
  aide_build_database: false
```

### Disable across ALL playbooks

Edit `vars/profiles/stig_defaults.yml` directly.

---

## Adding a New Image Profile

1. Create `playbooks/stig_<profile>.yml`
2. Set `hosts:` to the appropriate inventory group
3. Add `vars_files: - ../vars/profiles/stig_defaults.yml`
4. Add only the `vars:` overrides specific to that profile
5. List only the roles that apply to that image type

---

## Workstation-Specific Notes (RHEL 9.7 Graphical)

The workstation playbook applies **both** roles:

- `RedHatOfficial.rhel9_stig` — base OS controls
- `RedHatOfficial.rhel9_stig_gui` — GNOME/GDM/dconf controls

The GUI role is the upstream equivalent of the `stig_gui` OpenSCAP profile
(`xccdf_org.ssgproject.content_profile_stig_gui`). It adds:
- dconf screensaver lock / idle timeout
- GDM banner and disable automatic login
- GNOME disable autorun / automount-open
- xwindows_runlevel_target (enforces graphical.target)

**fapolicyd note:** The `fapolicy_default_deny` control (RHEL-09-433010)
will block any binary not in the fapolicyd allow list. Before deploying
to workstations, audit your in-house tooling with:

```bash
fapolicyd --debug 2>&1 | grep 'deny'
```

and add required rules to `/etc/fapolicyd/rules.d/` before enabling.

**USBGuard note:** `usbguard_generate_policy` captures the USB topology at
the time Ansible runs. Ensure your CAC reader, keyboard, and mouse are all
connected during the play run.

---

## FIPS 140-2 Sunset (September 2026)

The default crypto policy is `FIPS:STIG`, which currently satisfies both
FIPS 140-2 and the STIG. As of September 2026, FIPS 140-2 validations expire.
Confirm with your ISSO whether FIPS 140-3 modules are required and update
`var_system_crypto_policy` accordingly when RHEL 9 ships validated 140-3 modules.
