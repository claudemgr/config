---
name: RPM packaging conventions
description: Spec file structure, build workflow, signing, and repo layout for CasjaysDev RPM packages
type: user
---

## Directory Layout

```
~/rpmbuild/                              # Spec files + sources (per-package subdirs)
  {name}/
    {name}.spec
    {source tarballs / patches}

~/.local/tmp/BUILD/                      # rpmbuild working dir (%_builddir)
~/.local/tmp/BUILDROOT/                  # rpmbuild install root (%_buildrootdir)

~/Documents/builds/rpmbuild/RHEL/el{VER}/
  SRPMS/                                 # Source RPMs
  {ARCH}/rpms/                           # Binary RPMs  ← final output
  {ARCH}/debug/                          # debuginfo/debugsource

~/Documents/builds/sourceforge/RHEL/el{VER}/{ARCH}/
  casjay/    os/    langs/    databases/
  infra/     extras/   kernel/   debug/   testing/   empty/
```

Spec and source files always live together under `~/rpmbuild/{name}/` — this
matches `%_specdir` and `%_sourcedir` in `.rpmmacros`.

---

## ~/.rpmmacros

Full config — install to `~/.rpmmacros` on any build host or inside any build container:

```
%global debug_package  %{nil}

%distroname           casjay
%packager             CasjaysDev
%_gpg_name            CasjaysDev RPM Dev <rpm-devel@casjaysdev.pro>
%vendor               %packager http://github.com/rpm-devel

%_minorver            .3.4
%_pdistro             %distroname
%_osver               el%{?rhel}

%dist                 %_minorver.%_pdistro.%_osver
%distribution         %_minorver.%_pdistro.%_osver
%_release_name        RHEL

%_topdir              %{getenv:HOME}/rpmbuild
%_sourcedir           %{getenv:HOME}/rpmbuild/%{name}
%_specdir             %{getenv:HOME}/rpmbuild/%{name}
%_builddir            %{getenv:HOME}/.local/tmp/BUILD
%_buildrootdir        %{getenv:HOME}/.local/tmp/BUILDROOT
%_buildroot           %{_buildrootdir}/%{name}-%{version}-%{release}.%{BuildArch}

%_srcrpmdir           %{getenv:HOME}/Documents/builds/rpmbuild/%_release_name/%_osver/SRPMS
%_rpmdir              %{getenv:HOME}/Documents/builds/rpmbuild/%_release_name/%_osver/%BuildArch/rpms
%_debugrpmdir         %{getenv:HOME}/Documents/builds/rpmbuild/%_release_name/%_osver/%BuildArch/debug

%_signature           gpg
%_gpg_path            %(echo $HOME)/.gnupg
%_gpgbin              /usr/bin/gpg
%_var                 /var
%_tmppath             /tmp
%_usr                 /usr
%_usrdir              /usr
%_usrsrc              /usr/src
%_docdir              /usr/share/doc
%_sysconfdir          /etc
%_prefix              /usr
%_bindir              /usr/bin
%_libdir              /usr/%_lib
%_libexecdir          /usr/libexec
%_sbindir             /usr/sbin
%_sharedstatedir      /var/lib
%_datarootdir         /usr/share
%_datadir             /usr/share
%_includedir          /usr/include
%_infodir             /usr/share/info
%_mandir              /usr/share/man
%_localstatedir       /var
%_initddir            /etc/rc.d/init.d
%ext_info             .gz
%ext_man              .gz
%_smp_mflags          -j2

# Non-interactive GPG signing — reads passphrase from file, never prompts
%__gpg_sign_cmd       %{__gpg} gpg \
  --no-verbose --no-armor --batch \
  --passphrase-file %{getenv:HOME}/.gnupg/rpm_sign_pass.txt \
  --pinentry-mode loopback \
  --no-secmem-warning \
  -u "%{_gpg_name}" \
  -sbo %{__signature_filename} \
  --digest-algo sha256 \
  %{__plaintext_filename}

%__arch_install_post [ "%{buildarch}" = "noarch" ] || QA_CHECK_RPATHS=1 ; \
    case "${QA_CHECK_RPATHS:-}" in [1yY]*) /usr/lib/rpm/check-rpaths ;; esac \
    /usr/lib/rpm/check-buildroot
```

