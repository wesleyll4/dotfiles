# Arquitetura de dotfiles orientada ao ambiente de trabalho

**Status:** aprovada para planejamento; não inicia a migração por si só.

## Objetivo

Transformar este repositório de um conjunto de configurações do Arch atual em
uma definição reproduzível, modular e legível do ambiente de trabalho de Wes.
Arch Linux é a plataforma inicial, não a identidade do projeto. A arquitetura
deve permitir adicionar Omarchy, CachyOS ou outra plataforma quando houver um
caso real, sem criar uma camada universal prematura.

O primeiro resultado da migração preserva o comportamento atual. Não troca
Kitty, Zsh, Waybar, Walker, Hyprlock, Hypridle ou qualquer outro componente
somente por causa desta reorganização.

## Estado atual e restrições de migração

O repositório atual contém configurações por aplicação, uma configuração
Hyprland legada e uma migração em curso para Lua, além de um fluxo especializado
de greetd/ReGreet com testes de staging, drift e rollback. O estado de trabalho
existente precisa permanecer recuperável antes de qualquer migração.

Restrições:

- Não fazer clean rewrite.
- Não remover comportamento existente silenciosamente.
- Não instalar, remover ou trocar aplicações na fase arquitetural.
- Preservar os testes existentes de Hyprland e greetd/ReGreet.
- Manter `hyprland.conf` enquanto a configuração Lua for a transição e o
  fallback explicitamente necessário.
- Migrar em commits pequenos, semanticamente isolados e reversíveis.

## Modelo de camadas

```text
bootstrap
  -> Ansible
      -> profile (seleção e política)
          -> roles (responsabilidades executáveis)
              -> platform adapters e estado runtime

config/ (fonte versionada)
  -> Ansible materializa
      -> $HOME e /etc (estado runtime)
```

### Bootstrap

O bootstrap é um executável pequeno no diretório raiz. Ele detecta a plataforma
necessária para instalar dependências mínimas, instala Git/Python/Ansible quando
necessário e chama o playbook/profile selecionado. Não cria um segundo sistema
de provisionamento em shell e não instala aplicações do ambiente diretamente.

### Ansible

Ansible é o orquestrador principal de packages, links, cópias, templates,
serviços e validações declarativas. Roles devem ser idempotentes, falhar em
conflitos não gerenciados e poder ser executadas de forma independente quando
isso fizer sentido.

### Configurações

`config/` é a fonte de verdade de toda configuração versionada. Nenhuma role
Ansible gera, reescreve ou mantém arquivos dentro do repositório. Ela apenas
materializa fontes existentes no estado runtime.

Configurações pessoais normalmente são links gerenciados por Ansible. Arquivos
de sistema, especialmente em `/etc`, são copiados ou templateados; nunca são
links para um diretório do usuário.

### Scripts

`scripts/` contém comportamento executável que não é uma boa representação de
estado Ansible, como validadores e helpers de runtime. Scripts não são o
orquestrador geral da máquina. O fluxo atual de greetd/ReGreet permanece um
caso especializado até uma implementação Ansible equivalente preservar suas
garantias de segurança e rollback.

## Regra de responsabilidades

```text
profile       = seleção, composição e política
role          = responsabilidade executável
host_vars     = fatos e overrides da máquina
platform vars = diferenças reais da plataforma
platform role = comportamento específico da plataforma
```

Profiles não contêm instalação de pacotes, comandos operacionais, templates ou
lógica de detecção. Eles escolhem roles e valores de política. Roles aplicam o
estado e não devem conter fatos hardcoded de uma máquina concreta.

## Estrutura alvo

```text
dotfiles/
├── bootstrap
├── ansible/
│   ├── ansible.cfg
│   ├── requirements.yml
│   ├── inventories/
│   │   └── local/
│   │       ├── hosts.yml
│   │       ├── group_vars/
│   │       │   ├── all.yml
│   │       │   ├── platform_arch.yml
│   │       │   └── profile_*.yml
│   │       └── host_vars/
│   │           └── main_desktop.yml
│   ├── playbooks/
│   │   ├── workstation.yml
│   │   ├── dev.yml
│   │   └── verify.yml
│   └── roles/
│       ├── common/
│       ├── packages/
│       ├── cli_tools/
│       ├── shell_zsh/
│       ├── terminal_kitty/
│       ├── development/
│       ├── desktop_hyprland/
│       ├── desktop_session_current/
│       ├── desktop_shell_current/
│       ├── gaming/
│       ├── platform_arch/
│       ├── platform_omarchy/
│       └── greetd_regreet/
├── config/
│   ├── user/
│   │   ├── hypr/core/
│   │   ├── desktop-session/current/
│   │   ├── desktop-shell/current/
│   │   ├── kitty/
│   │   ├── zsh/
│   │   └── ...
│   ├── system/greetd/
│   └── templates/
├── scripts/
├── tests/
├── docs/
│   ├── architecture.md
│   ├── decisions/
│   └── inspirations/
└── secrets/
    └── README.md
```

