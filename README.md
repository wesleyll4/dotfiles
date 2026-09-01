# Dotfiles

## Provisionamento

O entrypoint arquitetural é `./bootstrap`:

```sh
./bootstrap desktop --check
./bootstrap dev --check
```

Ele calcula a raiz do checkout, exporta o `ANSIBLE_CONFIG` do repositório e
injeta `dotfiles_root` e `dotfiles_home` no playbook selecionado. Nesta fase,
ele instala somente o Ansible se ainda não estiver disponível. Os profiles
`desktop` e `dev` também gerenciam os links atuais de Starship, Mise, Yazi e
Zsh.

Depois que o Ansible estiver disponível, valide o contrato de execução a partir
de qualquer diretório com:

```sh
bash tests/ansible-vars-test.sh
```

O teste usa um `dotfiles_home` temporário; ele não escreve no `$HOME` real.

### Links gerenciados

As roles de configuração usam o contrato conservador
`ansible/roles/common/tasks/adopt_link.yml`. Um link pode ser criado quando o
target está ausente, mantido quando já aponta para a fonte esperada, ou migrado
somente de uma fonte legada explicitamente aprovada. Symlinks inesperados,
arquivos e diretórios falham sem ser alterados. As fontes precisam ser caminhos
canônicos dentro de `dotfiles_root`; o target precisa estar dentro de
`dotfiles_home`. O contrato nunca usa sobrescrita genérica.

```sh
bash tests/config-link-test.sh
```

Configuração pessoal para Arch Linux, Hyprland e os utilitários do desktop.
Os arquivos ficam versionados aqui e são ligados ao `$HOME`; configurações do
sistema são copiadas com backup, porque `/etc` não deve apontar para o diretório
do usuário.

## Migração do Hyprland para Lua

O ponto de entrada ativo é `config/user/hypr/candidate/hyprland.lua`, dividido
em `core/` e slots de integração para sessão, shell e ações. As configurações
de Hypridle/Hyprlock e os assets dos providers também vivem em `config/user/`.
O diretório legado `hypr/.config/hypr/lua/` permanece apenas porque o instalador
especializado de greetd/ReGreet ainda o utiliza.

Antes de instalar:

```sh
./install.sh check
```

Para criar apenas os links do usuário:

```sh
./install.sh install-user
```

O Hyprland usa a configuração Lua materializada em `~/.config/hypr`; não há
fallback operacional para a antiga configuração monolítica.

## Login visual com greetd + ReGreet

A sessão do greeter usa uma instância mínima do Hyprland. O formulário aparece
no `HDMI-A-1` e o `DP-3` fica com fundo escuro. A cada início do greeter, o
launcher sorteia uma imagem instalada em `/etc/greetd/wallpapers`. Se nenhuma
estiver disponível, ele usa o wallpaper Tokyo Night versionado como fallback.

Wallpapers pessoais ficam somente nesta máquina. Links colocados em
`greetd/etc/greetd/wallpapers/` são ignorados pelo Git; durante o staging, o
instalador copia os bytes para `/etc/greetd`, de modo que o usuário `greeter`
não precise acessar o diretório pessoal. Nesta máquina estão configurados:

- `monochrome.png` → `wallhaven-3q3vw6.png`
- `elf-prison.jpg` → `wallhaven-8geml1.jpg`

Primeiro instale os pacotes e prepare os arquivos sem trocar o display manager:

```sh
sudo ./install.sh install-system --no-activate
/etc/greetd/launch-regreet.sh --demo
```

Feche e abra a demo novamente para fazer um novo sorteio. Como são apenas duas
imagens, o mesmo resultado pode aparecer duas vezes seguidas.

Feche a demo e, quando o visual estiver aprovado, ative o greetd:

```sh
sudo ./install.sh install-system --activate --demo-tested
```

Os comandos instalam os pacotes listados em `packages.arch` e guardam os arquivos
anteriores em `/var/lib/wes-dotfiles/backups`. A ativação exige que o staging
exista e que você confirme a demo com `--demo-tested`. Somente `--activate` desativa
o serviço do Ly e ativa o greetd. Em uma falha, o Ly só é reativado depois de o
greetd ser confirmado como parado, evitando dois display managers disputando o TTY.
O pacote do Ly não é removido.

Para voltar ao backup original e reativar o Ly a partir de um TTY:

```sh
cd /home/wes/dotfiles
sudo ./install.sh rollback
```

## Verificação

```sh
tests/config-test.sh
tests/install-test.sh
bash -n install.sh tests/*.sh
```
