# Project-Local Ansible Environment

This directory holds a self-contained Python virtual environment for running
this project's playbooks, pinned to the `ansible-core` version that matches
the collection requirements in `../requirements.yml`.

## Why a pinned venv

`community.general` is pinned to `>=8.0.0,<10.0.0` in `../requirements.yml`.
`community.general` 10.x dropped support for `ansible-core` 2.15/2.16 in
favor of 2.17+. To stay inside the supported range, `ansible-core` here is
pinned to the **2.16.x** line.

If you ever bump `community.general` past `10.0.0`, you must also bump
`ANSIBLE_CORE_VERSION` in `setup.sh` to `2.17.*` (or later) in the same
change — otherwise you'll reproduce the
`Collection community.general does not support Ansible version X` warning,
and likely the related `[DEPRECATED]` callback-plugin failure.

## Usage

```bash
cd ansible/
./setup.sh
source venv/bin/activate
```

From the project root, with the venv active:

```bash
cd ..
ansible-playbook -i inventory/hosts playbooks/stig_workstation.yml --check --diff
```

## What `setup.sh` does

1. Locates a usable system Python (3.10–3.12).
2. Creates a fresh venv at `ansible/venv/` (wipes and rebuilds each run).
3. Installs `ansible-core==2.16.*`.
4. Installs roles from `../requirements.yml` into `../roles/`.
5. Installs collections from `../requirements.yml` into `../collections/`.

Both install paths line up with `roles_path` and `collections_path` in
`../ansible.cfg`, so nothing outside this venv/repo is touched.

## Do not commit the venv

Add to the project's `.gitignore`:

```
ansible/venv/
collections/
```

(`roles/` and `requirements.yml` ARE meant to be committed — the venv and
the downloaded collection/role payloads are not, since `setup.sh` +
`requirements.yml` fully reproduce them.)

Wait — roles ARE reproducible from `requirements.yml` too. If you want a
fully minimal repo, also ignore:

```
roles/*
!roles/.gitkeep
```

and let `setup.sh` populate `roles/` fresh on every clone.
