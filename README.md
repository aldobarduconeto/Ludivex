# GameHub — launcher e ofertas de jogos

Ofertas de **Steam, Epic Games Store, Xbox, PlayStation, Nuuvem, Ubisoft Store e EA Store**, lista de desejos e biblioteca para iniciar jogos instalados. No Android, o GameHub reúne os jogos do celular e as promoções de PC e consoles. Isso não executa jogos de PC ou console no telefone e não altera o aplicativo de tela inicial do Android. As requisições HTTP são feitas diretamente às fontes das lojas. Não há servidor próprio, backend separado, banco externo ou sincronização remota.

## Executar

Use o Flutter instalado (as dependências atuais do lockfile requerem Flutter 3.47 / Dart 3.13 ou superior):

```powershell
flutter pub get
flutter run -d windows
```

## Ícone do aplicativo

O ícone combina um controle 3D verde vibrante com uma etiqueta azul de promoção pendurada por um cordão sobre fundo preto. O arquivo original está em `assets/branding/app_icon.png`; o registro da geração está em `assets/branding/README.md`.

O projeto configura **`flutter_launcher_icons: ^0.14.3`** nas dependências de desenvolvimento. O lockfile resolveu a versão compatível 0.14.4. Para gerar novamente os tamanhos e formatos nativos:

```powershell
flutter pub get
dart run flutter_launcher_icons
```

O pacote gera os ícones Android (incluindo adaptativo), iOS, Web/PWA, Windows e macOS. O Linux não é suportado pelo gerador: o projeto reutiliza o PNG no GTK e instala o ícone de 512 px e o arquivo `.desktop` no bundle por CMake. O empacotador Linux deve instalar esses arquivos nos diretórios `share/applications` e `share/icons` da distribuição. A geração dos arquivos foi executada; builds nativos de cada sistema devem ser feitos nos ambientes correspondentes. Após trocar o ícone, pode ser necessário reinstalar o app ou atualizar o cache da PWA.

Android, iOS e macOS também são suportados pelo projeto. Para a Web, as APIs escolhidas precisam permitir CORS para a origem do aplicativo. O app não contorna essas restrições nem cria um proxy. Prefira o aplicativo nativo quando a API da loja não aceitar chamadas do navegador.

## Navegação

As abas se adaptam à plataforma:

- **Descobrir:** reúne todas as lojas selecionadas, com catálogo paginado, banners de categorias, busca local e ordenação. Em Configurações, escolha 12, 24, 48 ou 96 promoções por vez, ou todas as já carregadas, e qual plataforma aparece primeiro. **Mostrar mais promoções** revela os cartões seguintes e consulta novas páginas quando necessário.
- **Lista de desejos:** jogos salvos de qualquer loja, inclusive sem oferta ativa ou sem preço consultado.

- **Configurações:** preferências de lojas, região, aparência e atualização.
- **Biblioteca:** jogos cadastrados no dispositivo, busca por nome, filtro por plataforma e botão **Jogar**. Disponível nos aplicativos nativos; **oculta na Web**, no menu lateral e na navegação inferior.
- **Dispositivos / Setup:** grade de controles e fones Bluetooth, com bateria, firmware, última consulta e verificação de atualizações. Na navegação inferior, a aba é chamada **Setup**.

As telas de **Adicionar à lista** e **Editar acompanhamento** são abertas sobre essas abas. O histórico local de avisos fica dentro da lista de desejos.

## Dispositivos Bluetooth e firmware

Em **Dispositivos / Setup**, use **Buscar dispositivos** para consultar controles e fones já pareados com o sistema. A grade mostra nome, tipo, bateria, firmware e data do registro. É possível filtrar controles/fones, editar os dados, cadastrar modelos manualmente e removê-los da lista. A leitura de dispositivos não é iniciada sem tocar no botão de busca.

| Plataforma | Cobertura |
| --- | --- |
| Android | Consulta aparelhos pareados após a permissão **Dispositivos próximos / Bluetooth** no Android 12+. Em aparelhos BLE compatíveis, **Ler dados Bluetooth** consulta os serviços padrão Battery Service (`0x180F`, nível `0x2A19`) e Device Information (`0x180A`, firmware `0x2A26`, fabricante `0x2A29`). As leituras são serializadas, limitadas a nove segundos e encerram a conexão GATT depois. |
| Windows | Consulta registros Bluetooth PnP de controles/fones reconhecidos pelo nome. Mostra bateria e firmware apenas quando o Windows fornece essas propriedades; versão de driver não é tratada como firmware. |
| iOS, macOS, Linux e Web | Cadastro manual e consulta das fontes de atualização integradas. A leitura Bluetooth nativa não foi implementada nessas plataformas. |

