/* =====================================================================
   TripISEP - Restrições de integridade complexas (SQL Server)
   Executar DEPOIS de TripISEP_create.sql e ANTES do script de inserção
   de dados.

   Restrições que não se conseguem expressar com PK, FK, UNIQUE ou CHECK
   (envolvem várias linhas ou várias tabelas), implementadas com
   views auxiliares e triggers. Erro lançado = 50000 + número da regra.

     R6   supervisor mais velho que o supervisionado           TR_Condutor_R6_R7
     R7   supervisor com carta emitida há mais tempo           TR_Condutor_R6_R7
     R9   veículo só tem um condutor em cada intervalo         TR_CondVeic_R9
     R11  veículo não ultrapassa o limite de km semanal        TR_Pedido_R11
     R12  veículo disponível na data/hora do pedido            TR_Pedido_R12, TR_Viagem_R12
     R13  condutor associado ao veículo e com carta válida     TR_Pedido_R13
     R15  custos do serviço sem sobreposição; pedido com custo TR_Historico_R15, TR_Pedido_R15
     R17  valor do cancelamento conforme o enunciado           TR_Pedido_R17
     R20  viagem coerente com pedido e custos; fatura         TR_Viagem_R20, TR_Pedido_R20, TR_Fatura_R20
     R22  detalhe do recibo coerente com a viagem              TR_Detalhe_R22
     R26  totais do recibo calculados (viagens + supervisão)   TR_Detalhe_R26, TR_Recibo_R26
     R28  passagem por ponto turístico durante a viagem        TR_VPT_R28
   ===================================================================== */

USE TripISEP;
GO

/* =====================================================================
   1. VIEWS AUXILIARES
   ===================================================================== */

-- Intervalo de ocupação de cada pedido não cancelado com veículo:
-- [recolha, recolha + duração da viagem]. Sem viagem, ocupa só a recolha.
CREATE OR ALTER VIEW VW_Pedido_Ocupacao AS
SELECT p.cod_pedido,
       p.matricula,
       p.data_hora_recolha_passageiro AS inicio,
       DATEADD(MINUTE, COALESCE(v.duracao_minutos, 0), p.data_hora_recolha_passageiro) AS fim
FROM Pedido_Viagem p
LEFT JOIN Viagem v ON v.cod_pedido = p.cod_pedido
WHERE p.matricula IS NOT NULL
  AND p.data_hora_cancelamento IS NULL;
GO

-- Viagem + pedido + custos do serviço em vigor na data da viagem.
CREATE OR ALTER VIEW VW_Viagem_Tarifa AS
SELECT v.nr_viagem, v.cod_pedido, v.duracao_minutos, v.atraso_passageiro_minutos,
       v.custo_preco_base, v.custo_duracao, v.custo_distancia, v.custo_espera,
       v.valor_iva, v.custo_total,
       p.cod_servico, p.matricula, p.nr_idCivil_condutor, p.distancia_km,
       p.data_hora_recolha_passageiro, p.data_hora_cancelamento,
       CAST(p.data_hora_recolha_passageiro AS DATE) AS data_viagem,
       h.preco_base, h.custo_minuto, h.custo_km, h.taxa_iva, h.tempo_max_espera,
       h.custo_minuto_espera, h.perc_comissao_condutor, h.perc_comissao_supervisor,
       CASE WHEN h.cod_servico IS NULL THEN 0 ELSE 1 END AS tem_custo_servico
FROM Viagem v
JOIN Pedido_Viagem p ON p.cod_pedido = v.cod_pedido
LEFT JOIN Historico_Custo_Servico h
       ON h.cod_servico = p.cod_servico
      AND CAST(p.data_hora_recolha_passageiro AS DATE) >= h.data_inicio_custo
      AND (h.data_fim_custo IS NULL
           OR CAST(p.data_hora_recolha_passageiro AS DATE) <= h.data_fim_custo);
GO

