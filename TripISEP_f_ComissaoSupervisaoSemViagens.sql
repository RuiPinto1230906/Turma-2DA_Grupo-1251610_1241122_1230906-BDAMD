USE TripISEP;
GO

-- f) Condutores que não realizaram viagens num determinado ano mas receberam
--    comissões devido à atividade dos seus supervisionados.
--    Alterar @ano para o ano pretendido (por omissão, o ano atual).
DECLARE @ano INT = YEAR(GETDATE());

SELECT c.nr_idCivil,
       c.nome,
       @ano AS ano,
       SUM(r.valor_comissoes_supervisao) AS comissoes_supervisao
FROM Condutor c
JOIN Recibo_Comissao r ON r.nr_idCivil_condutor = c.nr_idCivil
WHERE r.ano_referencia = @ano
  AND r.valor_comissoes_supervisao > 0
  AND NOT EXISTS (SELECT 1
                  FROM Pedido_Viagem p
                  JOIN Viagem v ON v.cod_pedido = p.cod_pedido
                  WHERE p.nr_idCivil_condutor = c.nr_idCivil
                    AND YEAR(p.data_hora_recolha_passageiro) = @ano)
GROUP BY c.nr_idCivil, c.nome
ORDER BY c.nome;
GO
