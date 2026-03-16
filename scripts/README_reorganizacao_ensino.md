# Reorganização da Pasta ENSINO — Documentação

## Visão Geral

Este conjunto de scripts automatiza a reorganização da pasta `ENSINO`, movendo tudo que estiver **fora** de `Ensino Reformulação` para **dentro** dessa subpasta, organizado por **ano** e **categoria**.

| Arquivo | Descrição |
|---|---|
| `reorganizar-ensino.ps1` | Script PowerShell principal com toda a lógica |
| `executar_reorganizacao_ENSINO.bat` | Lançador BAT com menu interativo (recomendado para uso no dia a dia) |

---

## Pré-requisitos

- **Windows 7 / 10 / 11** com **PowerShell 5.1** ou superior (já incluído no Windows 10/11).
- Nenhuma dependência externa é necessária.
- O usuário deve ter permissão de leitura e gravação na pasta `ENSINO`.

---

## Como Usar

### Opção 1 — Via arquivo BAT (recomendado)

1. Abra o **Explorador de Arquivos** e navegue até a pasta `scripts\`.
2. Dê **duplo clique** em `executar_reorganizacao_ENSINO.bat`.
3. Escolha no menu:
   - **`1`** → Modo **Simulação** (nenhum arquivo é movido, apenas mostra o que seria feito)
   - **`2`** → Modo **Real** (move os arquivos de verdade — pede confirmação)
   - **`3`** → Cancela e sai

A janela permanece aberta ao final para que você possa ler as mensagens.

### Opção 2 — Via PowerShell diretamente

Abra o **PowerShell** (pode ser o Windows Terminal ou o ISE) e execute:

```powershell
# Simulação (DRY-RUN) — sem mover nada
.\reorganizar-ensino.ps1 -DryRun

# Execução real — move os arquivos
.\reorganizar-ensino.ps1

# Caminho personalizado + simulação
.\reorganizar-ensino.ps1 -RaizEnsino "C:\OutraPasta\ENSINO" -DryRun

# Caminho personalizado + execução real com log em local específico
.\reorganizar-ensino.ps1 -RaizEnsino "C:\OutraPasta\ENSINO" -LogPath "C:\Logs\reorganizacao.log"
```

> **Dica:** Se o PowerShell recusar a execução por política de segurança, use:
> ```powershell
> powershell -ExecutionPolicy Bypass -File .\reorganizar-ensino.ps1 -DryRun
> ```
> (O arquivo `.bat` já faz isso automaticamente.)

---

## Parâmetros do Script `.ps1`

| Parâmetro | Tipo | Padrão | Descrição |
|---|---|---|---|
| `-RaizEnsino` | string | `d:\usuarios\fisio06\Desktop\FISIO2013\ENSINO` | Caminho completo da pasta ENSINO |
| `-DryRun` | switch | (ausente) | Modo simulação — nenhum arquivo é movido |
| `-LogPath` | string | `scripts\reorganizacao_YYYY-MM-DD.log` | Caminho do arquivo de log |

---

## Regras de Decisão

### 1. Detecção de Ano

O ano de cada item é determinado nesta ordem de prioridade:

1. **Ano no nome do arquivo** — ex.: `Turma2019_lista.xlsx` → ano `2019`
2. **Ano no nome da pasta** — ex.: pasta `2021_Processo_Seletivo` → ano `2021`
3. **Ano em qualquer parte do caminho completo** — ex.: `…\2020\Fotos\foto.jpg` → ano `2020`
4. **Ano da data de modificação** — usado como último recurso

Somente anos entre `2000` e `(ano atual + 1)` são aceitos como válidos.

### 2. Pasta Inteira × Arquivo por Arquivo

Quando o script analisa uma **subpasta**:

- Se **≥ 80% dos arquivos** pertencem ao **mesmo ano** → a pasta é movida **inteira** para esse ano.
- Se os arquivos têm **anos mistos** → cada arquivo é movido **individualmente** para seu respectivo ano.

### 3. Destino dos Arquivos

```
Ensino Reformulação\
  └── <ANO>\
        ├── <Categoria>\              ← se a categoria puder ser inferida
        │     └── arquivo.ext
        └── _IMPORTADOS_AUTO\
              └── <NomeDaPastaOrigem>\  ← se categoria não identificada
                    └── arquivo.ext
