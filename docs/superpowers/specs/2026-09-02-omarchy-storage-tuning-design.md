# Design de tuning de storage do Omarchy

**Status:** aprovado para implementação futura; esta spec não implementa mudanças funcionais.

## Objetivo e diagnóstico

Criar uma role dedicada, `omarchy_storage_tuning`, incluída no profile
`omarchy`, para persistir a política de performance de LUKS/dm-crypt e TRIM
no boundary nativo de boot do Omarchy. A role não deve se misturar a
`omarchy_hypr_overrides`, `common` ou outras responsabilidades.

O sistema validado é Omarchy 4.0.2/Arch, com root Btrfs sobre LUKS2:
`/dev/nvme0n1p2` → `/dev/mapper/root`. A fonte persistente da cmdline é
`/etc/default/limine`; `/boot/limine.conf` é gerado pelo fluxo nativo. A
cmdline atual contém `cryptdevice=PARTUUID=81d6c837-13e7-42bc-a1f4-96eceb915e0d:root`,
`root=/dev/mapper/root`, `zswap.enabled=0`, `rootflags=subvol=@`, `rw` e
`rootfstype=btrfs`.

O diagnóstico comprovou que `no-write-workqueue` reduz a fila e a latência do
dm-crypt, enquanto `allow-discards` habilita o discard anteriormente bloqueado.
O primeiro `fstrim` liberou 844.8 GiB; com ambas as opções, a carga pesada da
Steam voltou a operar sem o stall observado. O NVMe não apresentou alertas,
erros de mídia ou erros no error log; temperatura observada: 59 °C.

## Política de boot

A role deve editar somente a entrada persistente necessária em
`/etc/default/limine`, sem assumir ownership do arquivo inteiro, reconstruir a
cmdline ou hardcodar o PARTUUID. Deve localizar exatamente um
`KERNEL_CMDLINE[default]` ativo e exatamente um `cryptdevice` cujo mapper seja
`root`, preservando o valor existente de PARTUUID e todos os demais argumentos.

A única transformação permitida é:

```text
cryptdevice=PARTUUID=<valor-existente>:root
→ cryptdevice=PARTUUID=<mesmo-valor>:root:allow-discards,no-write-workqueue
```

São aceitas somente a forma original sem opções e a forma final exatamente
`allow-discards,no-write-workqueue`. Opções desconhecidas ou preexistentes,
mapper diferente de `root`, ausência/duplicidade de `cryptdevice` ou
ausência/duplicidade de `KERNEL_CMDLINE[default]` devem causar falha fechada,
antes de qualquer mutação.

Guard rails obrigatórios:

- `/etc/default/limine` existe, é arquivo regular e não é symlink;
- `limine-update` existe e é executável;
- o hook `encrypt` usado pelo mkinitcpio existe e suporta `allow-discards` e
  `no-write-workqueue`;
- não aceitar nem habilitar `no-read-workqueue`.

Não editar `/boot/limine.conf` diretamente. Um handler deve executar
`limine-update` somente quando `/etc/default/limine` realmente mudar. Não
regenerar mkinitcpio apenas por causa dessas opções, pois o hook instalado pelo
`limine-mkinitcpio-hook` 1.37.1-1 já as suporta.

## Política de TRIM

Usar o `fstrim.timer` nativo fornecido pelo sistema. A role apenas deve
garantir que esse timer esteja `enabled` e `started`; não deve criar override
nem timer customizado. A periodicidade semanal continua sendo a periodicidade
do timer nativo. Não adicionar discard contínuo aos mount options do Btrfs e
não executar `fstrim` manualmente em cada bootstrap. A role não gerencia
`nvme-cli` como dependência.

## Limites explícitos

Não fazer alterações persistentes no header LUKS, não criar/configurar
`/etc/crypttab`, não alterar a arquitetura Limine/mkinitcpio, não mudar
compressão, mount options ou outras políticas do Btrfs, e não assumir
ownership de `/boot/limine.conf`.

O `limine-update` deve atualizar a entrada normal e as entradas de snapshots.
Snapshots devem conservar seus próprios `rootflags`/`subvol`; a role apenas
altera a fonte persistente da cmdline.

## Idempotência e rollback

A primeira execução transforma a forma original e reporta `changed=1`. A forma
final e execuções subsequentes reportam `changed=0`; nesse caso,
`limine-update` não roda. A habilitação do timer também deve ser idempotente.

Rollback lógico:

1. remover `:allow-discards,no-write-workqueue` da entrada `cryptdevice`;
2. executar `limine-update`;
3. desabilitar `fstrim.timer` se a política anterior for restaurada integralmente;
4. reiniciar;
5. confirmar a ausência das flags no mapper.

O trade-off de `allow-discards` — expor ao storage quais regiões criptografadas
estão livres — foi conscientemente aprovado para este desktop pessoal.

## Testes mínimos de implementação

1. O profile `omarchy` inclui `omarchy_storage_tuning`.
2. Fixture original produz exatamente a forma final.
3. PARTUUID e todos os demais argumentos são preservados.
4. A forma final é idempotente.
5. Ausência ou duplicidade de `cryptdevice` falha.
6. Mapper inesperado falha.
7. Opção crypto desconhecida/preexistente falha.
8. Múltiplos `KERNEL_CMDLINE[default]` falham.
9. Alvo inexistente, não regular ou symlink falha.
10. `limine-update` ausente/não executável falha.
11. Hook `encrypt` ausente ou sem os dois suportes exigidos falha.
12. O handler de `limine-update` é change-driven.
13. `fstrim.timer` fica habilitado e semanal, sem discard contínuo.

## Acceptance

- As opções persistem pelo fluxo nativo do Limine.
- Antes do reboot, após `limine-update`, `/boot/limine.conf` contém
  `:root:allow-discards,no-write-workqueue` na entrada normal e nas entradas de
  snapshots; cada snapshot preserva seu próprio `rootflags`/`subvol`; a role
  não edita `/boot/limine.conf` diretamente.
- `fstrim.timer` executa semanalmente.
- O bootstrap é idempotente e todos os guard rails são testados.
- Após reboot, `/proc/cmdline` contém as opções e `dmsetup table root` mostra
  `allow_discards` e `no_write_workqueue`.
- A carga pesada da Steam não reproduz o stall grave observado antes do tuning.