Diretórios só são criados quando uma fase de migração precisa deles. A árvore é
um destino arquitetural, não autorização para criar todos os módulos de uma vez.

## Profiles e composição

Um profile é um playbook ou uma seleção declarativa de roles. Ele não é uma
role e não executa detalhes operacionais.

```text
workstation
├── common
├── cli_tools
├── shell_zsh
├── terminal_kitty
├── development
├── desktop_hyprland
├── desktop_session_current
├── desktop_shell_current
└── gaming
```

Exemplos futuros:

```text
workstation_noctalia
├── common
├── cli_tools
├── shell_zsh
├── terminal_kitty
├── development
├── desktop_hyprland
├── desktop_session_current
├── desktop_shell_noctalia
└── gaming

workstation_omarchy
├── common
├── cli_tools
├── shell_zsh
├── terminal_kitty
├── development
├── desktop_hyprland
├── desktop_shell_omarchy
└── gaming
```

O último exemplo pode omitir `desktop_session_current` se Omarchy for dono do
lock e do comportamento de sessão. Um profile `dev` pode selecionar somente
`common`, `cli_tools`, `shell_zsh`, `terminal_kitty` e `development`.

## Fronteira do desktop

### `desktop_hyprland`

É a role do compositor, e contém somente:

- compositor e opções neutras;
- input;
- monitores recebidos como fatos/overrides de host;
- workspaces;
- regras de janelas neutras;
- binds neutros do compositor, como foco, movimentação, resize e workspaces;
- hooks neutros de extensão.

Ela não conhece Waybar, Walker, Quickshell, Noctalia, Elephant, AGS,
omarchy-shell, Hyprlock ou Hypridle.

### `desktop_session_current`

Possui o comportamento atual de sessão, incluindo Hypridle, Hyprlock e os
binds/ações de lock associados. É substituível ou omitível independentemente do
compositor.

### `desktop_shell_current`

Possui a shell/UI atual: barra, launcher, menus, seus autostarts e integrações
associadas. Binds de launcher, clipboard, menus, calendário e ações próprias da
shell pertencem ao provider de shell, não ao compositor.

### Contrato de integração

Hyprland fornece slots de runtime estáveis:

```text
~/.config/hypr/
├── core/
└── integrations/
    ├── shell.lua
    └── session.lua
```

As fontes ficam versionadas, por exemplo:

```text
config/user/desktop-shell/current/hypr-integration.lua
config/user/desktop-session/current/hypr-integration.lua
```

O profile seleciona uma fonte por slot. `desktop_hyprland` executa a
materialização e limpa o diretório runtime gerenciado antes de aplicar os slots
selecionados. Dessa forma, uma troca de `desktop_shell_current` para
`desktop_shell_noctalia` deixa somente a integração selecionada ativa. O
compositor conhece o contrato e os nomes dos slots, nunca o produto provider.

## Terminal e ferramentas de linha de comando

Não existe uma role `terminal` agregadora. As fronteiras são independentes:

- `cli_tools`: ferramentas CLI e configurações que não exigem shell interativo;
- `shell_zsh`: Zsh e sua configuração atual;
- `terminal_kitty`: Kitty e sua configuração atual.

Futuras roles como `shell_fish` e `terminal_ghostty` substituem somente a
responsabilidade correspondente. Kitty e Zsh são defaults atuais; a preferência
permanente continua deliberadamente indefinida.

## Packages e plataformas

Não haverá catálogo lógico de nomes de packages na primeira etapa. Enquanto
Arch for a única plataforma concreta, variáveis por plataforma fornecem listas
de nomes físicos por responsabilidade:

```yaml
# platform_arch.yml
cli_tools_packages:
  - bat
  - eza
  - ripgrep

development_packages:
  - dotnet-sdk
  - nodejs
  - python
```

Roles como `development` e `cli_tools` pedem apenas a variável de sua
responsabilidade. A role `packages` instala a lista recebida através de um
backend interno específico da plataforma. O backend é detalhe interno de
`packages`, não uma segunda hierarquia pública de adaptadores.

Quando uma segunda plataforma concreta surgir, ela fornece suas próprias listas
físicas, por exemplo `fd-find` em vez de `fd`. Um catálogo lógico só será
introduzido se a repetição real entre plataformas justificar essa complexidade.