```

### 4. Categorias Reconhecidas Automaticamente

O script identifica categorias pelo **nome do arquivo** usando palavras-chave:

| Palavras-chave no nome | Categoria |
|---|---|
| cadastr | Cadastramento |
| historico, historicos | Historicos |
| processo seletivo, selecao | Processo Seletivo |
| prova, provas, gabarito, gabaritos | Provas e Gabaritos |
| divulg | Divulgacao |
| foto, fotos, imagem, imagens, img | Fotos e Imagens |
| formul | Formularios |
| planilha, xlsx, xls | Planilhas |
| atalho, lnk | Atalhos |
| setup, install, installer | Instaladores |

### 5. Triagem (Sem Ano)

Arquivos cujo ano **não pôde ser determinado** por nenhum critério vão para:

```
Ensino Reformulação\_TRIAGEM_SEM_ANO\
```

Revise essa pasta manualmente após a execução.

### 6. Colisões de Nome

Se já existir um arquivo com o mesmo nome no destino, o script **nunca sobrescreve**. Em vez disso, renomeia com sufixo:

```
relatorio.pdf         → já existe
relatorio__DUP_1.pdf  → novo nome atribuído automaticamente
relatorio__DUP_2.pdf  → se __DUP_1 também existir
```

### 7. O que NÃO é tocado

- Tudo dentro de `Ensino Reformulação` permanece **intacto**.
- O próprio arquivo de log nunca é movido.

---

## Arquivo de Log

Um arquivo de log é gerado automaticamente na pasta `scripts\` com o nome:

```
reorganizacao_YYYY-MM-DD.log
```

Exemplo de conteúdo:

```
[2025-06-10 14:22:01][INFO] ======================================================================
[2025-06-10 14:22:01][AVISO]   MODO SIMULACAO (DRY-RUN) - Nenhum arquivo sera movido
[2025-06-10 14:22:01][INFO]   Raiz ENSINO   : d:\usuarios\fisio06\Desktop\FISIO2013\ENSINO
[2025-06-10 14:22:03][INFO] Analisando pasta: '...\2021_Seletivo'
[2025-06-10 14:22:03][INFO]   Total arquivos: 12 | Ano majoritario: 2021 (100%)
[2025-06-10 14:22:03][SIM] [SIMUL] Moveria: '...\2021_Seletivo' -> '...\Ensino Reformulacao\2021\_IMPORTADOS_AUTO\2021_Seletivo'
```

---

## Exemplo de Execução Passo a Passo

### Passo 1 — Simule primeiro (SEMPRE faça isso antes)

```bat
REM Via BAT: escolha opção 1 no menu
REM Via PowerShell:
powershell -ExecutionPolicy Bypass -File .\reorganizar-ensino.ps1 -DryRun
```

Revise o log gerado e verifique se as ações planejadas fazem sentido.

### Passo 2 — Execute de verdade

```bat
REM Via BAT: escolha opção 2 no menu e confirme com "S"
REM Via PowerShell:
powershell -ExecutionPolicy Bypass -File .\reorganizar-ensino.ps1
```

### Passo 3 — Revisar triagem

Verifique manualmente a pasta:

```
d:\usuarios\fisio06\Desktop\FISIO2013\ENSINO\Ensino Reformulacao\_TRIAGEM_SEM_ANO\
```

e mova os itens para o local correto conforme necessário.

---

## Perguntas Frequentes

**O script pode apagar meus arquivos?**
Não. O script apenas **move** arquivos, nunca apaga. A única exceção é a remoção de pastas de origem que ficaram **completamente vazias** após o processamento arquivo a arquivo.

**O que acontece se eu interromper o script no meio?**
Os arquivos já movidos permanecem no destino. Você pode rodar o script novamente com segurança — itens já dentro de `Ensino Reformulação` não são tocados.

**O script funciona com nomes com acentos, espaços e parênteses?**
Sim. O script usa `-LiteralPath` em todas as operações do PowerShell, o que garante tratamento correto de caracteres especiais.

**O log fica onde?**
Na mesma pasta onde está o `.ps1`, com nome `reorganizacao_YYYY-MM-DD.log`. Você pode especificar outro local com `-LogPath`.
