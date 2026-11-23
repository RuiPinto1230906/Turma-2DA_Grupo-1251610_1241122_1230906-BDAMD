# TripISEP – Base de Dados

Trabalho prático de **Bases de Dados e Armazéns de Dados** (Licenciatura em Engenharia de Telecomunicações e Informática – ISEP).

Base de dados em **SQL Server** para a TripISEP, uma empresa de transporte de passageiros do Porto. Guarda a informação dos serviços e respetivos custos, clientes, condutores e supervisores, veículos, pedidos de viagem, viagens, pontos turísticos, faturas e recibos de comissões dos condutores.

## Grupo

| Turma | Números de aluno |
|---|---|
| 2DA | 1251610 · 1241122 · 1230906 |

## Estrutura do repositório

### Parte I – Modelo e base de dados

| Ficheiro | Descrição |
|---|---|
| `TripISEP_Modelo_Relacional.svg` | Modelo relacional (entidades, PK, FK e cardinalidades) |
| `TripISEP_create.sql` | Criação da base de dados, das tabelas e das restrições declarativas (PK, FK, UNIQUE, CHECK) |
| `TripISEP_regras_complexas.sql` | Views e triggers para as restrições que envolvem várias linhas ou tabelas |
| `TripISEP_insert.sql` | Povoamento da base de dados (dados que validam todas as consultas) |
| `TripISEP_delete.sql` | Apaga todos os dados das tabelas, mantendo a estrutura |

### Parte II – Consultas

| Ficheiro | Alínea |
|---|---|
| `TripISEP_a_Top3CondutoresPorServico.sql` | a) Top 3 condutores com maior custo total de viagens, por tipo de serviço |
| `TripISEP_b_ViagensAposMediaMuseus.sql` | b) Viagens com todas as passagens depois da hora média de passagem nos Museus |
| `TripISEP_c_PedidosUltimaViagemVeiculo.sql` | c) Pedidos cujo veículo iniciou a última viagem mais de 2 h após a chegada |
| `TripISEP_d_CustosPorServico.sql` | d) Custo total, % do ano atual e pedidos 80% acima da média, por serviço |
| `TripISEP_e_ViagensAbaixoMediaTop20Supervisor.sql` | e) Viagens abaixo da média das 20% melhores viagens do supervisor |
| `TripISEP_f_ComissaoSupervisaoSemViagens.sql` | f) Condutores sem viagens num ano, mas com comissões de supervisão |
| `TripISEP_g_CondutoresTodosPontosMesmaHora.sql` | g) Viagens por todos os pontos turísticos, sempre à mesma hora |
| `TripISEP_h_CondutoresMesmosPontosTuristicos.sql` | h) Condutores com o mesmo roteiro de pelo menos 5 outros condutores |
| `TripISEP_i_ViagensDiasHorariosUltimos6Meses.sql` | i) Viagens só a terças, quintas, sábados e domingos, das 10 h às 15 h, nos últimos 6 meses |

### Parte III – Consultas originais

| Ficheiro | Autor (n.º de aluno) |
|---|---|
| `TripISEP_consulta_1230906.sql` | 1230906 |
| `TripISEP_consulta_1241122.sql` | 1241122 |
| `TripISEP_consulta_1251610.sql` | 1251610 |

## Como executar

Executar os scripts no SQL Server Management Studio (SSMS), por esta ordem:

1. `TripISEP_create.sql` – cria a base de dados `TripISEP` (se já existir, é apagada e criada de novo)
2. `TripISEP_regras_complexas.sql` – cria as views e os triggers
3. `TripISEP_insert.sql` – insere os dados
4. Qualquer ficheiro de consulta da Parte II ou da Parte III

Para voltar a inserir os dados sem recriar a base de dados, executar `TripISEP_delete.sql` e depois `TripISEP_insert.sql`.

> **Nota:** as alíneas d) e i) usam `GETDATE()` ("ano atual" e "últimos 6 meses"). Os dados foram preparados com a data de referência de 21-11-2026; noutra data, os resultados destas alíneas podem ser diferentes.

## Restrições de integridade

As restrições estão numeradas de **R1 a R28**:

- **R1 a R5** (enunciado) e as restantes restrições declarativas estão em `TripISEP_create.sql` (ver o cabeçalho do ficheiro).
- As restrições que dependem de várias linhas ou tabelas (por exemplo, supervisor mais velho, sobreposição de períodos, limite de km semanal e disponibilidade do veículo) estão em `TripISEP_regras_complexas.sql`. Cada trigger lança o erro `50000 + número da regra`.

A descrição completa de cada restrição e a justificação das decisões tomadas estão no relatório.