-- Viagens que violam R20 (a view vazia = dados coerentes).
CREATE OR ALTER VIEW VW_Viagem_Violacao_R20 AS
SELECT t.nr_viagem, t.cod_pedido
FROM VW_Viagem_Tarifa t
CROSS APPLY (SELECT t.preco_base
                    + ROUND(t.custo_minuto * t.duracao_minutos, 2)
                    + ROUND(t.custo_km * t.distancia_km, 2)
                    + ROUND(t.custo_minuto_espera * COALESCE(t.atraso_passageiro_minutos, 0), 2) AS subtotal) s
WHERE t.data_hora_cancelamento IS NOT NULL                       -- pedido cancelado
   OR t.matricula IS NULL                                        -- pedido sem veículo/condutor
   OR t.tem_custo_servico = 0                                    -- sem custos em vigor
   OR COALESCE(t.atraso_passageiro_minutos, 0) > t.tempo_max_espera
   OR ABS(t.custo_preco_base - t.preco_base) > 0.01
   OR ABS(t.custo_duracao  - t.custo_minuto * t.duracao_minutos) > 0.01
   OR ABS(t.custo_distancia - t.custo_km * t.distancia_km) > 0.01
   OR ABS(t.custo_espera   - t.custo_minuto_espera * COALESCE(t.atraso_passageiro_minutos, 0)) > 0.01
   OR ABS(t.valor_iva      - s.subtotal * t.taxa_iva / 100.0) > 0.01;
GO

-- Valores de comissão calculados para cada recibo.
-- Viagens: soma das comissões das viagens do recibo.
-- Supervisão: para cada viagem dos supervisionados no mesmo mês/ano,
--             comissão da viagem * perc_comissao_supervisor do serviço.
CREATE OR ALTER VIEW VW_Recibo_Comissao_Calculado AS
SELECT r.nr_recibo,
       CAST(COALESCE((SELECT SUM(d.valor_comissao)
                      FROM Detalhe_Recibo_Viagem d
                      WHERE d.nr_recibo = r.nr_recibo), 0) AS DECIMAL(10,2)) AS valor_comissoes_viagens,
       CAST(COALESCE((SELECT SUM(ROUND(d.valor_comissao * t.perc_comissao_supervisor / 100.0, 2))
                      FROM Condutor c
                      JOIN Recibo_Comissao rs
                        ON rs.nr_idCivil_condutor = c.nr_idCivil
                       AND rs.mes_referencia = r.mes_referencia
                       AND rs.ano_referencia = r.ano_referencia
                      JOIN Detalhe_Recibo_Viagem d ON d.nr_recibo = rs.nr_recibo
                      JOIN VW_Viagem_Tarifa t ON t.nr_viagem = d.nr_viagem
                      WHERE c.nr_idCivil_supervisor = r.nr_idCivil_condutor), 0) AS DECIMAL(10,2)) AS valor_comissoes_supervisao
FROM Recibo_Comissao r;
GO

/* =====================================================================
   2. TRIGGERS
   ===================================================================== */

-- ---------------------------------------------------------------------
-- R6 / R7  Condutor: o supervisor tem de ser mais velho e ter a carta
--          emitida há mais tempo que o supervisionado
-- ---------------------------------------------------------------------
CREATE OR ALTER TRIGGER TR_Condutor_R6_R7
ON Condutor
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- verifica os pares (supervisionado, supervisor) em que qualquer um foi alterado
    IF EXISTS (SELECT 1
               FROM Condutor c
               JOIN Condutor s ON s.nr_idCivil = c.nr_idCivil_supervisor
               WHERE (c.nr_idCivil IN (SELECT nr_idCivil FROM inserted)
                      OR s.nr_idCivil IN (SELECT nr_idCivil FROM inserted))
                 AND s.data_nascimento >= c.data_nascimento)
    BEGIN
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW 50006, 'R6: o supervisor tem de ser mais velho que o condutor supervisionado.', 1;
    END;

    IF EXISTS (SELECT 1
               FROM Condutor c
               JOIN Condutor s ON s.nr_idCivil = c.nr_idCivil_supervisor
               WHERE (c.nr_idCivil IN (SELECT nr_idCivil FROM inserted)
                      OR s.nr_idCivil IN (SELECT nr_idCivil FROM inserted))
                 AND s.data_emissao_carta >= c.data_emissao_carta)
    BEGIN
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW 50007, 'R7: o supervisor tem de ter a carta de condução emitida há mais tempo que o supervisionado.', 1;
    END;
