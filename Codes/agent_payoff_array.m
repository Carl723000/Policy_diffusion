function payoff = agent_payoff_array(featureData, strategy, carbonInfo, ... 
    Analys_mode_2020_model_design, Analys_mode_2020_model_design_var, Analys_mode_2020_model_design_var_type) 
% featureData：节点特征数据
% strategy：节点的策略
% carbonInfo：碳信息，包括碳交易价格、减排成本、减排收益。
% 【可扩展】分别计算各方的，各种策略的收益表达式
% 收益函数计算用到的变量：GDP_100M、Type_DI_GDP、CO2_reduction、Total、CO2_quota
% 数据的顺序：            1           2           3               4       5

if Analys_mode_2020_model_design == 0 ... % 正常运行，不进行敏感性
        || (Analys_mode_2020_model_design == 1 && Analys_mode_2020_model_design_var_type == 0) % 或：敏感性分析————保持现状时 
    
    switch strategy
        % 【策略1-合作】
        case 1 
            % 注意单位：GDP-亿元  CO2排放-万吨
            switch featureData(2) %【两种对比】featureData.Type
                case 1 
                    % 类型1-发达、低排碳；  
                    % 类型1-强解耦，已实现绿色发展，最强管控？ 
                    payoff = featureData(1) + featureData(3)*0.0001*(carbonInfo.benifit + carbonInfo.price - carbonInfo.cost); % Payoff = GDP + 减排收益                  
                case 2 
                    % 类型2-发达、高排碳；   
                    % 类型2-弱解耦，发力点，强处罚管控？
                    payoff = featureData(1) + featureData(3)*0.0001*(carbonInfo.benifit + carbonInfo.price - carbonInfo.cost); % Payoff = GDP + 减碳收益
                case 3 
                    % 类型3-欠发达、低排碳、排污   
                    % 类型3-未解耦-弱依赖，弱管控
                    payoff = featureData(1) + featureData(3)*0.0001*(carbonInfo.benifit + carbonInfo.price*2 - carbonInfo.cost); % Payoff = GDP + 减排收益
                case 4 
                    % 类型4-欠发达、高排碳、排污 
                    % 类型4-未解耦-强依赖，减排奖励
                    payoff = featureData(1) + featureData(3)*0.0001*(carbonInfo.benifit + carbonInfo.price*3 - carbonInfo.cost); % Payoff = GDP + 减排收益
            end
        

        % 【策略2-叛逃】
        case 2
            switch featureData(2) %featureData.Type
                %【测试代码】直接按排放量处罚
                case 1 % 类型1-强解耦，已实现绿色发展，最强管控？ 
                    if featureData(4) < featureData(5)
                         payoff = featureData(1); % Payoff = GDP
                    else
                         payoff = featureData(1) - (featureData(4)-featureData(5))*0.0001*carbonInfo.price*3; %Payoff = GDP - 超排罚款 3倍市场价 
                    end
                case 2 %类型2-弱解耦，发力点，强处罚管控？
                    if featureData(4) < featureData(5)
                         payoff = featureData(1); % Payoff = GDP
                    else
                         payoff = featureData(1) - (featureData(4)-featureData(5))*0.0001*carbonInfo.price*2; %Payoff = GDP - 超排罚款 2倍市场价 
                    end
                case 3 %类型3-未解耦-弱依赖，弱管控
                    if featureData(4) < featureData(5)
                         payoff = featureData(1); % Payoff = GDP
                    else
                         payoff = featureData(1) - (featureData(4)-featureData(5))*0.0001*carbonInfo.price; %Payoff = GDP - 超排罚款 1倍市场价 
                    end
                case 4 %类型4-未解耦-强依赖，仅奖励，不处罚
                    payoff = featureData(1);
            end
    end




