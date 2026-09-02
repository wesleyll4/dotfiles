# Experimento Noctalia

**Status:** aprovado como provider alternativo funcional  
**Versão:** `noctalia 5.0.0_beta.10-1`  
**Origem:** Arch `extra`

## Seleção oficial

```text
./bootstrap desktop          # provider current (default)
./bootstrap desktop-noctalia # provider Noctalia
```

`desktop` continua sendo o default. `desktop-noctalia` permanece disponível
para uso e evolução, mas Noctalia não foi promovido a default.

## Ownership

```text
desktop_session_current  → Hypridle / Hyprlock
desktop_shell_current    → Waybar / Walker / Elephant / AGS
desktop_shell_noctalia   → bar, launcher, clipboard, control center,
                            session UI, tray e OSD
desktop_actions_current  → terminal, browser, file manager e screenshot
```

O Dunst continua sendo o owner de `org.freedesktop.Notifications`. Screenshot
permanece fora do Noctalia.

## Invariantes Noctalia

O provider deve manter desabilitados: lockscreen; `lock_before_suspend`; idle
lock; idle lock-and-suspend; idle screen-off; notification daemon; wallpaper.
Assim, Hypridle/Hyprlock e Dunst não são duplicados pelo Noctalia.

Não foram introduzidos Quickshell, AUR, Flatpak ou gerenciamento adicional de
packages.

## Binds validados

- `SUPER + Space` abre o launcher do provider selecionado;
- `SUPER + SHIFT + Space` abre o control center Noctalia;
- `SUPER + S` abre o scratch desktop;
- `SUPER + CTRL + L` chama Hyprlock.

## Problemas encontrados e correções

- bind Walker perdido na separação do core: restaurado no provider current;
- detecção de AGS por `pgrep -x ags`: substituída por `ags list`/instância
  `mydots`;
- encerramento assíncrono do AGS: passou a usar polling com timeout finito;
- rollback inicial não fase-aware: activation passou a registrar fases e
  desfazer somente ações efetivamente concluídas.

## Garantias operacionais

Os dois profiles fazem preflight, materializam o provider, validam a
configuração, trocam `shell.lua` atomicamente, aguardam processos assíncronos,
confirmam exclusividade e são idempotentes. Falhas entram em rescue com
rollback fase-aware. Fixtures cobrem estados válidos, inconsistentes,
timeouts, atomicidade e isolamento.

A recuperação manual via TTY está documentada em
`docs/operations/noctalia-tty-recovery.md`.

O experimento foi validado nas duas direções na sessão principal, com retorno
ao provider current e posterior seleção de Noctalia sem intervenção manual.
