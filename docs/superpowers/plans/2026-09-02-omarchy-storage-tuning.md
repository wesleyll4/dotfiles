# Omarchy Storage Tuning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Adicionar a role Ansible omarchy_storage_tuning ao profile omarchy, persistindo as opções aprovadas de dm-crypt via /etc/default/limine e garantindo o timer nativo semanal de TRIM com guard rails completos.

**Architecture:** A role nova fará preflight somente leitura, validará arquivo Limine, limine-update e hook encrypt antes de qualquer replace. A transformação será um replace cirúrgico do único token cryptdevice na única linha KERNEL_CMDLINE[default]; somente essa mudança notificará um handler dedicado. O timer será o unit nativo fstrim.timer, com targets e comandos fake nos testes.

**Tech Stack:** Ansible builtin modules (stat, slurp, assert, set_fact, replace, command), YAML, Bash, systemctl nativo e fixtures locais em mktemp.

**Spec:** docs/superpowers/specs/2026-09-02-omarchy-storage-tuning-design.md

## Global Constraints

- Role: omarchy_storage_tuning; composição em ansible/profiles/omarchy.yml.
- Produção usa /etc/default/limine, /usr/bin/limine-update, /usr/lib/initcpio/hooks/encrypt e /usr/bin/systemctl.
- Aceitar somente a forma original cryptdevice=PARTUUID=PARTUUID_EXISTENTE:root e a forma final exata :root:allow-discards,no-write-workqueue; o PARTUUID real nunca é hardcoded.
- Exigir uma linha ativa KERNEL_CMDLINE[default], um token cryptdevice, mapper root e rejeitar qualquer estado ambíguo antes da mutação.
- Preservar PARTUUID, todos os outros argumentos, comentários e linhas não relacionadas.
- limine-update roda somente via handler notificado pelo replace; não editar /boot/limine.conf nem rebuildar mkinitcpio.
- O hook deve suportar allow-discards|discard e no-write-workqueue|perf-no_write_workqueue; no-read-workqueue, flags persistentes, crypttab, discard contínuo Btrfs e nvme-cli são proibidos.
- Usar somente o fstrim.timer nativo, garantindo enabled + started; não criar override/timer customizado.
- Testes nunca tocam /etc/default/limine real, /boot real, systemd real ou limine-update real.
- O role usa become: true por default; a fixture sobrescreve omarchy_storage_tuning_become: false, sem sudo em command/shell.

---

## File Map

Criar:

- ansible/roles/omarchy_storage_tuning/defaults/main.yml: defaults dos paths reais, unit e comando systemctl.
- ansible/roles/omarchy_storage_tuning/tasks/main.yml: preflight, classificação, replace e garantia do timer.
- ansible/roles/omarchy_storage_tuning/handlers/main.yml: handler dedicado de limine-update.
- tests/fixtures/omarchy-storage-tuning.yml: playbook local que inclui somente a role e recebe a seam.
- tests/omarchy-storage-tuning-test.sh: fixtures fake, casos red/green e assertions.

Modificar:

- ansible/profiles/omarchy.yml: adicionar a role à lista existente.
- tests/omarchy-profile-test.sh: verificar path e composição.
- tests/ansible-structure-test.sh: verificar os paths novos.

Não modificar ansible/playbooks/omarchy.yml, roles Omarchy existentes, nem arquivos reais em /etc ou /boot.

## Task 1: Definir fixture isolado e testes red

**Files:**

- Create: tests/fixtures/omarchy-storage-tuning.yml
- Create: tests/omarchy-storage-tuning-test.sh

**Interfaces:**

- Consumes: role futura e variáveis de seam.
- Produces: teste Bash executável, inicialmente red porque a role ainda não existe.

- [ ] **Step 1: Criar a fixture Ansible**

~~~yaml
---
- name: Exercise Omarchy storage tuning role
  hosts: local
  gather_facts: false
  become: "{{ omarchy_storage_tuning_become | default(false) }}"
  tasks:
    - name: Include Omarchy storage tuning role
      ansible.builtin.include_role:
        name: omarchy_storage_tuning
~~~

- [ ] **Step 2: Criar harness e targets fake**

