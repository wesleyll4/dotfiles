# Boundary temporário de greetd/ReGreet

**Status:** preservado deliberadamente

O fluxo de greetd/ReGreet continua sendo operado pelo `install.sh`, separado
das roles genéricas do Ansible. Esta fronteira inclui:

- validação do usuário/root e dos caminhos de destino;
- staging de arquivos em `/etc/greetd` como arquivos regulares;
- validação de metadados e `Hyprland --verify-config`;
- detecção de drift por manifesto SHA-256;
- backups versionados e preservação do backup original;
- ativação opcional após demonstração (`--demo-tested`);
- rollback com snapshot de recuperação e restauração segura do Ly.

Enquanto `install.sh` e seus testes dependerem de `hypr/.config/hypr/lua`, esse
diretório é uma source operacional e deve permanecer no repositório. A
configuração de login/display manager não deve ser movida para
`desktop_hyprland`, `platform_arch` ou outra role genérica nesta etapa.

Uma futura remoção de `hypr/.config/hypr/lua` exige uma migração específica
deste boundary: atualizar o instalador, seus fixtures de `install-user` e as
validações do greeter, mantendo as garantias de staging, drift, backup e
rollback. Esta decisão não autoriza essa migração.

## Garantias verificadas

Os testes existentes em `tests/install-test.sh` e `tests/config-test.sh`
continuam cobrindo check read-only, validação como usuário sudo, links Lua,
conflitos não gerenciados, staging sem troca de serviços, backups, idempotência,
detecção de drift, falhas de ativação e recuperação de rollback.

Nenhuma alteração em `/etc/greetd`, serviços de display manager ou no runtime
Hyprland é necessária para manter este contrato.