AUR e Flatpak são fontes distintas e explícitas. O AUR pertence ao adaptador
Arch e não é misturado com packages nativos. Flatpak usa application IDs e uma
responsabilidade própria opt-in.

`platform_arch` cuida de comportamento específico como preparação de AUR,
repositórios ou serviços Arch. `platform_omarchy` cuida de detecção e política
de coexistência/override. Essas roles não duplicam o backend interno de
`packages`.

## Hosts, máquina e segredos

Fatos de máquina, como monitores, resolução, orientação, GPU, mounts e
particularidades de hardware, pertencem a `host_vars/main_desktop.yml` ou a um
overlay local ignorado. Não pertencem a roles genéricas.

Valores publicáveis e úteis para reproduzir uma máquina podem ser versionados.
Valores privados ou sensíveis ficam em arquivos `*.local.yml` ignorados pelo
Git ou em Ansible Vault. A primeira versão não depende de um secret manager.

Nenhum secret, token, credential, chave privada ou valor equivalente entra em
`config/` ou em variáveis versionadas.

## Política de arquivos e links

- Links pessoais são gerenciados com Ansible e devem falhar em conflitos não
  reconhecidos.
- Arquivos de sistema são cópias/templates com owner e modo explícitos.
- Templates são reservados a configuração que realmente depende de host vars,
  plataforma ou entradas externas; arquivos estáticos continuam arquivos.
- Diretórios runtime de integração têm ownership explícito da role que os
  materializa e limpeza limitada ao escopo gerenciado.
- Nenhuma task pode fazer append não idempotente, como `>> ~/.zshrc`.

GNU Stow não é parte da arquitetura principal: Ansible já gerencia links,
conflitos, templates, host vars e arquivos de sistema na mesma orquestração.

## Greetd/ReGreet

O bundle atual de greetd/ReGreet possui validações e rollback específicos. Ele
não será simplificado durante a introdução do Ansible. A role `greetd_regreet`
é uma direção futura; a migração só pode ocorrer após demonstrar equivalência
de segurança, staging, drift detection, ativação e rollback, mantendo o script
atual como fallback durante essa transição.

## Documentação leve de decisões

`docs/decisions/` guarda decisões pequenas com contexto, status e alternativas.
Um registro pode declarar, por exemplo, que Kitty é `current/default`, com
preferência `undecided` e Ghostty como experimento futuro. `docs/inspirations/`
guarda referências a Omarchy, Noctalia e outros projetos, sempre com a ideia
observada e a decisão de adotar, adaptar ou não adotar.

## Validação

Cada etapa de implementação deve ter validação proporcional:

- `ansible-playbook --syntax-check`;
- `ansible-playbook --check`, quando aplicável;
- execução real seguida de segunda execução sem mudanças relevantes;
- `ansible-lint` e `yamllint` após as ferramentas existirem no bootstrap;
- `bash -n`, `tests/config-test.sh` e `tests/install-test.sh` preservados;
- validação de configuração com `Hyprland --verify-config`;
- smoke test manual de sessão, launcher, barra, lock, aliases e ferramentas;
- VM Arch limpa antes de declarar reproduzibilidade completa;
- CI inicial limitado a syntax check, lint e testes de shell.

## Invariantes arquiteturais

1. `config/` é a fonte versionada de verdade; Ansible não a modifica.
2. Profiles compõem e selecionam; roles executam.
3. `desktop_hyprland` não conhece providers de shell/UI, lock ou idle.
4. Shell/UI e comportamento de sessão são substituíveis independentemente do
   compositor.
5. Terminal emulator, shell interativo e CLI tooling são independentes.
6. `host_vars` contém fatos/overrides de máquina, não defaults universais.
7. Roles genéricas não chamam diretamente `pacman`, `apt` ou `dnf`.
8. Não existe catálogo lógico de packages sem necessidade comprovada por mais
   de uma plataforma.
9. Cada slot de integração runtime tem exatamente um provider ativo selecionado
   pelo profile.
10. Arquivos de `/etc` são copiados/templateados; configurações pessoais são
    normalmente links gerenciados.
11. Segredos não entram no Git.
12. Migrações preservam comportamento, são incrementais e mantêm rollback
    simples.

## Fora de escopo desta especificação

- Implementar a árvore proposta ou migrar arquivos existentes.
- Trocar aplicativos atuais por Quickshell, Noctalia, omarchy-shell, Ghostty ou
  Fish.
- Instalar Omarchy, CachyOS ou uma segunda distribuição.
- Montar CI extensa ou uma abstração multi-distribuição genérica.
- Remover o fluxo atual de greetd/ReGreet.

O próximo artefato, após a revisão humana desta especificação, será um plano de
implementação incremental. Nenhuma mudança funcional começa antes da aprovação
desse plano.