### GPG passphrase file

`~/.gnupg/rpm_sign_pass.txt` must exist on the build host and inside any
build container (bind-mount it in). Permissions must be `600`:

```sh
chmod 600 ~/.gnupg/rpm_sign_pass.txt
```

The file contains only the raw passphrase, no newline required but one is harmless.

---

## Build — Docker Container

Builds always run inside a container. Never run `rpmbuild` directly on the host.

### Container image

Use the official AlmaLinux image for the target RHEL version:

```sh
# x86_64
docker run --rm -it \
  --name rpmbuild-{name}-$(tr -dc 'a-z0-9' </dev/urandom | head -c8) \
  -v "$HOME/rpmbuild:/root/rpmbuild" \
  -v "$HOME/Documents/builds:/root/Documents/builds" \
  -v "$HOME/.rpmmacros:/root/.rpmmacros:ro" \
  -v "$HOME/.gnupg:/root/.gnupg:ro" \
  almalinux:9 bash

# aarch64 (cross or native)
docker run --rm -it \
  --platform linux/arm64 \
  --name rpmbuild-{name}-$(tr -dc 'a-z0-9' </dev/urandom | head -c8) \
  -v "$HOME/rpmbuild:/root/rpmbuild" \
  -v "$HOME/Documents/builds:/root/Documents/builds" \
  -v "$HOME/.rpmmacros:/root/.rpmmacros:ro" \
  -v "$HOME/.gnupg:/root/.gnupg:ro" \
  almalinux:9 bash
```

Substitute `almalinux:9` with `almalinux:8`, `almalinux:10`, or `fedora:latest` as needed.

### Container setup (run once per container)

```sh
# Inside the container
dnf install -y rpm-build rpm-sign rpmdevtools dnf-utils gnupg2 make gcc

# Create required directories
mkdir -p ~/.local/tmp/BUILD ~/.local/tmp/BUILDROOT
mkdir -p ~/Documents/builds/rpmbuild/RHEL/el9/{x86_64/rpms,x86_64/debug,SRPMS}

# Verify macros are loaded
rpm --eval '%dist'           # should print .3.4.casjay.el9
rpm --eval '%_gpg_name'      # should print CasjaysDev RPM Dev <rpm-devel@casjaysdev.pro>
```

### Build a spec

```sh
# Install build deps
dnf builddep -y ~/rpmbuild/{name}/{name}.spec

# Download remote sources (requires rpmdevtools)
spectool -g -R ~/rpmbuild/{name}/{name}.spec

# Build binary + source RPMs
rpmbuild -ba ~/rpmbuild/{name}/{name}.spec

# Build binary RPM only
rpmbuild -bb ~/rpmbuild/{name}/{name}.spec
```

Logs go to stdout; redirect to a file if needed. On success the RPM lands in
`~/Documents/builds/rpmbuild/RHEL/el{VER}/{ARCH}/rpms/`.

---

## GPG Signing

Non-interactive signing uses `~/.gnupg/rpm_sign_pass.txt` via the
`%__gpg_sign_cmd` override in `.rpmmacros` (defined above). No pinentry,
no interactive prompt.

```sh
# Sign a single RPM
rpmsign --addsign {package}.rpm

# Sign all RPMs in a directory
find ~/Documents/builds/rpmbuild/RHEL/el9/x86_64/rpms -name '*.rpm' \
  -print0 | xargs -0 -r rpmsign --addsign

# Verify a signed RPM
rpm --checksig {package}.rpm
```

The passphrase file must be readable before `rpmsign` is called.
If the file does not exist or is unreadable, signing will fail — never
fall back to interactive mode.

Import the public key for local verification:

```sh
rpm --import ~/.gnupg/RPM-GPG-KEY-casjay
```

---

## Repo Creation

After building and signing, create the repodata with `createrepo_c`:

```sh
# Install createrepo_c if not present
dnf install -y createrepo_c

# Create / update repo metadata
createrepo_c ~/Documents/builds/sourceforge/RHEL/el9/x86_64/casjay/

# Sign the repomd.xml (clients with repo_gpgcheck=1 require this)
gpg --batch \
    --passphrase-file ~/.gnupg/rpm_sign_pass.txt \
    --pinentry-mode loopback \
    --detach-sign --armor \
    ~/Documents/builds/sourceforge/RHEL/el9/x86_64/casjay/repodata/repomd.xml
```

Run `createrepo_c --update` on subsequent runs to only process new/changed packages.

---

## Repo Categories

Packages are published under `RHEL/el{VER}/{ARCH}/`:

| Category | Contents |
|---|---|
| `casjay` | CasjaysDev-built packages (primary) |
| `testing` | Pre-release / unstable packages |
| `os` | Upstream base OS mirror |
| `langs` | Language runtimes (PHP, Node.js, Python) |
| `databases` | Database servers (MariaDB, PostgreSQL, MongoDB) |
| `infra` | Infrastructure tooling (Docker, Jenkins) |
| `extras` | Community extras (EPEL, RPM Fusion, Remi) |
| `kernel` | ELRepo kernel packages |
| `debug` | debuginfo / debugsource RPMs |
| `empty` | Placeholder for arches with no packages |

---

## Spec File Structure

### Required header fields (in order)

```spec
%global some_ver  1.2.3     # use %global for constants, not %define

Name:       {name}
Version:    {version}
Release:    1%{?dist}
Summary:    One-line description (imperative, no trailing period)
License:    {SPDX-identifier}
URL:        https://...

# BuildArch only when genuinely architecture-independent (scripts, data)
# BuildArch: noarch

Source0:    https://.../{name}-{version}.tar.gz
# Source1, Source2, ... for additional sources

BuildRequires: make
Requires:      bash

%description
Multi-line description of what the package does.
```

Rules:
- **`Release: 1%{?dist}`** — always; `%{?dist}` expands via `.rpmmacros`
- **`License:`** — SPDX identifiers (`Apache-2.0`, `MIT`, `GPLv2`, `GPLv2+`) — never informal names
- **No `Group:` tag** — deprecated since RHEL 7; omit entirely
- **No `%clean` section** — deprecated; omit entirely
- **No `%defattr`** — deprecated; use `%attr` per-file in `%files` if needed
- **`BuildArch: noarch`** — only for scripts, data, truly arch-independent content; Go/Rust binaries are never noarch
- **`%global` over `%define`** — `%global` expands everywhere; use it for spec-level constants

### Section separators

```spec
# -----------------------------------------------------------------------
# Python interpreter selection
# -----------------------------------------------------------------------
```

### Conditionals

```spec
%if 0%{?rhel} >= 10
  ...
%endif
%if 0%{?rhel} == 9
  ...
%endif
%if 0%{?fedora}
  ...
%endif
```

Use `0%{?rhel}` (leading zero) — expands to `0` when undefined, preventing syntax errors.

### %prep

```spec
%prep
%setup -q -n %{name}-%{version}
```

### %build

```spec
%build
%make_build
```

Or for custom builds:
```spec
%build
%{__make} %{?_smp_mflags} BINDIR=%{_bindir} PREFIX=%{_prefix}
```

- Always use `%{?_smp_mflags}` for parallel builds (set to `-j2` in `.rpmmacros`)
- Never hardcode paths — use macros
- Go binaries: `CGO_ENABLED=0 go build -ldflags "-s -w" -o %{name} ./...`
- Noarch/script packages: `%build` may be empty or omitted

### %install

```spec
%install
%{__rm} -rf %{buildroot}
%{__install} -Dpm 0755 %{name}           %{buildroot}%{_bindir}/%{name}
%{__install} -Dpm 0644 %{name}.1         %{buildroot}%{_mandir}/man1/%{name}.1
%{__install} -Dpm 0644 completions/bash  %{buildroot}%{_datadir}/bash-completion/completions/%{name}
%{__install} -Dpm 0644 %{name}.conf      %{buildroot}%{_sysconfdir}/%{name}/%{name}.conf
```

