USE TripISEP;
GO

SELECT c.nr_idCivil, c.nome,
       COUNT(v.nr_viagem)  AS nr_viagens,
       SUM(v.custo_total)  AS total_gasto
FROM Cliente c
JOIN Pedido_Viagem p ON p.nr_idCivil_cliente = c.nr_idCivil
JOIN Viagem v        ON v.cod_pedido = p.cod_pedido
WHERE YEAR(p.data_hora_recolha_passageiro) = YEAR(GETDATE())
  AND p.data_hora_cancelamento IS NULL
GROUP BY c.nr_idCivil, c.nome
HAVING SUM(v.custo_total) > (
        SELECT AVG(t.total)
        FROM (SELECT SUM(v2.custo_total) AS total
              FROM Pedido_Viagem p2
              JOIN Viagem v2 ON v2.cod_pedido = p2.cod_pedido
              WHERE YEAR(p2.data_hora_recolha_passageiro) = YEAR(GETDATE())
              GROUP BY p2.nr_idCivil_cliente) t);