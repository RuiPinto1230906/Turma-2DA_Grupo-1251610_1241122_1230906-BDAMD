/* =====================================================================
   TripISEP - Script de criação da base de dados (SQL Server)
   Baseado no modelo relacional TripISEP_Modelo_Relacional.svg

   Restrições de integridade implementadas neste script (PK, FK, UNIQUE,
   CHECK e NULL/NOT NULL):
     R1  tipo_ponto_turistico IN ('M','MU','PN','MI')       CK_Ponto_tipo
     R2  nr_chassis único                                   UQ_Veiculo_chassis
     R3  nr_carta_conducao único                            UQ_Condutor_carta
     R4  nr_idCivil_supervisor pode ser NULL                coluna NULL
     R5  data_hora_pedido < data_hora_recolha_passageiro    CK_Pedido_datas
     R8  condutor não supervisiona a si próprio             CK_Condutor_auto_supervisao
     R10 data_hora_fim > data_hora_inicio                   CK_CondVeic_datas
     R14 data_fim_custo > data_inicio_custo                 CK_Historico_datas
     R16 cancelamento posterior ao pedido                   CK_Pedido_cancelamento_data
     R18 custo_total = soma das parcelas                    CK_Viagem_custo_total
     R19 valor_comissao = custo * percentagem / 100         CK_Detalhe_comissao
     R21 um recibo por condutor por mês/ano                 UQ_Recibo_condutor_mes
     R23 nif, login, nr_carta_conducao, nr_chassis únicos   UQ_*
     R24 valores, distâncias, durações e % não negativos    CK_*_valores / CK_*_custos
     R25 cliente com idade >= 18 anos                       CK_Cliente_idade
     R27 mes_referencia entre 1 e 12                        CK_Recibo_mes
   ===================================================================== */

USE master;
GO

IF DB_ID('TripISEP') IS NOT NULL
BEGIN
    ALTER DATABASE TripISEP SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE TripISEP;
END;
GO

CREATE DATABASE TripISEP;
GO

USE TripISEP;
GO
/* =====================================================================
   1. TABELAS
   ===================================================================== */

-- ---------------------------------------------------------------------
-- Tipo_Servico
-- ---------------------------------------------------------------------
CREATE TABLE Tipo_Servico (
    cod_servico     INT             NOT NULL,
    descricao       VARCHAR(50)     NOT NULL,

    CONSTRAINT PK_Tipo_Servico PRIMARY KEY (cod_servico),
    CONSTRAINT UQ_Tipo_Servico_descricao UNIQUE (descricao)
);
GO

-- ---------------------------------------------------------------------
-- Historico_Custo_Servico
-- ---------------------------------------------------------------------
CREATE TABLE Historico_Custo_Servico (
    cod_servico                  INT            NOT NULL,
    data_inicio_custo            DATE           NOT NULL,
    data_fim_custo               DATE           NULL,
    preco_base                   DECIMAL(10,2)  NOT NULL,
    custo_minuto                 DECIMAL(10,2)  NOT NULL,
    custo_km                     DECIMAL(10,2)  NOT NULL,
    taxa_iva                     DECIMAL(5,2)   NOT NULL,   -- em %
    tempo_max_espera             INT            NOT NULL,   -- minutos
    custo_minuto_espera          DECIMAL(10,2)  NOT NULL,
    custo_cancelamento           DECIMAL(10,2)  NOT NULL,
    perc_acrescimo_cancelamento  DECIMAL(5,2)   NOT NULL,   -- em %
    perc_comissao_condutor       DECIMAL(5,2)   NOT NULL,   -- em %
    perc_comissao_supervisor     DECIMAL(5,2)   NOT NULL,   -- em %

    CONSTRAINT PK_Historico_Custo_Servico PRIMARY KEY (cod_servico, data_inicio_custo),
    CONSTRAINT FK_Historico_Tipo_Servico FOREIGN KEY (cod_servico)
        REFERENCES Tipo_Servico (cod_servico),

    -- R14 (parte simples): fim posterior ao início
    CONSTRAINT CK_Historico_datas CHECK (data_fim_custo IS NULL OR data_fim_custo > data_inicio_custo),
    -- R24
    CONSTRAINT CK_Historico_valores CHECK (
        preco_base >= 0 AND custo_minuto >= 0 AND custo_km >= 0
        AND tempo_max_espera >= 0 AND custo_minuto_espera >= 0
        AND custo_cancelamento >= 0),
    CONSTRAINT CK_Historico_percentagens CHECK (
        taxa_iva BETWEEN 0 AND 100
        AND perc_acrescimo_cancelamento BETWEEN 0 AND 100
        AND perc_comissao_condutor BETWEEN 0 AND 100
        AND perc_comissao_supervisor BETWEEN 0 AND 100)
);
GO