END;
GO

-- ---------------------------------------------------------------------
-- R9  Condutor_Veiculo: intervalos do mesmo veículo não se sobrepõem
--     (data_hora_fim NULL = intervalo em aberto)
-- ---------------------------------------------------------------------
CREATE OR ALTER TRIGGER TR_CondVeic_R9
ON Condutor_Veiculo
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1
               FROM inserted i
               JOIN Condutor_Veiculo cv
                 ON cv.matricula = i.matricula
                AND cv.data_hora_inicio <> i.data_hora_inicio
               WHERE i.data_hora_inicio < COALESCE(cv.data_hora_fim, CAST('9999-12-31' AS DATETIME2(0)))
                 AND cv.data_hora_inicio < COALESCE(i.data_hora_fim, CAST('9999-12-31' AS DATETIME2(0))))
    BEGIN
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW 50009, 'R9: o veículo já está associado a outro condutor num intervalo que se sobrepõe.', 1;
    END;
END;
GO

-- ---------------------------------------------------------------------
-- R15 Historico_Custo_Servico: períodos do mesmo serviço não se
--     sobrepõem (datas inclusivas; fim NULL = em vigor)
-- ---------------------------------------------------------------------
CREATE OR ALTER TRIGGER TR_Historico_R15
ON Historico_Custo_Servico
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1
               FROM inserted i
               JOIN Historico_Custo_Servico h
                 ON h.cod_servico = i.cod_servico
                AND h.data_inicio_custo <> i.data_inicio_custo
               WHERE i.data_inicio_custo <= COALESCE(h.data_fim_custo, CAST('9999-12-31' AS DATE))
                 AND h.data_inicio_custo <= COALESCE(i.data_fim_custo, CAST('9999-12-31' AS DATE)))
    BEGIN
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW 50015, 'R15: já existe um custo do serviço em vigor num período que se sobrepõe.', 1;
    END;
END;
GO

-- R15 (cont.) Pedido_Viagem: tem de existir custo do serviço em vigor
--     na data de recolha
CREATE OR ALTER TRIGGER TR_Pedido_R15
ON Pedido_Viagem
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1
               FROM inserted i
               WHERE NOT EXISTS (SELECT 1
                                 FROM Historico_Custo_Servico h
                                 WHERE h.cod_servico = i.cod_servico
                                   AND CAST(i.data_hora_recolha_passageiro AS DATE) >= h.data_inicio_custo
                                   AND (h.data_fim_custo IS NULL
                                        OR CAST(i.data_hora_recolha_passageiro AS DATE) <= h.data_fim_custo)))
    BEGIN
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW 50015, 'R15: não existe custo do serviço em vigor na data de recolha do pedido.', 1;
    END;
END;
GO

-- ---------------------------------------------------------------------
-- R11 Pedido_Viagem: km dos pedidos (não cancelados) de um veículo na
--     semana (segunda a domingo) não podem exceder limite_km_semanal
-- ---------------------------------------------------------------------
CREATE OR ALTER TRIGGER TR_Pedido_R11
ON Pedido_Viagem
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM (SELECT DISTINCT i.matricula,
                     DATEADD(DAY,
                             -(DATEDIFF(DAY, CAST('19000101' AS DATE),
                                        CAST(i.data_hora_recolha_passageiro AS DATE)) % 7),
                             CAST(i.data_hora_recolha_passageiro AS DATE)) AS semana_inicio   -- 01-01-1900 foi segunda-feira
              FROM inserted i
              WHERE i.matricula IS NOT NULL
                AND i.data_hora_cancelamento IS NULL) a
        JOIN Veiculo ve ON ve.matricula = a.matricula
        CROSS APPLY (SELECT SUM(p.distancia_km) AS km
                     FROM Pedido_Viagem p
                     WHERE p.matricula = a.matricula
                       AND p.data_hora_cancelamento IS NULL
                       AND CAST(p.data_hora_recolha_passageiro AS DATE) >= a.semana_inicio
                       AND CAST(p.data_hora_recolha_passageiro AS DATE) <  DATEADD(DAY, 7, a.semana_inicio)) s
        WHERE s.km > ve.limite_km_semanal)
    BEGIN
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW 50011, 'R11: o veículo ultrapassa o limite de quilómetros semanal.', 1;
    END;
