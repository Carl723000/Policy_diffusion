function [strategy_diffusion] = diffusion(adjmatrix, strategyMatrix, node, game_results_all)
% adjmatrix: 邻接矩阵
% policy: 节点的策略状态（是与否）
% node: 某一个节点
% strategy_diffusion：策略扩散度

% 使用广度优先搜索（BFS）来计算政策传播路径
visited = false(size(adjmatrix, 1), 1);
queue = node; % 从当前城市开始
path = node; %【注意】路径暂未用上
visited(node) = 1;
strategy_diffusion = 0;

while ~isempty(queue)
    % 出队
    current_node = queue(1);
    queue(1) = [];

    % 计算策略行为扩散度
    if strategyMatrix(current_node) == 1 % 仅计算"合作"策略的传播度
        strategy_diffusion = strategy_diffusion + 1;
    end
    
%     game_results_current = game_results_all(current_node, :);
    % 扩展节点-所有相连城市
    for i = 1:size(adjmatrix, 1)
%         game_results_i = game_results_all(i, :);
        if adjmatrix(current_node, i) == 1 ... % 与当前节点相连、邻居
                && visited(i) == 0 ... % 没有搜索过
                && sum(game_results_all(current_node, :) == 1) > sum(game_results_all(i, :) == 1)
%                 && histcounts(game_results_current, 1) > histcounts(game_results_i, 1) % 整个迭代中，当前节点合作的次数更多
%                 && strategyMatrix(i) == strategyMatrix(node) % 与当前节点策略一致
            %【待补充】增加一条：根据策略迭代矩阵game_results，要满足是从初始策略为"是"的节点，扩展到初始为"否"的节点，保证方向性
            % 所以条件应该是？ sum(game_results(node, :)) > sum(game_results(i, :))
            % 增加在函数外部条件控制？？
            visited(i) = 1;
            queue(end+1) = i; % 将找到符合条件的对象，加到顶部
            path(end+1) = i;
        end
    end
    
%     % 扩展节点-邻居
%     for i = 1:size(adjmatrix, 1)
%         if adjmatrix(current_node, i) == 1 ...
%                 && visited(i) == 0
%             visited(i) = 1;
%             queue(end+1) = i;
%         end
%     end
end

end