-- ---------------------------------------------------------------------
-- Cliente
-- ---------------------------------------------------------------------
CREATE TABLE Cliente (
    nr_idCivil       CHAR(8)        NOT NULL,
    nome             VARCHAR(100)   NOT NULL,
    nif              CHAR(9)        NOT NULL,
    data_nascimento  DATE           NOT NULL,
    login            VARCHAR(50)    NOT NULL,
    password         VARCHAR(255)   NOT NULL,   -- guardar hash, não texto simples

    CONSTRAINT PK_Cliente PRIMARY KEY (nr_idCivil),
    CONSTRAINT UQ_Cliente_nif   UNIQUE (nif),     -- R23
    CONSTRAINT UQ_Cliente_login UNIQUE (login),   -- R23

    CONSTRAINT CK_Cliente_idCivil CHECK (nr_idCivil NOT LIKE '%[^0-9]%'),
    CONSTRAINT CK_Cliente_nif     CHECK (nif NOT LIKE '%[^0-9]%'),
    -- R25
    CONSTRAINT CK_Cliente_idade   CHECK (data_nascimento <= DATEADD(YEAR, -18, CAST(GETDATE() AS DATE)))
);
GO

-- ---------------------------------------------------------------------
-- Condutor
-- ---------------------------------------------------------------------
CREATE TABLE Condutor (
    nr_idCivil             CHAR(8)        NOT NULL,
    nome                   VARCHAR(100)   NOT NULL,
    morada                 VARCHAR(200)   NOT NULL,
    nif                    CHAR(9)        NOT NULL,
    data_nascimento        DATE           NOT NULL,
    nr_carta_conducao      VARCHAR(15)    NOT NULL,
    data_emissao_carta     DATE           NOT NULL,
    data_validade_carta    DATE           NOT NULL,
    nr_idCivil_supervisor  CHAR(8)        NULL,       -- R4

    CONSTRAINT PK_Condutor PRIMARY KEY (nr_idCivil),
    CONSTRAINT UQ_Condutor_nif   UNIQUE (nif),                -- R23
    CONSTRAINT UQ_Condutor_carta UNIQUE (nr_carta_conducao),  -- R3
    CONSTRAINT FK_Condutor_Supervisor FOREIGN KEY (nr_idCivil_supervisor)
        REFERENCES Condutor (nr_idCivil),

    CONSTRAINT CK_Condutor_idCivil CHECK (nr_idCivil NOT LIKE '%[^0-9]%'),
    CONSTRAINT CK_Condutor_nif     CHECK (nif NOT LIKE '%[^0-9]%'),
    -- R8
    CONSTRAINT CK_Condutor_auto_supervisao CHECK (nr_idCivil_supervisor IS NULL OR nr_idCivil_supervisor <> nr_idCivil),
    CONSTRAINT CK_Condutor_carta_datas CHECK (data_validade_carta > data_emissao_carta),
    -- só pode ter carta com 18 anos ou mais
    CONSTRAINT CK_Condutor_idade_carta CHECK (data_emissao_carta >= DATEADD(YEAR, 18, data_nascimento))
);
GO