END;
GO

-- ---------------------------------------------------------------------
-- R12 Pedido_Viagem: veículo disponível (sem outro pedido sobreposto)
-- ---------------------------------------------------------------------
CREATE OR ALTER TRIGGER TR_Pedido_R12
ON Pedido_Viagem
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1
               FROM VW_Pedido_Ocupacao a
               JOIN VW_Pedido_Ocupacao b
                 ON b.matricula = a.matricula
                AND b.cod_pedido <> a.cod_pedido
                AND a.inicio <= b.fim
                AND b.inicio <= a.fim
               WHERE a.cod_pedido IN (SELECT cod_pedido FROM inserted))
    BEGIN
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW 50012, 'R12: o veículo não está disponível na data/hora do pedido.', 1;
    END;
END;
GO

-- R12 (cont.) Viagem: a duração da viagem também ocupa o veículo
CREATE OR ALTER TRIGGER TR_Viagem_R12
ON Viagem
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1
               FROM VW_Pedido_Ocupacao a
               JOIN VW_Pedido_Ocupacao b
                 ON b.matricula = a.matricula
                AND b.cod_pedido <> a.cod_pedido
                AND a.inicio <= b.fim
                AND b.inicio <= a.fim
               WHERE a.cod_pedido IN (SELECT cod_pedido FROM inserted))
    BEGIN
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW 50012, 'R12: a duração da viagem sobrepõe-se a outro pedido do mesmo veículo.', 1;
    END;
END;
GO

-- ---------------------------------------------------------------------
-- R13 Pedido_Viagem: o condutor alocado é o condutor associado ao
--     veículo na hora de recolha e tem a carta de condução válida
-- ---------------------------------------------------------------------
CREATE OR ALTER TRIGGER TR_Pedido_R13
ON Pedido_Viagem
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1
               FROM inserted i
               WHERE i.matricula IS NOT NULL
                 AND (NOT EXISTS (SELECT 1
                                  FROM Condutor_Veiculo cv
                                  WHERE cv.matricula = i.matricula
                                    AND cv.nr_idCivil_condutor = i.nr_idCivil_condutor
                                    AND cv.data_hora_inicio <= i.data_hora_recolha_passageiro
                                    AND i.data_hora_recolha_passageiro < COALESCE(cv.data_hora_fim, CAST('9999-12-31' AS DATETIME2(0))))
                      OR NOT EXISTS (SELECT 1
                                     FROM Condutor c
                                     WHERE c.nr_idCivil = i.nr_idCivil_condutor
                                       AND c.data_validade_carta >= CAST(i.data_hora_recolha_passageiro AS DATE))))
    BEGIN
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW 50013, 'R13: o condutor não está associado ao veículo na hora de recolha ou tem a carta de condução caducada.', 1;
    END;
END;
GO

