function [clusteringCoefficients,clusteringCoefficients_Yes] = clustering_coef(adjMatrix,strategyMatrix,Type_DI)
%CLUSTERING_COEF 此处显示有关此函数的摘要
%   此处显示详细说明
degrees = sum(adjMatrix, 2);
clusteringCoefficients = zeros(size(adjMatrix, 1), 1);
clusteringCoefficients_Yes = zeros(size(adjMatrix, 1), 1);

for i = 1:size(adjMatrix, 1)
    neighbors = find(adjMatrix(i, :));
    k = length(neighbors);
    if k < 2
        clusteringCoefficients(i) = 0; % 对于度小于2的节点，聚类系数为0
    else
        triangles = 0; % 初始化形成的三角形数量
        triangles_Yes = 0;
        for j = 1:k
            for m = (j + 1):k
                if adjMatrix(neighbors(j),neighbors(m))
                    triangles = triangles + 1; % 如果邻居节点j和m都相连，则形成一个三角形
%                     if strategyMatrix(i) == 1 && strategyMatrix(j) == 1 && strategyMatrix(m) == 1
                    if strategyMatrix(i) == strategyMatrix(j) && strategyMatrix(i) == strategyMatrix(m) % && Type_DI(i) == T
                        if Type_DI(i) == 2
                        triangles_Yes = triangles_Yes + 1; % 合作且相连的邻居，形成三角形
                        end
                    end
                end
            end
        end
        clusteringCoefficients(i) = 2 * triangles / (degrees(i) * (degrees(i) - 1)); % 计算聚类系数
        clusteringCoefficients_Yes(i) = 2 * triangles_Yes / (degrees(i) * (degrees(i) - 1)); % 合作聚类系数
    end
end
end