else % 进行【—————————————————— 敏感性分析 ——————————————————】时
    % 【其他参数保持不变！！】
    switch Analys_mode_2020_model_design_var
        %【待优化】整合到前面
        
        case 1 % 奖励系数α（合作时）
            if strategy == 1 
                switch Analys_mode_2020_model_design_var_type
                    case 1 % 奖励系数α————统一3倍奖励
                        payoff = featureData(1) + featureData(3)*0.0001*(carbonInfo.benifit + carbonInfo.price*3 - carbonInfo.cost);
                    case 2 % 奖励系数α————统一1倍奖励
                        payoff = featureData(1) + featureData(3)*0.0001*(carbonInfo.benifit + carbonInfo.price - carbonInfo.cost);
                    case 3 % 奖励系数α————统一0倍奖励(无奖励)
                        payoff = featureData(1) + featureData(3)*0.0001*(carbonInfo.benifit                    - carbonInfo.cost);
                end
            else % 叛逃时，按原先的计算
                switch featureData(2) 
                    case 1
                        if featureData(4) < featureData(5)
                            payoff = featureData(1); 
                        else
                            payoff = featureData(1) - (featureData(4)-featureData(5))*0.0001*carbonInfo.price*3; %Payoff = GDP - 超排罚款 3倍市场价
                        end
                    case 2 
                        if featureData(4) < featureData(5)
                            payoff = featureData(1); 
                        else
                            payoff = featureData(1) - (featureData(4)-featureData(5))*0.0001*carbonInfo.price*2; %Payoff = GDP - 超排罚款 2倍市场价
                        end
                    case 3 
                        if featureData(4) < featureData(5)
                            payoff = featureData(1); 
                        else
                            payoff = featureData(1) - (featureData(4)-featureData(5))*0.0001*carbonInfo.price; %Payoff = GDP - 超排罚款 1倍市场价
                        end
                    case 4 
                        payoff = featureData(1);
                end
            end
                    
        
        case 2 % 惩罚系数β（叛逃时）
            if strategy == 2
                switch Analys_mode_2020_model_design_var_type
                    case 1 % 惩罚系数β————统一3倍惩罚
                        if featureData(4) < featureData(5)
                            payoff = featureData(1); 
                        else
                            payoff = featureData(1) - (featureData(4)-featureData(5))*0.0001*carbonInfo.price*3; %Payoff = GDP - 超排罚款 3倍市场价
                            %【0417测试】10倍惩罚
                        end
                    case 2 % 惩罚系数β————统一1倍惩罚
                        if featureData(4) < featureData(5)
                            payoff = featureData(1); 
                        else
                            payoff = featureData(1) - (featureData(4)-featureData(5))*0.0001*carbonInfo.price*1; %Payoff = GDP - 超排罚款 1倍市场价
                            %【0417测试】5倍惩罚
                        end
                    case 3 % 惩罚系数β————统一0倍惩罚(无惩罚)
                        payoff = featureData(1); 
                end
            else % 合作时，计算方法按正常的算
                switch featureData(2)
                    case 1
                        payoff = featureData(1) + featureData(3)*0.0001*(carbonInfo.benifit + carbonInfo.price - carbonInfo.cost); % Payoff = GDP + 减排收益
                    case 2
                        payoff = featureData(1) + featureData(3)*0.0001*(carbonInfo.benifit + carbonInfo.price - carbonInfo.cost); % Payoff = GDP + 减碳收益
                    case 3
                        payoff = featureData(1) + featureData(3)*0.0001*(carbonInfo.benifit + carbonInfo.price*2 - carbonInfo.cost); % Payoff = GDP + 减排收益
                    case 4
                        payoff = featureData(1) + featureData(3)*0.0001*(carbonInfo.benifit + carbonInfo.price*3 - carbonInfo.cost); % Payoff = GDP + 减排收益
                end
            end


       %【注意】减排努力程度、分配系数，在主程序中计算。
       %    其对应payoff的计算函数，跟正常的一致。   
        case {3,4} % 当前减排努力&分配系数
            payoff = featureData(1);
            switch strategy

                case 1 % 【策略1-合作】
                    switch featureData(2)
                        case 1
                            payoff = featureData(1) + featureData(3)*0.0001*(carbonInfo.benifit + carbonInfo.price - carbonInfo.cost); % Payoff = GDP + 减排收益
                        case 2
                            payoff = featureData(1) + featureData(3)*0.0001*(carbonInfo.benifit + carbonInfo.price - carbonInfo.cost); % Payoff = GDP + 减碳收益
                        case 3
                            payoff = featureData(1) + featureData(3)*0.0001*(carbonInfo.benifit + carbonInfo.price*2 - carbonInfo.cost); % Payoff = GDP + 减排收益
                        case 4
                            payoff = featureData(1) + featureData(3)*0.0001*(carbonInfo.benifit + carbonInfo.price*3 - carbonInfo.cost); % Payoff = GDP + 减排收益
                    end

                case 2 % 【策略2-叛逃】
                    switch featureData(2)
                        case 1
                            if featureData(4) < featureData(5)
                                payoff = featureData(1);
                            else
                                payoff = featureData(1) - (featureData(4)-featureData(5))*0.0001*carbonInfo.price*3; %Payoff = GDP - 超排罚款 3倍市场价
                            end
                        case 2
                            if featureData(4) < featureData(5)
                                payoff = featureData(1);
                            else
                                payoff = featureData(1) - (featureData(4)-featureData(5))*0.0001*carbonInfo.price*2; %Payoff = GDP - 超排罚款 2倍市场价
                            end
                        case 3
                            if featureData(4) < featureData(5)
                                payoff = featureData(1);
                            else
                                payoff = featureData(1) - (featureData(4)-featureData(5))*0.0001*carbonInfo.price; %Payoff = GDP - 超排罚款 1倍市场价
                            end
                        case 4
                            payoff = featureData(1);
                    end
            end
    end
end