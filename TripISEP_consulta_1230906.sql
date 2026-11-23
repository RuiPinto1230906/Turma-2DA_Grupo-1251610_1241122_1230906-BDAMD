USE TripISEP;
GO

-- Consulta original (1230906): Viagens com atraso de passageiro e distância > 10 km
-- cujo custo total ultrapassa a média de custo do respetivo tipo de serviço.
SELECT v.nr_viagem,
       cl.nome AS nome_cliente,
       ts.descricao AS tipo_servico,
       p.distancia_km,
       v.atraso_passageiro_minutos,
       v.custo_total
FROM Viagem v
JOIN Pedido_Viagem p ON p.cod_pedido = v.cod_pedido
JOIN Tipo_Servico ts ON ts.cod_servico = p.cod_servico
JOIN Cliente cl ON cl.nr_idCivil = p.nr_idCivil_cliente
WHERE p.distancia_km > 10
  AND COALESCE(v.atraso_passageiro_minutos, 0) > 0
  AND v.custo_total > (
      SELECT AVG(v2.custo_total)
      FROM Viagem v2
      JOIN Pedido_Viagem p2 ON p2.cod_pedido = v2.cod_pedido
      WHERE p2.cod_servico = p.cod_servico
  )
ORDER BY v.custo_total DESC;
GO