Usar fixture=$(mktemp -d), trap de remoção, diretórios fixture/etc, fixture/hooks
e fixture/bin, e exportar ANSIBLE_CONFIG, ANSIBLE_LOCAL_TEMP e
ANSIBLE_REMOTE_TEMP. O conteúdo inicial deve ser:

~~~bash
printf '%s\n' 'KERNEL_CMDLINE[default]+="quiet cryptdevice=PARTUUID=AAA:root root=/dev/mapper/root rootflags=subvol=@ rw"' >"$fixture/etc/default-limine"
printf '%s\n' 'allow-discards|discard' 'no-write-workqueue|perf-no_write_workqueue' >"$fixture/hooks/encrypt"
cat >"$fixture/bin/limine-update" <<'EOF'
#!/usr/bin/env bash
printf 'limine-update\n' >>"$OMARCHY_STORAGE_TEST_LOG"
EOF
cat >"$fixture/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
printf 'systemctl %s\n' "$*" >>"$OMARCHY_STORAGE_TEST_LOG"
EOF
chmod +x "$fixture/bin/limine-update" "$fixture/bin/systemctl"
~~~

- [ ] **Step 3: Rodar o red e commitar**

~~~bash
bash tests/omarchy-storage-tuning-test.sh
git add tests/fixtures/omarchy-storage-tuning.yml tests/omarchy-storage-tuning-test.sh
git commit -m "test: define Omarchy storage tuning fixture"
~~~

Esperado no primeiro run: falha por role inexistente.

## Task 2: Implementar preflight e transformação TDD

**Files:**

- Create: ansible/roles/omarchy_storage_tuning/defaults/main.yml
- Create: ansible/roles/omarchy_storage_tuning/tasks/main.yml
- Test: tests/omarchy-storage-tuning-test.sh

**Interfaces:**

- Consumes: overrides de path/comando da Task 1.
- Produces: facts omarchy_storage_tuning_content, omarchy_storage_tuning_default_cmdlines, omarchy_storage_tuning_cryptdevice_tokens e state original|final.

- [ ] **Step 1: Adicionar testes red de todos os guard rails**

Definir expect_failure name, restaurar o arquivo antes de cada caso e comparar
o arquivo depois. Cobrir target ausente, diretório e symlink; limine-update
ausente e não executável; hook ausente e sem cada parser; default ausente e
duplicado; cryptdevice ausente e duplicado; mapper data; e os tokens
:root:allow-discards, :root:no-write-workqueue e :root:foo.

~~~bash
printf '%s\n' 'KERNEL_CMDLINE[default]+="cryptdevice=PARTUUID=AAA:root:foo"' >"$fixture/etc/default-limine"
cp "$fixture/etc/default-limine" "$fixture/before"
expect_failure unknown_crypto_option
cmp "$fixture/before" "$fixture/etc/default-limine"
~~~

Executar bash tests/omarchy-storage-tuning-test.sh; o resultado deve ser red.

- [ ] **Step 2: Declarar defaults**

~~~yaml
---
omarchy_storage_tuning_limine_config: /etc/default/limine
omarchy_storage_tuning_limine_update: /usr/bin/limine-update
omarchy_storage_tuning_encrypt_hook: /usr/lib/initcpio/hooks/encrypt
omarchy_storage_tuning_systemctl: /usr/bin/systemctl
omarchy_storage_tuning_fstrim_unit: fstrim.timer
omarchy_storage_tuning_become: true
~~~

- [ ] **Step 3: Implementar preflight antes do replace**

Usar nessa ordem: stat follow:false do arquivo + assert regular/não symlink;
stat + assert dos executáveis; slurp do hook + assert dos dois padrões; slurp
do target + extração da cmdline; asserts de unicidade e estado. Tasks de
inspeção usam changed_when: false. Nenhuma mutação aparece antes do último
assert.

~~~yaml
default_pattern: '(?m)^[ \t]*KERNEL_CMDLINE\[default\]\+=[\"'']([^\"''\n]*)[\"''][ \t]*$'
cryptdevice_pattern: '(^|[ \t])(cryptdevice=[^ \t]+)(?=[ \t]|$)'
original_pattern: '^cryptdevice=PARTUUID=[^ \t:]+:root$'
final_pattern: '^cryptdevice=PARTUUID=[^ \t:]+:root:allow-discards,no-write-workqueue$'
~~~

