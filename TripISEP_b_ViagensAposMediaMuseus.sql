USE TripISEP;
GO

SELECT v.nr_viagem,
       p.data_hora_recolha_passageiro,
       COUNT(*) AS nr_pontos_visitados,
       MIN(CAST(vpt.data_hora_passagem AS TIME(0))) AS primeira_passagem,
       mm.media_hora_museus
FROM Viagem v
JOIN Pedido_Viagem p            ON p.cod_pedido  = v.cod_pedido
JOIN Viagem_Ponto_Turistico vpt ON vpt.nr_viagem = v.nr_viagem
CROSS JOIN (
        SELECT AVG(CAST(DATEDIFF(SECOND, CAST('00:00' AS TIME),
                                         CAST(m.data_hora_passagem AS TIME)) AS DECIMAL(10,2))) AS media_segundos,
               CAST(DATEADD(SECOND,
                            CAST(AVG(CAST(DATEDIFF(SECOND, CAST('00:00' AS TIME),
                                                           CAST(m.data_hora_passagem AS TIME)) AS DECIMAL(10,2))) AS INT),
                            CAST('00:00' AS TIME)) AS TIME(0)) AS media_hora_museus
        FROM Viagem_Ponto_Turistico m
        JOIN Ponto_Turistico pt ON pt.cod_ponto = m.cod_ponto
        WHERE pt.tipo_ponto_turistico = 'MU'
     ) mm
GROUP BY v.nr_viagem, p.data_hora_recolha_passageiro, mm.media_segundos, mm.media_hora_museus
HAVING MIN(DATEDIFF(SECOND, CAST('00:00' AS TIME),
                            CAST(vpt.data_hora_passagem AS TIME))) > mm.media_segundos
ORDER BY v.nr_viagem;