-- ---------------------------------------------------------------------
-- Veiculo
-- ---------------------------------------------------------------------
CREATE TABLE Veiculo (
    matricula          CHAR(8)        NOT NULL,    -- formato AA-00-AA
    marca              VARCHAR(50)    NOT NULL,
    modelo             VARCHAR(50)    NOT NULL,
    nr_chassis         CHAR(17)       NOT NULL,    -- VIN
    data_matricula     DATE           NOT NULL,
    limite_km_semanal  DECIMAL(8,2)   NOT NULL,

    CONSTRAINT PK_Veiculo PRIMARY KEY (matricula),
    CONSTRAINT UQ_Veiculo_chassis UNIQUE (nr_chassis),   -- R2

    CONSTRAINT CK_Veiculo_matricula CHECK (matricula LIKE '[A-Z0-9][A-Z0-9]-[A-Z0-9][A-Z0-9]-[A-Z0-9][A-Z0-9]'),
    CONSTRAINT CK_Veiculo_limite_km CHECK (limite_km_semanal > 0)   -- R24
);
GO

-- ---------------------------------------------------------------------
-- Condutor_Veiculo
-- ---------------------------------------------------------------------
CREATE TABLE Condutor_Veiculo (
    matricula            CHAR(8)       NOT NULL,
    data_hora_inicio     DATETIME2(0)  NOT NULL,
    nr_idCivil_condutor  CHAR(8)       NOT NULL,
    data_hora_fim        DATETIME2(0)  NULL,

    CONSTRAINT PK_Condutor_Veiculo PRIMARY KEY (matricula, data_hora_inicio),
    CONSTRAINT FK_CondVeic_Veiculo  FOREIGN KEY (matricula)
        REFERENCES Veiculo (matricula),
    CONSTRAINT FK_CondVeic_Condutor FOREIGN KEY (nr_idCivil_condutor)
        REFERENCES Condutor (nr_idCivil),

    -- R10
    CONSTRAINT CK_CondVeic_datas CHECK (data_hora_fim IS NULL OR data_hora_fim > data_hora_inicio)
);
GO

-- ---------------------------------------------------------------------
-- Pedido_Viagem
-- ---------------------------------------------------------------------
CREATE TABLE Pedido_Viagem (
    cod_pedido                    INT            NOT NULL,
    nr_idCivil_cliente            CHAR(8)        NOT NULL,
    cod_servico                   INT            NOT NULL,
    matricula                     CHAR(8)        NULL,
    nr_idCivil_condutor           CHAR(8)        NULL,
    data_hora_pedido              DATETIME2(0)   NOT NULL,
    data_hora_recolha_passageiro  DATETIME2(0)   NOT NULL,
    local_inicio                  VARCHAR(200)   NOT NULL,
    distancia_km                  DECIMAL(8,2)   NOT NULL,
    data_hora_cancelamento        DATETIME2(0)   NULL,
    valor_cancelamento            DECIMAL(10,2)  NULL,

    CONSTRAINT PK_Pedido_Viagem PRIMARY KEY (cod_pedido),
    CONSTRAINT FK_Pedido_Cliente  FOREIGN KEY (nr_idCivil_cliente)
        REFERENCES Cliente (nr_idCivil),
    CONSTRAINT FK_Pedido_Servico  FOREIGN KEY (cod_servico)
        REFERENCES Tipo_Servico (cod_servico),
    CONSTRAINT FK_Pedido_Veiculo  FOREIGN KEY (matricula)
        REFERENCES Veiculo (matricula),
    CONSTRAINT FK_Pedido_Condutor FOREIGN KEY (nr_idCivil_condutor)
        REFERENCES Condutor (nr_idCivil),

    -- R5
    CONSTRAINT CK_Pedido_datas CHECK (data_hora_pedido < data_hora_recolha_passageiro),
    -- veículo e condutor são alocados em conjunto
    CONSTRAINT CK_Pedido_alocacao CHECK (
        (matricula IS NULL AND nr_idCivil_condutor IS NULL)
        OR (matricula IS NOT NULL AND nr_idCivil_condutor IS NOT NULL)),
    -- R16 (parte simples): cancelamento posterior ao pedido
    CONSTRAINT CK_Pedido_cancelamento_data CHECK (
        data_hora_cancelamento IS NULL OR data_hora_cancelamento > data_hora_pedido),
    -- cancelamento e valor de cancelamento existem em conjunto
    CONSTRAINT CK_Pedido_cancelamento_valor CHECK (
        (data_hora_cancelamento IS NULL AND valor_cancelamento IS NULL)
        OR (data_hora_cancelamento IS NOT NULL AND valor_cancelamento IS NOT NULL)),
    -- R24
    CONSTRAINT CK_Pedido_distancia CHECK (distancia_km > 0),
    CONSTRAINT CK_Pedido_valor_cancel CHECK (valor_cancelamento IS NULL OR valor_cancelamento >= 0)
);
GO