-- ---------------------------------------------------------------------
-- R17 Pedido_Viagem: valor do cancelamento
--     - cancelamento até 1h antes da recolha: custo_cancelamento
--     - cancelamento posterior: custo_cancelamento + perc_acrescimo
--       sobre o custo da distância (custo_km * distancia_km)
--     - o cancelamento não pode ser posterior à recolha
-- ---------------------------------------------------------------------
CREATE OR ALTER TRIGGER TR_Pedido_R17
ON Pedido_Viagem
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1
               FROM inserted i
               WHERE i.data_hora_cancelamento IS NOT NULL
                 AND i.data_hora_cancelamento > i.data_hora_recolha_passageiro)
    BEGIN
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW 50017, 'R17: o cancelamento não pode ser posterior à hora de recolha do passageiro.', 1;
    END;

    IF EXISTS (SELECT 1
               FROM inserted i
               JOIN Historico_Custo_Servico h
                 ON h.cod_servico = i.cod_servico
                AND CAST(i.data_hora_recolha_passageiro AS DATE) >= h.data_inicio_custo
                AND (h.data_fim_custo IS NULL
                     OR CAST(i.data_hora_recolha_passageiro AS DATE) <= h.data_fim_custo)
               WHERE i.data_hora_cancelamento IS NOT NULL
                 AND ABS(i.valor_cancelamento
                         - (h.custo_cancelamento
                            + CASE WHEN i.data_hora_cancelamento > DATEADD(HOUR, -1, i.data_hora_recolha_passageiro)
                                   THEN h.perc_acrescimo_cancelamento / 100.0 * h.custo_km * i.distancia_km
                                   ELSE 0 END)) > 0.01)
    BEGIN
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW 50017, 'R17: valor_cancelamento não corresponde ao custo de cancelamento do serviço.', 1;
    END;
END;
GO

-- ---------------------------------------------------------------------
-- R20 Viagem: só existe para pedidos não cancelados e com veículo/
--     condutor; custos calculados com os custos do serviço em vigor;
--     atraso não superior ao tempo máximo de espera
-- ---------------------------------------------------------------------
CREATE OR ALTER TRIGGER TR_Viagem_R20
ON Viagem
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1
               FROM VW_Viagem_Violacao_R20 x
               JOIN inserted i ON i.nr_viagem = x.nr_viagem)
    BEGIN
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW 50020, 'R20: viagem incoerente com o pedido (cancelado/sem condutor), com os custos do serviço ou com o tempo máximo de espera.', 1;
    END;
END;
GO

-- R20 (cont.) alterações ao pedido não podem invalidar a viagem existente
CREATE OR ALTER TRIGGER TR_Pedido_R20
ON Pedido_Viagem
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1
               FROM VW_Viagem_Violacao_R20 x
               JOIN inserted i ON i.cod_pedido = x.cod_pedido)
    BEGIN
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW 50020, 'R20: a alteração ao pedido invalida a viagem já registada.', 1;
    END;
END;
GO

-- R20 (cont.) a fatura-recibo é emitida no final da viagem
CREATE OR ALTER TRIGGER TR_Fatura_R20
ON Fatura_Recibo
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1
               FROM inserted i
               JOIN VW_Viagem_Tarifa t ON t.nr_viagem = i.nr_viagem
               WHERE i.data_emissao < t.data_viagem)
    BEGIN
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW 50020, 'R20: a fatura-recibo não pode ser emitida antes da data da viagem.', 1;
    END;
END;
GO

-- ---------------------------------------------------------------------
-- R22 Detalhe_Recibo_Viagem: coerente com a viagem e com o recibo
--     - viagem feita pelo condutor do recibo, no mês/ano do recibo
--     - serviço, custo total e percentagem iguais aos da viagem
--       (perc_comissao_condutor do serviço em vigor)
-- ---------------------------------------------------------------------
CREATE OR ALTER TRIGGER TR_Detalhe_R22
ON Detalhe_Recibo_Viagem
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1
               FROM inserted i
               JOIN Recibo_Comissao r ON r.nr_recibo = i.nr_recibo
               JOIN VW_Viagem_Tarifa t ON t.nr_viagem = i.nr_viagem
               WHERE t.nr_idCivil_condutor IS NULL
                  OR t.nr_idCivil_condutor <> r.nr_idCivil_condutor
                  OR MONTH(t.data_viagem) <> r.mes_referencia
                  OR YEAR(t.data_viagem)  <> r.ano_referencia
                  OR t.cod_servico <> i.cod_servico
                  OR t.custo_total <> i.custo_total_viagem
                  OR t.tem_custo_servico = 0
                  OR t.perc_comissao_condutor <> i.percentagem_aplicada)
    BEGIN
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW 50022, 'R22: detalhe incoerente com a viagem (condutor, mês/ano, serviço, custo total ou percentagem).', 1;
    END;
