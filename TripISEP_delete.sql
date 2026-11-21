/* =====================================================================
   TripISEP - Limpeza: apaga todos os dados das tabelas (mantém a estrutura)
   Ordem inversa das FK. Os triggers de TripISEP_regras_complexas.sql
   continuam ativos (o R26 só recalcula recibos que ainda existam).
   ===================================================================== */

USE TripISEP;
GO

DELETE FROM Detalhe_Recibo_Viagem;
DELETE FROM Recibo_Comissao;
DELETE FROM Viagem_Ponto_Turistico;
DELETE FROM Fatura_Recibo;
DELETE FROM Viagem;
DELETE FROM Pedido_Viagem;
DELETE FROM Condutor_Veiculo;
DELETE FROM Veiculo;
UPDATE Condutor SET nr_idCivil_supervisor = NULL;   -- FK recursiva
DELETE FROM Condutor;
DELETE FROM Cliente;
DELETE FROM Ponto_Turistico;
DELETE FROM Historico_Custo_Servico;
DELETE FROM Tipo_Servico;
GO