-- ---------------------------------------------------------------------
-- Viagem
-- ---------------------------------------------------------------------
CREATE TABLE Viagem (
    nr_viagem                  INT            NOT NULL,
    cod_pedido                 INT            NOT NULL,
    duracao_minutos            INT            NOT NULL,
    atraso_passageiro_minutos  INT            NULL,
    custo_preco_base           DECIMAL(10,2)  NOT NULL,
    custo_duracao              DECIMAL(10,2)  NOT NULL,
    custo_distancia            DECIMAL(10,2)  NOT NULL,
    custo_espera               DECIMAL(10,2)  NOT NULL,
    valor_iva                  DECIMAL(10,2)  NOT NULL,
    custo_total                DECIMAL(10,2)  NOT NULL,

    CONSTRAINT PK_Viagem PRIMARY KEY (nr_viagem),
    CONSTRAINT UQ_Viagem_pedido UNIQUE (cod_pedido),   -- relação 1 : 0..1
    CONSTRAINT FK_Viagem_Pedido FOREIGN KEY (cod_pedido)
        REFERENCES Pedido_Viagem (cod_pedido),

    -- R24
    CONSTRAINT CK_Viagem_tempos CHECK (
        duracao_minutos > 0
        AND (atraso_passageiro_minutos IS NULL OR atraso_passageiro_minutos >= 0)),
    CONSTRAINT CK_Viagem_custos CHECK (
        custo_preco_base >= 0 AND custo_duracao >= 0 AND custo_distancia >= 0
        AND custo_espera >= 0 AND valor_iva >= 0),
    -- R18
    CONSTRAINT CK_Viagem_custo_total CHECK (
        custo_total = custo_preco_base + custo_duracao + custo_distancia + custo_espera + valor_iva)
);
GO

-- ---------------------------------------------------------------------
-- Fatura_Recibo
-- ---------------------------------------------------------------------
CREATE TABLE Fatura_Recibo (
    nr_fatura     INT    NOT NULL,
    nr_viagem     INT    NOT NULL,
    data_emissao  DATE   NOT NULL,

    CONSTRAINT PK_Fatura_Recibo PRIMARY KEY (nr_fatura),
    CONSTRAINT UQ_Fatura_viagem UNIQUE (nr_viagem),    -- relação 1 : 1
    CONSTRAINT FK_Fatura_Viagem FOREIGN KEY (nr_viagem)
        REFERENCES Viagem (nr_viagem)
);
GO

-- ---------------------------------------------------------------------
-- Ponto_Turistico
-- ---------------------------------------------------------------------
CREATE TABLE Ponto_Turistico (
    cod_ponto             INT           NOT NULL,
    nome                  VARCHAR(100)  NOT NULL,
    tipo_ponto_turistico  VARCHAR(2)    NOT NULL,

    CONSTRAINT PK_Ponto_Turistico PRIMARY KEY (cod_ponto),
    -- R1
    CONSTRAINT CK_Ponto_tipo CHECK (tipo_ponto_turistico IN ('M', 'MU', 'PN', 'MI'))
);
GO