- Always start with `%{__rm} -rf %{buildroot}`
- Use RPM macro wrappers: `%{__install}`, `%{__rm}`, `%{__mkdir}`, `%{__cp}`, `%{__tar}`, `%{__ln_s}`
- `%{__install} -Dpm {mode} src dst` creates parent directories automatically
- Modes: `0755` executables · `0644` data/config · `0600` secrets

### %files

```spec
%files
%license LICENSE
%doc README.md
%{_bindir}/%{name}
%{_mandir}/man1/%{name}.1*
%{_datadir}/bash-completion/completions/%{name}
%config(noreplace) %{_sysconfdir}/%{name}/%{name}.conf
```

- `%license` — license file
- `%doc` — documentation
- `%config(noreplace)` — config not overwritten on upgrade (preferred)
- `%config` — config overwritten on upgrade (rare)
- `%dir` — own a directory without owning its contents
- `%attr({mode},{user},{group})` — explicit permissions when needed
- Always use macros, never hardcoded paths

### %changelog

```spec
%changelog
* Thu May 22 2026 CasjaysDev <rpm-devel@casjaysdev.pro> - 1.0-1
- Initial package
```

- Format: `* Weekday Mon DD YYYY Name <email> - version-release`
- Date must be a real calendar date (`rpmbuild` warns on invalid day-of-week)
- Most recent entry at top
- Bullets use `-` not `*`
- No markdown

---

## Scriptlets

`$1` argument values:

| `$1` | Meaning |
|---|---|
| `1` | Fresh install |
| `2` | Upgrade |
| `0` | Final removal |

### systemd services — use RPM macros

```spec
%post
%systemd_post %{name}.service

%preun
%systemd_preun %{name}.service

%postun
%systemd_postun_with_restart %{name}.service
```

`%systemd_*` macros (from `systemd-rpm-macros`) handle `$1` correctly and are
the RHEL/Fedora standard. Never write raw `systemctl` calls in scriptlets.
For timer units include both the `.service` and `.timer` in each macro.

### Non-systemd scriptlets

```spec
%post
if [ $1 -eq 1 ]; then
  # fresh install only
fi

%preun
if [ $1 -eq 0 ]; then
  # final removal only
fi
```

- Scriptlets must be minimal — no network calls, no package manager invocations
- Guard non-fatal operations with `|| true`
- Never `exit 1` in a scriptlet — it aborts the entire transaction

---

## BuildArch and Multi-Arch

| Package type | `BuildArch` | Notes |
|---|---|---|
| Shell scripts, data, noarch configs | `BuildArch: noarch` | One `.noarch.rpm` for all arches |
| Go binary | omit | Build per-arch inside matching container |
| Rust binary | omit | Build per-arch inside matching container |
| C binary | omit | Build per-arch inside matching container |

Target arches: `x86_64` and `aarch64`. Build each in its own container.

---

## Rules

- **Never hardcode paths** — always use `%{_bindir}`, `%{_sysconfdir}`, `%{_datadir}`, `%{_mandir}`, etc.
- **Use RPM macro wrappers** for all filesystem commands in `%install` and scriptlets
- **`%{buildroot}` not `$RPM_BUILD_ROOT`**
- **No `Group:`, no `%clean`, no `%defattr`** — deprecated; omit
- **`Release: 1%{?dist}`** always
- **All packages signed** with `rpmsign --addsign` before publishing — unsigned packages will not install when `gpgcheck=1`
- **Non-interactive signing** via `~/.gnupg/rpm_sign_pass.txt` and `%__gpg_sign_cmd` override in `.rpmmacros` — never rely on interactive pinentry
- **Spec + sources under `~/rpmbuild/{name}/`** — matches `%_specdir` / `%_sourcedir`
- **Builds always inside Docker containers** — `almalinux:{ver}` image; never `rpmbuild` on the host
- **No debug subpackages** — `%global debug_package %{nil}` is set globally in `.rpmmacros`
- **Target platforms**: RHEL/AlmaLinux/Rocky 8, 9, 10 + Fedora latest; architectures x86_64 and aarch64