**Pareado não significa conectado.** Registros salvos também não representam uma conexão ativa: os cards distinguem aparelhos encontrados na busca, registros anteriores e cadastro manual. Dados ausentes aparecem como **não informados**, sem percentuais ou versões simuladas. Headsets Bluetooth clássico e protocolos proprietários podem não expor bateria/firmware pelo BLE padrão; desligados ou fora de alcance também podem não responder. O cadastro manual permite informar a versão exibida pelo aplicativo do fabricante e identifica essa informação como fornecida pelo usuário.

### Serviço de atualizações de dispositivos

**Verificar atualizações** consulta fontes oficiais e compara versões numéricas quando há um feed público identificável por modelo. Ao abrir a aba com dispositivos salvos, o serviço também verifica atualizações e repete a consulta após 12 horas enquanto a aba/app estão ativos; não há serviço de sistema rodando com o GameHub fechado. As páginas recebidas têm cache de 12 horas, limites de requisição e timeout. Identificadores Bluetooth não são enviados aos fabricantes; apenas URLs públicas predefinidas por modelo são consultadas.

- **Sony WH-1000XM4/XM5/XM6 e WF-1000XM4/XM5:** consulta a página oficial de downloads do modelo e extrai títulos de firmware. Uma versão numérica mais nova gera **Atualização disponível**. Sem firmware atual ou sem metadados suficientes, informa **versão não identificada** ou a versão pública para comparação, sem afirmar que o aparelho está atualizado. Exemplo de [fonte oficial WH-1000XM5](https://www.sony.com/electronics/support/product/wh-1000xm5/downloads).
- **Xbox, DualSense, 8BitDo e SteelSeries/Arctis:** orienta a verificação pelo software/fonte oficial, pois não há um feed genérico integrado para comparar o firmware de cada unidade. Não confunde a versão do aplicativo atualizador com o firmware do controle/fone. Consulte [PlayStation Accessories](https://controller.dl.playstation.net/controller/lang/en/2100004.html), [8BitDo Updater](https://support.8bitdo.com/firmware-updater.html) e [SteelSeries Engine](https://support.steelseries.com/hc/en-us/articles/360056638111-How-do-I-check-if-my-device-s-firmware-is-up-to-date).
- **Outros modelos:** informa que não há fonte integrada, em vez de declarar que estão atualizados.

O GameHub faz a consulta e abre o site oficial; a instalação do firmware é realizada pela ferramenta do fabricante. Dados de dispositivos são persistidos exclusivamente em `SharedPreferencesAsync`, na chave `devices.v1`. Resultados das consultas de atualização permanecem em memória e são refeitos conforme necessário.

O código Dart e a sintaxe do leitor PowerShell foram verificados. Os novos testes de dispositivos e a compilação Android não foram executados nesta revisão porque as solicitações de acesso ao cache externo do Flutter foram recusadas; bateria, firmware e permissões ainda precisam de validação em hardware real.

## Biblioteca e launcher

A biblioteca é local e independente da lista de desejos. Adicionar um jogo não instala, compra ou transfere licenças. Jogos, atalhos e launchers precisam estar disponíveis no dispositivo. O cadastro manual permite selecionar Steam, Epic Games, Xbox Store, EA, Ubisoft Connect, GOG, Android e iOS, além de nomes personalizados.

| Plataforma | Adicionar e iniciar jogos |
| --- | --- |
| Android | A busca de jogos instalados acontece automaticamente na inicialização da biblioteca e ao voltar ao aplicativo. Os resultados aparecem em **Jogos detectados no celular**, sem abrir janelas sobre outras telas e sem salvar jogos automaticamente. Em **Revisar jogos encontrados**, escolha todos ou apenas os desejados. Se um título não aparecer, use **Adicionar jogos do celular** e marque **Incluir aplicativos sem categoria de jogo**; essa opção também pode mostrar aplicativos que não são jogos. **Jogar** abre o aplicativo pelo pacote Android. Se ele for desinstalado, o GameHub informa a falha sem apagar o cadastro. |
| iPhone/iPad | Cadastro manual com um link de abertura compatível fornecido pelo próprio jogo. Não há varredura de aplicativos instalados nem suporte a executáveis. Jogos sem um link de abertura acessível não podem ser iniciados dessa forma. |
| Windows | Busca autorizada nas bibliotecas Steam, manifests da Epic, atalhos da área de trabalho/menu Iniciar para EA e Ubisoft e jogos registrados no Windows para Xbox Store. Também aceita executáveis e atalhos `.lnk`, preservando os argumentos do atalho. |
| Linux/macOS | Busca nas pastas conhecidas da Steam e cadastro manual de destinos compatíveis. |
| Web | Biblioteca e varredura indisponíveis. Promoções, lista de desejos e configurações continuam disponíveis, sujeitas às regras de CORS das lojas. |

No computador, a busca começa **somente após “Permitir e buscar”**; no Android, a detecção é automática e não executa buscas simultâneas. Os resultados apresentam **Adicionar todos** ou **Escolher jogos**; nada é salvo apenas por executar a varredura. Jogos já cadastrados pelo mesmo identificador ou destino são ignorados. Você pode informar uma pasta da Steam fora dos locais comuns. A detecção depende dos registros, atalhos e permissões disponíveis e não garante encontrar toda instalação.

No Android, um `MethodChannel` nativo consulta atividades `MAIN`/`LAUNCHER` e abre o jogo usando `getLaunchIntentForPackage`. O manifesto declara essa consulta específica, sem `QUERY_ALL_PACKAGES`, e a lista de aplicativos não é enviada a servidores. No iOS, o cadastro usa links de abertura, respeitando as [restrições do sistema para consultar outros aplicativos](https://developer.apple.com/documentation/uikit/uiapplication/canopenurl(_:)).

### Compatibilidade das ofertas Xbox

Os cartões Xbox e a lista de desejos mostram a compatibilidade informada pela fonte. Ao selecionar a loja Xbox em **Descobrir**, use os filtros:

- **Console Xbox:** a fonte declara suporte a console Xbox.
- **Xbox Play Anywhere:** o catálogo declara explicitamente XPA; não é deduzido apenas pela presença de versões para PC e console.
- **Somente Windows:** os metadados declaram Windows/PC sem console Xbox.
- **Xbox e Windows · XPA não confirmado:** há suporte às duas plataformas, mas sem indicação explícita de Play Anywhere.
- **Compatibilidade não informada:** faltam metadados suficientes; confira a página oficial antes de comprar.

A classificação usa campos estruturados de plataformas e a indicação `XboxXPA`/capacidade equivalente. O catálogo Xbox consulta metadados adicionais em lotes de até 100 IDs pelo DisplayCatalog, reutilizando o cache HTTP; se essa consulta falhar, os preços disponíveis continuam sendo exibidos. O suporte às duas plataformas, sozinho, não garante o benefício de compra compartilhada do [Xbox Play Anywhere](https://developer.microsoft.com/en-us/games/resources/xbox-play-anywhere/).

## APIs e cobertura

Em **Configurações → Lojas e APIs**, selecione suas lojas e teste cada fonte.

| Loja | Consulta integrada | Limites |
| --- | --- | --- |
| Steam | Catálogo regional de descontos paginado (`search/results`), Store Search para buscar jogos e App Details por App ID | Até 50 resultados por página, com avanço até o fim informado pela fonte. Pacotes, restrições regionais e mudanças no endpoint podem afetar a cobertura. |
| Epic | Catálogo público EGData + gratuitos oficiais da Epic | Jogos pagos em promoção, paginação de 40 jogos e preços BRL. Gratuitos temporários na primeira página. |
| Xbox | Catálogo público regional Xbox + DisplayCatalog da Microsoft | Catálogo paginado, preços de compra e metadados de compatibilidade. IDs de produtos de 12 caracteres também permitem consultar jogos específicos. A cobertura e os metadados dependem da fonte. |
| Nuuvem | HTML público do catálogo brasileiro | Jogos, preços BRL, validade e paginação. Sem chave ou login. |
| Ubisoft Store | Busca pública utilizada pela própria loja brasileira | Jogos e preços BRL paginados. A credencial pública de busca é lida da página, sem chave pessoal ou configuração. |
| EA Store | Página brasileira de ofertas + cotação GraphQL anônima | Consulta em lotes de 12 jogos, somente BRL e preço de não assinante. O endpoint regional pode ficar indisponível; não usa preços USD como se fossem reais. |
| PlayStation | Catálogo público regional PlayStation Store | Promoções paginadas, sem login PSN. O endpoint pode mudar ou ficar indisponível; uma API alternativa é opcional. |

Cada loja também aceita uma API alternativa compatível. O aplicativo não exige que você execute um servidor para isso: deve ser um serviço de API existente, acessível diretamente pelo cliente. A URL alternativa é opcional. A indisponibilidade de uma fonte não impede a consulta das outras lojas; o app informa as falhas e preserva dados salvos.

Os endpoints públicos das lojas podem mudar ou bloquear chamadas. Confira sempre preço, edição, região e validade na página oficial. Não há autenticação para APIs privadas nesta versão; não coloque chaves secretas em URLs ou no código do app.

### Contrato das APIs alternativas

O aplicativo faz `GET` na URL HTTPS configurada, acrescentando `region=BR` e, ao buscar, `q=texto`. A resposta deve ter o formato:

```json
{
  "deals": [
    {
      "id": "produto-123",
      "title": "Nome do jogo",
      "currentPrice": 49.9,
      "originalPrice": 99.9,
      "currency": "BRL",
      "imageUrl": "https://cdn.example.com/capa.jpg",
      "storeUrl": "https://store.playstation.com/pt-br/product/produto-123",
      "expiresAt": "2026-12-01T02:59:00Z",
      "source": "API regional"
    }
  ]
}
```

Preços são números em reais. `id`, `title`, `currentPrice` e `originalPrice` são obrigatórios. A moeda deve ser BRL quando informada; o padrão é BRL. Os demais campos são opcionais. A plataforma vem da configuração da fonte. O desconto é calculado pelo app; IDs recebem os prefixos `psn_`, `xbox_`, `steam_`, `epic_`, `nuuvem_`, `ubisoft_` ou `ea_`.

Para ofertas Xbox, a API alternativa pode fornecer `xboxCompatibility` com `console`, `playAnywhere`, `windows`, `consoleAndWindows` ou `unknown`. Também são aceitos metadados estruturados como `supportedPlatforms: ["XboxOne", "Windows.Desktop"]` e `isXboxPlayAnywhere: true`. Sem a marcação explícita de XPA, suporte a Xbox e Windows resulta em `consoleAndWindows`. A classificação é persistida nos caches e nas cotações da lista de desejos. A moeda real da resposta deve corresponder à região selecionada.

### Paginação e campanhas sazonais

A consulta inicial busca uma página por loja e continua automaticamente em segundo plano até a última página disponível das fontes selecionadas, incluindo Xbox, PlayStation e lojas de PC. As ofertas chegam progressivamente; não é necessário pressionar **Mostrar mais** para continuar a coleta. Esse botão revela os cartões já carregados e também permite pedir mais resultados. A coleta respeita pausas e limites das APIs, é suspensa fora do primeiro plano e preserva resultados quando uma loja falha. Páginas vazias após os filtros não encerram a coleta se houver cursor seguinte; ciclos de cursores são interrompidos com aviso. APIs alternativas podem retornar `nextCursor` e `total` junto de `deals`; o app envia o cursor seguinte em `cursor=...`. A quantidade escolhida nas configurações limita a exibição, sem descartar as ofertas coletadas. “Todas” exibe todos os resultados já recebidos, respeitando os filtros de desconto, loja e compatibilidade.

A Xbox usa o filtro oficial `Price/0` de promoções, sem restringir a coleta a console ou PC. A PSN usa a categoria regional de ofertas e os cabeçalhos de operação/preflight exigidos por sua API GraphQL. A cobertura é a das páginas públicas disponíveis em cada região, com preços de compra; acesso por assinatura e preços exclusivos de assinantes não são tratados como ofertas públicas de compra.

O modo **Cards compactos** reduz a largura e a altura do card inteiro, além da capa, dos espaços internos e da tipografia. Ele permite mais colunas quando há espaço e também se aplica às telas de campanhas. A altura se adapta à escala de texto para manter preços e compatibilidade legíveis.

Os banners gerais de cada loja abrem uma tela com todas as ofertas disponíveis naquela categoria, incluindo as próximas páginas. Essa tela não aplica o limite de cartões da página inicial nem seus filtros de desconto mínimo ou somente gratuitos. A plataforma prioritária organiza os cartões e os banners iniciais; a ordenação por preço, desconto ou nome continua valendo dentro dessa prioridade.

Campanhas como **Autumn Sale** ou **Halloween** aparecem como banners próprios quando a fonte fornece a campanha vigente e o vínculo dos produtos. O aplicativo não presume datas nem considera que todo jogo de terror participa de Halloween. Sem metadados, aparecem apenas categorias gerais da loja. A integração Steam não descobre automaticamente eventos sazonais; PSN/Xbox dependem da cobertura dos catálogos e dos metadados retornados.

Exemplo de extensão do contrato — as datas são ilustrativas, não um calendário oficial:

```json
{
  "deals": [
    {
      "id": "produto-123",
      "title": "Nome do jogo",
      "currentPrice": 49.9,
      "originalPrice": 99.9,
      "currency": "BRL",
      "campaignIds": ["halloween-2026"]
    }
  ],
  "nextCursor": "pagina-2",
  "total": 240,
  "campaigns": [
    {
      "id": "halloween-2026",
      "title": "Halloween",
      "description": "Ofertas selecionadas para esta campanha",
      "imageUrl": "https://cdn.example.com/halloween.jpg",
      "startsAt": "2026-10-21T00:00:00Z",
      "endsAt": "2026-11-05T00:00:00Z"
    }
  ]
}
```

Ao tocar no banner, o app consulta a mesma API com `campaignId=halloween-2026` e, nas próximas páginas, também com `cursor`. A resposta precisa conter o ID em `campaignIds` de cada oferta, ou confirmar que todo o resultado está filtrado com `"campaignId":"halloween-2026"` na raiz. Produtos sem vínculo não são misturados na categoria. Campanhas futuras, vencidas ou com metadados inválidos não aparecem; início e fim são obrigatórios. APIs sem paginação devem retornar o conjunto completo de resultados em uma resposta.

O catálogo mostra apenas descontos ativos. A busca para adicionar e a consulta individual aceitam preços cheios. Para atualizar um produto pela API alternativa, a busca `q=ID` deve devolver esse mesmo ID. Respostas vazias válidas substituem o snapshot anterior; falhas preservam o cache da consulta correspondente, com aviso visível. O cliente valida preços finitos e não negativos, URLs HTTPS, moeda e validade.

## Adicionar e acompanhar jogos

1. Toque no coração de uma oferta ou em **Adicionar jogo** na lista.
2. Busque nas APIs das lojas selecionadas ou cole o link oficial do produto.
3. Informe, se quiser, um preço desejado e ative os avisos daquele jogo.
4. Salve. O item fica disponível neste dispositivo, mesmo sem conexão.

Ao adicionar por link, nome e URL são obrigatórios. Steam e Xbox permitem extrair o ID e consultar o produto diretamente. Links PSN e Epic dependem da cobertura da API configurada ou de correspondência com uma oferta retornada. O app mostra **Preço ainda não consultado** quando não há cotação; não inventa preços.

O serviço `WishlistService` concentra adição, edição, remoção com opção de desfazer, prevenção de duplicatas, migração da lista anterior, persistência, metas de preço e histórico de avisos. Um jogo pode ter uma entrada por loja. Salvar o mesmo produto novamente preserva a entrada existente.

### Avisos locais

As consultas são feitas com o app em primeiro plano e ao retomá-lo:

- Sem meta, avisa quando o preço fica abaixo do menor preço já observado desde o acompanhamento.
- Com meta, avisa ao atingir ou ficar abaixo do preço desejado.
- O desconto mínimo global e a opção de aviso de cada jogo também são respeitados.
- A mesma cotação não gera avisos repetidos. Os últimos 100 eventos ficam no histórico local.
- Android, iOS e macOS podem exibir notificações nativas após permissão. Nos outros ambientes, consulte o histórico da lista.

**Não existe monitoramento ou push com o app encerrado.** Não há serviço externo para executar essa tarefa. Produtos sem cotação suportada pela API podem ser salvos, mas não terão alertas de preço até que uma cotação seja encontrada.

## Configurações disponíveis

- Seleção de lojas, URLs das APIs e teste individual de cada fonte;
- IDs de produtos Xbox e estado das últimas consultas;
- desconto mínimo, somente gratuitos e ordenação;
- quantidade de promoções individuais por vez e plataforma prioritária;
- avisos globais, som, desconto mínimo para alertar e permissões do sistema;
- tema claro, escuro ou automático, cartões compactos;
- atualização automática e intervalo de 1, 5, 15 ou 30 minutos;
- limpeza do cache, histórico de avisos e exclusão da lista local;
- restauração de preferências, versão e licenças.

As preferências são aplicadas ao salvar. Os botões de salvar ficam fixos na parte inferior das telas de configurações e de adição/edição, inclusive com o teclado aberto. As opções avançadas de API podem ser expandidas por loja. Restaurar padrões preserva a lista e as APIs configuradas. Desmarcar uma loja afeta o catálogo; os jogos dela continuam na lista e podem ser consultados para acompanhamento.

## Organização e otimizações

```text
lib/src/
  app.dart                         # Duas abas, navegação e ciclo de vida
  data/store_providers.dart        # Adaptadores de APIs com transporte injetado
  models/game_deal.dart            # Oferta, plataforma e validação
  models/wishlist_item.dart        # Item salvo, URL, preço desejado e cotação
  models/sale_campaign.dart        # Campanhas vigentes e páginas de ofertas
  services/api_transport.dart      # Orçamento, concorrência, cache HTTP e pausas
  services/deals_api.dart          # Agregação, cache persistente, busca e consulta por ID
  services/wishlist_service.dart   # Lista persistente e avisos locais
  services/notification.dart       # Notificações nativas opcionais
  views/add_wishlist_screen.dart   # Busca, cadastro por link e edição de meta
  views/wishlist_screen.dart       # Lista unificada e histórico de avisos
  views/settings_screen.dart       # Configurações completas
  views/sale_banner.dart           # Banners de loja ou campanha
  views/sale_screen.dart           # Categoria completa com paginação
  views/widgets/deal_card.dart     # Cartão reutilizável e abertura da loja
  views/widgets/app_sidebar.dart   # Drawer adaptativo e navegação por loja
  views/widgets/discovery_hero.dart # Destaque do catálogo com dados reais
  theme/app_theme.dart             # Paleta, tipografia e componentes comuns
  views/widget/app_preferences.dart
```

### Economia de requisições

| Consulta ou proteção | Comportamento |
| --- | --- |
| Catálogo automático | Reaproveita o snapshot por **15 minutos**, inclusive ao voltar ao app |
| Atualização manual | Pode revalidar antes dos 15 minutos, mas respeita **um minuto** desde uma resposta recente |
| Consulta individual | Cache de **30 minutos**, inclusive para produto não encontrado |
| Busca de adição | Mínimo de **3 caracteres**, debounce de **700 ms** e cache HTTP de **5 minutos** para a mesma URL |
| Concorrência | No máximo **duas chamadas de rede simultâneas** em todo o cliente |
| Orçamento local | Até **12 chamadas por host em uma janela móvel de um minuto**, compartilhadas entre catálogo, busca, testes e lista |
| Respostas 429 e 503 | Pausa do host inteiro, respeitando `Retry-After` em segundos ou data HTTP e espera exponencial de 1 a 32 minutos quando necessário |
| Outras falhas | Pausa por URL, começando em 30 segundos e aumentando até 8 minutos; sem repetição automática imediata |
| Lista grande | Até **oito consultas individuais sem cache** e um lote de até **100 jogos Xbox** por ciclo; rodízio dos jogos restantes |

Chamadas simultâneas para a mesma URL compartilham uma resposta. Steam e Epic não perdem seu cache quando apenas a seleção de outra loja ou seus IDs Xbox mudam. Fontes que retornam preços cheios, como Xbox e APIs alternativas, também os reaproveitam na lista; a tela Ofertas mostra apenas descontos. O catálogo Steam é dedicado a promoções; preços cheios continuam disponíveis por consulta individual. A Epic compartilha o cache do catálogo paginado entre consultas equivalentes.

Até 12 snapshots de catálogo com até 500 jogos são persistidos localmente, com limite de 512 KiB para o conjunto serializado, permitindo reaproveitar consultas após reiniciar o app. Em falhas, snapshots de até 24 horas podem aparecer com aviso de desatualização; promoções expiradas são filtradas e o fallback antigo não gera novos avisos. O cache HTTP é limitado a 64 entradas e 8 MiB do conteúdo recebido, com remoção das entradas menos usadas. Cada resposta é limitada a 8 MiB durante o recebimento. As chamadas têm prazo de cancelamento de 20 segundos nos clientes que suportam abortar requisições; também há limites de espera de 15 segundos nos cabeçalhos e entre blocos de dados.

Limpar o cache não remove as pausas após falhas nem o orçamento local. As consultas automáticas param fora do primeiro plano e enquanto as telas de configurações ou adição estão abertas. Salvar apenas o tema, a ordenação ou outro ajuste visual não apaga os preços em cache.

Essas proteções **reduzem o consumo, mas não garantem a cota de um provedor**: os limites reais variam e podem contabilizar outras instalações, outros apps e chamadas anteriores. Contadores e pausas do transporte são locais à sessão; snapshots persistentes sobrevivem ao reinício. Listas grandes são atualizadas gradualmente, sem prometer que todos os produtos foram consultados no mesmo ciclo.

### Telas leves e atualização

O catálogo usa slivers e construção sob demanda, imagens com tamanho de decodificação limitado e filtros locais com debounce. A partir de 1100 px, o app usa um menu lateral fixo, inclusive nas telas internas. Abaixo disso, mantém navegação inferior e menu lateral recolhível: quatro abas nos aplicativos nativos e três na Web, que oculta a Biblioteca. No celular, as campanhas aparecem primeiro; no desktop, o destaque e as campanhas ficam lado a lado quando há espaço. Os temas são reutilizados e a lista só é gravada e notificada quando seus dados mudam. Links do mesmo produto em idiomas ou domínios oficiais alternativos são reconhecidos para evitar duplicatas.

O catálogo mantém as ofertas disponíveis enquanto consulta atualizações, sem spinner no gesto de puxar para atualizar. Na primeira abertura sem cache, aparece uma mensagem estática e a navegação continua acessível. A busca de jogos instalados usa um indicador apenas durante a varredura; ele para antes de mostrar os resultados. Buscas de ofertas mantêm os resultados anteriores até receber a nova resposta e descartam resultados de textos antigos. Os botões de salvar permanecem fixos na parte inferior dos formulários.

### Persistência exclusivamente assíncrona

Configurações, biblioteca, lista de desejos, histórico de avisos e snapshots do catálogo usam **apenas `SharedPreferencesAsync`**. Não há chamadas à API legada `SharedPreferences.getInstance()`, uso de `SharedPreferencesWithCache` ou gravação direta de arquivos para os dados do aplicativo. O estado necessário para renderizar a interface e o cache HTTP continuam em memória.

`PreferencesStore` compartilha uma única inicialização entre os serviços e serializa suas gravações. Essa reutilização não cria cache de valores: as leituras continuam usando a API Async. Falhas temporárias de inicialização liberam uma nova tentativa na mesma sessão. No Android, os novos dados usam o backend padrão DataStore do plugin. A migração lê o arquivo antigo `FlutterSharedPreferences` também pela API Async; nas demais plataformas, lê as chaves antigas com prefixo `flutter.`. Somente chaves conhecidas do GameHub são copiadas. Valores novos existentes têm prioridade, os originais são preservados e a migração só é marcada como concluída após todas as gravações. Esse tratamento segue os [backends e prefixos documentados pelo plugin](https://pub.dev/packages/shared_preferences).

As leituras de inicialização são agrupadas por serviço e solicitam apenas suas chaves. Configurações e biblioteca ignoram gravações sem alterações. O catálogo descarta snapshots pendentes já substituídos por uma versão mais recente e mantém os catálogos recentes que cabem no limite de 512 KiB, em vez de abandonar toda a gravação quando o conjunto cresce demais. A importação de jogos usa conjuntos de identificadores e destinos para evitar duplicatas sem comparar cada entrada com toda a coleção. As listas publicadas são imutáveis e reaproveitadas entre reconstruções da tela.

Falhas de gravação preservam os jogos salvos e permitem tentar novamente; as configurações restauram o último estado confirmado. A tela de avisos não insere objetos de apresentação nos registros persistidos, mantendo o histórico serializável após sua abertura. Tokens e URLs do backend antigo não são usados.

### Componentes e telas

Biblioteca, lista de desejos, campanhas, configurações e adição de jogos compartilham cabeçalhos responsivos com hierarquia de texto, ícones e ações. Biblioteca e lista de desejos têm busca com botão de limpar e estados vazios específicos para buscas sem resultado. Os estados vazios e as seções de configurações usam componentes reutilizáveis. Os cartões da biblioteca se adaptam à escala de texto; os cartões de ofertas permitem quebrar os metadados em linhas. Botões principais têm área mínima de toque de 48 px e a aba ativa recebe maior contraste. Seletores expandem dentro da largura disponível, textos de ajuda podem ocupar mais de uma linha e as ações de salvar permanecem acessíveis na parte inferior dos formulários. Os temas claro e escuro mantêm os destaques verde e azul.

## Verificar

```powershell
dart format --output=none --set-exit-if-changed lib test
dart analyze lib test
flutter test
flutter build web --release
flutter build apk --debug
```

Na revisão visual mais recente, a suíte completa passou com **17 testes**, incluindo migração Async, recuperação de falhas, biblioteca e lista em telas estreitas com texto ampliado, detecção Android, paginação dos catálogos e cards compactos. Os builds Web/APK existentes são anteriores às mudanças mais recentes; compile novamente para incluí-las.

Na revisão da coleta e dos cards compactos, **oito testes passaram**: paginação conjunta Xbox/PSN/PC até o fim, páginas intermediárias sem ofertas, retomada após falha, cursores repetidos, filtro de promoções Xbox e dimensionamento dos cards. Os cards foram verificados em 320 e 1440 px, nos modos normal e compacto, com texto normal e ampliado em 2×. A análise estática passou. As consultas públicas reais confirmaram o filtro Xbox e a primeira página PSN com cursor de continuação; a coleta integral das fontes reais depende da disponibilidade e das pausas dos serviços.

`test/async_storage_and_layout_test.dart` usa o backend assíncrono em memória para persistência e prepara verificações de layout em 320 e 1440 px com texto em escala normal e 2×. Os campos `XboxXPA` e `Attributes/Name: XPA` foram conferidos em resposta pública real do DisplayCatalog na revisão anterior. A descoberta e a abertura de jogos ainda precisam ser testadas em celulares reais; a compilação Web não verifica CORS de cada fonte.

`test/automatic_mobile_scan_test.dart` verifica a detecção automática no Android, a atualização ao voltar ao app, a prevenção de buscas simultâneas e a ausência de importação sem seleção. As três variantes (Android, iOS e Windows) passaram; iOS e Windows não iniciam a varredura automaticamente.




### Identidade visual e acessibilidade

A interface usa superfícies neutras, fundo grafite no tema escuro e fundo claro no tema light, com acentos suaves em verde e azul. Os cabeçalhos são abertos, sem painéis com gradientes; cards e banners não têm brilho ou sombras decorativas. Capas, preços e ações recebem prioridade visual. A tipografia Roboto é incluída localmente, com licença disponível no app. As grades são construídas sob demanda e os movimentos respeitam a preferência de animação reduzida. Os testes cobrem 320, 390 e 1440 px, incluindo texto ampliado. `test/clean_layout_test.dart` gera prévias de componentes com dados de exemplo em `build/qa/` ao executar `flutter test --update-goldens`; elas foram revisadas nos temas claro e escuro.


A Epic utiliza a [API pública EGData](https://docs.egdata.app/docs/offer-search) para promoções pagas. Consultas POST compartilham cache por corpo e página, com os mesmos limites e pausas das outras lojas. Falhas do catálogo não são tratadas como uma lista vazia bem-sucedida.

O tema escuro utiliza fundo grafite, texto claro e destaques suaves em verde e azul.


### Identidade visual e adaptação

Ícone 3D com controle verde e etiqueta azul, aplicado em Android, iOS, Web, Windows, macOS e integração Linux. Fundo preto e texto branco com destaques vibrantes verdes e azuis. A grade compartilhada entre descoberta e campanhas considera o espaço entre cartões, adapta até seis colunas e aumenta a altura com a escala de texto. As capas preservam a imagem anterior durante a troca de URL, sem spinner, e os catálogos mantêm cache durante atualizações.