-- ---------------------------------------------------------------------
-- Viagem_Ponto_Turistico
-- ---------------------------------------------------------------------
CREATE TABLE Viagem_Ponto_Turistico (
    nr_viagem           INT           NOT NULL,
    cod_ponto           INT           NOT NULL,
    data_hora_passagem  DATETIME2(0)  NOT NULL,

    CONSTRAINT PK_Viagem_Ponto_Turistico PRIMARY KEY (nr_viagem, cod_ponto, data_hora_passagem),
    CONSTRAINT FK_VPT_Viagem FOREIGN KEY (nr_viagem)
        REFERENCES Viagem (nr_viagem),
    CONSTRAINT FK_VPT_Ponto  FOREIGN KEY (cod_ponto)
        REFERENCES Ponto_Turistico (cod_ponto)
);
GO

-- ---------------------------------------------------------------------
-- Recibo_Comissao
-- ---------------------------------------------------------------------
CREATE TABLE Recibo_Comissao (
    nr_recibo                   INT            NOT NULL,
    nr_idCivil_condutor         CHAR(8)        NOT NULL,
    data_emissao                DATE           NOT NULL,
    mes_referencia              TINYINT        NOT NULL,
    ano_referencia              SMALLINT       NOT NULL,
    valor_comissoes_viagens     DECIMAL(10,2)  NOT NULL DEFAULT 0,
    valor_comissoes_supervisao  DECIMAL(10,2)  NOT NULL DEFAULT 0,
    valor_total_comissoes       DECIMAL(10,2)  NOT NULL,

    CONSTRAINT PK_Recibo_Comissao PRIMARY KEY (nr_recibo),
    CONSTRAINT FK_Recibo_Condutor FOREIGN KEY (nr_idCivil_condutor)
        REFERENCES Condutor (nr_idCivil),
    -- R21
    CONSTRAINT UQ_Recibo_condutor_mes UNIQUE (nr_idCivil_condutor, mes_referencia, ano_referencia),

    -- R27
    CONSTRAINT CK_Recibo_mes CHECK (mes_referencia BETWEEN 1 AND 12),
    CONSTRAINT CK_Recibo_ano CHECK (ano_referencia >= 2000),
    -- o recibo só é emitido depois do mês a que diz respeito
    CONSTRAINT CK_Recibo_emissao CHECK (
        data_emissao >= DATEADD(MONTH, 1, DATEFROMPARTS(ano_referencia, mes_referencia, 1))),
    -- R24
    CONSTRAINT CK_Recibo_valores CHECK (valor_comissoes_viagens >= 0 AND valor_comissoes_supervisao >= 0),
    CONSTRAINT CK_Recibo_total CHECK (
        valor_total_comissoes = valor_comissoes_viagens + valor_comissoes_supervisao)
);
GO

-- ---------------------------------------------------------------------
-- Detalhe_Recibo_Viagem
-- ---------------------------------------------------------------------
CREATE TABLE Detalhe_Recibo_Viagem (
    nr_viagem             INT            NOT NULL,
    nr_recibo             INT            NOT NULL,
    cod_servico           INT            NOT NULL,
    custo_total_viagem    DECIMAL(10,2)  NOT NULL,
    percentagem_aplicada  DECIMAL(5,2)   NOT NULL,
    valor_comissao        DECIMAL(10,2)  NOT NULL,

    CONSTRAINT PK_Detalhe_Recibo_Viagem PRIMARY KEY (nr_viagem),
    CONSTRAINT FK_Detalhe_Viagem  FOREIGN KEY (nr_viagem)
        REFERENCES Viagem (nr_viagem),
    CONSTRAINT FK_Detalhe_Recibo  FOREIGN KEY (nr_recibo)
        REFERENCES Recibo_Comissao (nr_recibo),
    CONSTRAINT FK_Detalhe_Servico FOREIGN KEY (cod_servico)
        REFERENCES Tipo_Servico (cod_servico),

    -- R24
    CONSTRAINT CK_Detalhe_valores CHECK (
        custo_total_viagem >= 0 AND valor_comissao >= 0
        AND percentagem_aplicada BETWEEN 0 AND 100),
    -- R19 (tolerância de 1 cêntimo para arredondamentos)
    CONSTRAINT CK_Detalhe_comissao CHECK (
        ABS(valor_comissao - custo_total_viagem * percentagem_aplicada / 100) <= 0.01)
);
GO