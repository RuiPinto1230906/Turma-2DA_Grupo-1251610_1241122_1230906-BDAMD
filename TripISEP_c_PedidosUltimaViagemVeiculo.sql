USE TripISEP;
GO

SELECT x.cod_pedido,
       x.matricula,
       x.data_hora_recolha_passageiro,
       x.hora_chegada,
       x.inicio_ultima_viagem_veiculo,
       CONCAT(x.dif / 1440, ' dias ',
              (x.dif % 1440) / 60, ' h ',
              x.dif % 60, ' min') AS intervalo
FROM (
        SELECT p.cod_pedido,
               p.matricula,
               p.data_hora_recolha_passageiro,
               c.hora_chegada,
               u.inicio_ultima_viagem_veiculo,
               DATEDIFF(MINUTE, c.hora_chegada, u.inicio_ultima_viagem_veiculo) AS dif
        FROM Pedido_Viagem p
        JOIN Viagem v ON v.cod_pedido = p.cod_pedido
        CROSS APPLY (SELECT DATEADD(MINUTE,
                                    ISNULL(v.atraso_passageiro_minutos, 0) + v.duracao_minutos,
                                    p.data_hora_recolha_passageiro) AS hora_chegada) c
        CROSS APPLY (SELECT MAX(p2.data_hora_recolha_passageiro) AS inicio_ultima_viagem_veiculo
                     FROM Pedido_Viagem p2
                     JOIN Viagem v2 ON v2.cod_pedido = p2.cod_pedido
                     WHERE p2.matricula = p.matricula) u
        WHERE p.matricula IS NOT NULL
     ) x
WHERE x.dif > 120
ORDER BY x.matricula, x.data_hora_recolha_passageiro;