Contar exatamente uma linha default e um token que começa por cryptdevice=;
validar o token inteiro contra original_pattern ou final_pattern. Isso rejeita
opções parciais/desconhecidas e garante mapper root.

- [ ] **Step 4: Implementar replace cirúrgico e rodar green**

~~~yaml
- name: Add approved dm-crypt options to native Limine cmdline
  ansible.builtin.replace:
    path: "{{ omarchy_storage_tuning_limine_config }}"
    regexp: '(^[ \t]*KERNEL_CMDLINE\[default\]\+=[\"''][^\"''\n]*?)(cryptdevice=PARTUUID=([^ \t:]+):root)(?=[ \t]|[\"''])([^\"''\n]*[\"''][ \t]*$)'
    replace: '\g<1>cryptdevice=PARTUUID=\g<3>:root:allow-discards,no-write-workqueue\g<4>'
  notify: Regenerate Limine configuration
  become: "{{ omarchy_storage_tuning_become }}"
  when: omarchy_storage_tuning_current_state == 'original'
~~~

Confirmar forma final exata, PARTUUID AAA, quiet, root, rootflags=subvol=@ e rw
preservados; forma final não muda; todos os casos de falha deixam o arquivo
idêntico.

- [ ] **Step 5: Commitar**

~~~bash
git add ansible/roles/omarchy_storage_tuning tests/omarchy-storage-tuning-test.sh
git commit -m "feat: add Omarchy storage tuning preflight"
~~~

## Task 3: Implementar handler, idempotência e timer nativo

**Files:**

- Create: ansible/roles/omarchy_storage_tuning/handlers/main.yml
- Modify: ansible/roles/omarchy_storage_tuning/tasks/main.yml
- Test: tests/omarchy-storage-tuning-test.sh

**Interfaces:**

- Consumes: notify da Task 2 e vars omarchy_storage_tuning_systemctl e omarchy_storage_tuning_fstrim_unit.
- Produces: execução fake observável somente quando a cmdline muda.

- [ ] **Step 1: Adicionar casos red de handler**

Após o primeiro apply, zerar o log, executar o segundo, exigir changed=0 e
provar que o log não contém limine-update. O fake systemctl deve registrar:

~~~text
systemctl enable --now fstrim.timer
~~~

- [ ] **Step 2: Criar handler sem mascarar falhas**

~~~yaml
---
- name: Regenerate Limine configuration
  ansible.builtin.command:
    argv: ["{{ omarchy_storage_tuning_limine_update }}"]
  become: "{{ omarchy_storage_tuning_become }}"
~~~

Não usar shell, sudo, failed_when: false ou || true.

- [ ] **Step 3: Garantir o unit nativo**

~~~yaml
- name: Enable and start native weekly fstrim timer
  ansible.builtin.command:
    argv:
      - "{{ omarchy_storage_tuning_systemctl }}"
      - enable
      - --now
      - "{{ omarchy_storage_tuning_fstrim_unit }}"
  become: "{{ omarchy_storage_tuning_become }}"
  changed_when: false
~~~

O default é /usr/bin/systemctl + fstrim.timer; não criar unit, drop-in,
override ou mount option. Rodar:

~~~bash
bash tests/omarchy-storage-tuning-test.sh
! rg -n 'no-read-workqueue|crypttab|--persistent|/boot/limine\.conf|[[:space:]]discard([[:space:]=,]|$)' ansible/roles/omarchy_storage_tuning
~~~

- [ ] **Step 4: Commitar**

~~~bash
git add ansible/roles/omarchy_storage_tuning tests/omarchy-storage-tuning-test.sh
git commit -m "feat: persist Limine storage tuning and native TRIM"
~~~

## Task 4: Integrar profile e estrutura

**Files:**

- Modify: ansible/profiles/omarchy.yml
- Modify: tests/omarchy-profile-test.sh
- Modify: tests/ansible-structure-test.sh

**Interfaces:**

- Consumes: role funcional da Task 3.
- Produces: profile normal usando o loop existente de ansible/playbooks/omarchy.yml.