END;
GO

-- ---------------------------------------------------------------------
-- R26 Recibo_Comissao: totais calculados pela base de dados
--     valor_comissoes_viagens    = soma das comissões das viagens
--     valor_comissoes_supervisao = soma, por viagem dos supervisionados
--                                  no mesmo mês/ano, de comissão *
--                                  perc_comissao_supervisor / 100
--     valor_total_comissoes      = viagens + supervisão
--     (como o recibo é inserido antes dos detalhes, os valores são
--      recalculados sempre que os detalhes mudam)
-- ---------------------------------------------------------------------
CREATE OR ALTER TRIGGER TR_Detalhe_R26
ON Detalhe_Recibo_Viagem
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH Mexidos AS (
        SELECT nr_recibo FROM inserted
        UNION
        SELECT nr_recibo FROM deleted
    ),
    Base AS (
        SELECT r.nr_recibo, r.nr_idCivil_condutor, r.mes_referencia, r.ano_referencia
        FROM Recibo_Comissao r
        JOIN Mexidos m ON m.nr_recibo = r.nr_recibo
    ),
    Afetados AS (
        SELECT nr_recibo FROM Base
        UNION
        SELECT rs.nr_recibo                                  -- recibos dos supervisores
        FROM Base b
        JOIN Condutor c ON c.nr_idCivil = b.nr_idCivil_condutor
        JOIN Recibo_Comissao rs
          ON rs.nr_idCivil_condutor = c.nr_idCivil_supervisor
         AND rs.mes_referencia = b.mes_referencia
         AND rs.ano_referencia = b.ano_referencia
    )
    UPDATE r
    SET valor_comissoes_viagens    = cal.valor_comissoes_viagens,
        valor_comissoes_supervisao = cal.valor_comissoes_supervisao,
        valor_total_comissoes      = cal.valor_comissoes_viagens + cal.valor_comissoes_supervisao
    FROM Recibo_Comissao r
    JOIN Afetados a ON a.nr_recibo = r.nr_recibo
    JOIN VW_Recibo_Comissao_Calculado cal ON cal.nr_recibo = r.nr_recibo;
END;
GO

-- R26 (cont.) recibo inserido depois dos detalhes dos supervisionados
CREATE OR ALTER TRIGGER TR_Recibo_R26
ON Recibo_Comissao
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE r
    SET valor_comissoes_viagens    = cal.valor_comissoes_viagens,
        valor_comissoes_supervisao = cal.valor_comissoes_supervisao,
        valor_total_comissoes      = cal.valor_comissoes_viagens + cal.valor_comissoes_supervisao
    FROM Recibo_Comissao r
    JOIN inserted i ON i.nr_recibo = r.nr_recibo
    JOIN VW_Recibo_Comissao_Calculado cal ON cal.nr_recibo = r.nr_recibo;
END;
GO

-- ---------------------------------------------------------------------
-- R28 Viagem_Ponto_Turistico: a passagem ocorre durante a viagem
--     [recolha, recolha + duração]
-- ---------------------------------------------------------------------
CREATE OR ALTER TRIGGER TR_VPT_R28
ON Viagem_Ponto_Turistico
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1
               FROM inserted i
               JOIN VW_Viagem_Tarifa t ON t.nr_viagem = i.nr_viagem
               WHERE i.data_hora_passagem < t.data_hora_recolha_passageiro
                  OR i.data_hora_passagem > DATEADD(MINUTE, t.duracao_minutos, t.data_hora_recolha_passageiro))
    BEGIN
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW 50028, 'R28: a hora de passagem pelo ponto turístico tem de estar dentro da duração da viagem.', 1;
    END;
END;
GO