- [ ] **Step 1: Criar assertion red e integrar**

Adicionar ao profile test, executar para confirmar red, e então adicionar
somente esta linha a profile_roles:

~~~bash
grep -Fx '  - omarchy_storage_tuning' "$profile" >/dev/null
~~~

~~~yaml
  - omarchy_storage_tuning
~~~

- [ ] **Step 2: Atualizar structure test e rodar green**

Adicionar ao loop de paths:

~~~text
ansible/roles/omarchy_storage_tuning/defaults/main.yml
ansible/roles/omarchy_storage_tuning/tasks/main.yml
ansible/roles/omarchy_storage_tuning/handlers/main.yml
tests/fixtures/omarchy-storage-tuning.yml
tests/omarchy-storage-tuning-test.sh
~~~

Executar bash tests/omarchy-profile-test.sh e bash tests/ansible-structure-test.sh.

- [ ] **Step 3: Commitar**

~~~bash
git add ansible/profiles/omarchy.yml tests/omarchy-profile-test.sh tests/ansible-structure-test.sh
git commit -m "feat: enable Omarchy storage tuning profile"
~~~

## Task 5: Suíte final e revisão de segurança

**Files:**

- Test: tests/omarchy-storage-tuning-test.sh
- Read: docs/superpowers/specs/2026-09-02-omarchy-storage-tuning-design.md

- [ ] **Step 1: Confirmar coverage map**

Task 2 cobre transformação, preservação e guard rails; Task 3 cobre notify,
idempotência e timer nativo; Task 4 cobre composição. O fixture deve nomear
assertions para os 20 itens pedidos: profile, forma original/final,
PARTUUID/adjacentes, idempotência, ausência/duplicidade de default/cryptdevice,
mapper, três opções inválidas, três estados de target, dois estados de
limine-update, três estados do hook, handler change-driven e timer enabled/started.

- [ ] **Step 2: Rodar suíte**

~~~bash
bash tests/omarchy-storage-tuning-test.sh
bash tests/omarchy-profile-test.sh
bash tests/ansible-structure-test.sh
~~~

Esperado: exit code 0 em todos; nenhum comando toca boot real.

- [ ] **Step 3: Commitar somente ajustes de teste finais**

~~~bash
git add tests/omarchy-storage-tuning-test.sh tests/omarchy-profile-test.sh tests/ansible-structure-test.sh
git commit -m "test: cover Omarchy storage tuning guard rails"
~~~

## Acceptance manual, separado dos testes automatizados

Os testes não executam Limine real. Em máquina Omarchy real, após o apply:

~~~bash
grep -F 'KERNEL_CMDLINE[default]' /etc/default/limine
grep -F ':root:allow-discards,no-write-workqueue' /boot/limine.conf
grep -E 'rootflags=.*subvol=' /boot/limine.conf
systemctl is-enabled fstrim.timer
systemctl is-active fstrim.timer
~~~

Confirmar na entrada normal e em cada snapshot as flags finais, preservando o
rootflags/subvol próprio; somente limine-update deve ter gerado o limine.conf.

Após reboot:

~~~bash
cat /proc/cmdline
dmsetup table root | grep -oE 'allow_discards|no_(read|write)_workqueue'
systemctl status fstrim.timer --no-pager
iostat -xz 1 10
~~~

Repetir iostat -xz 1 10 durante carga pesada da Steam e confirmar que o stall
grave anterior não reaparece.

## Self-review do plano

- A spec foi relida e cada requisito tem cobertura nas Tasks 2–5 ou na acceptance manual.
- Todos os paths existentes citados foram confirmados; os paths novos estão exclusivamente no File Map.
- Names de vars, fixture, handler e comandos são consistentes entre tasks.
- Não há pendências ou lacunas; PARTUUID_EXISTENTE é notação literal da regra e AAA é valor literal de fixture.
- Nenhum teste chama paths reais: todos os targets e executáveis são overrides no mktemp.
- Nenhuma task implementa discard Btrfs, no-read-workqueue, crypttab, cryptsetup --persistent, edição direta de /boot/limine.conf, rebuild de mkinitcpio ou gerenciamento de nvme-cli.
