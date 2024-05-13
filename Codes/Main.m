%%

%% 初始化运行参数
clear; clc; % close all;

currentPath = fileparts(matlab.desktop.editor.getActiveFilename);
parentPath = fullfile(currentPath, '..');
disp(currentPath);
cd(currentPath);
userpath(currentPath);
addpath(genpath("Toolbox\ComDetTBv090")); % Community Detection Toolbox
addpath("Toolbox\GrTheory"); % Graph Theory Toolbox
addpath("Toolbox\toolbox_graph"); % Toolbox Graph
addpath("Toolbox\github_repo");
addpath("Toolbox\B-A");

% 基本参数
filename = 'Data.xlsx';
target_variables = {'Code', 'City','Year', 'Longitude', 'Latitude', 'Permanent_population_10K','GDP_100M', ...
            'Total', 'Per_capita_emissions', 'CO2_emissions_per_GDP', 'DI_POP', 'DI_GDP',...
            'Value_added_2nd_industry', 'Expenditure_general_budget', 'Total_fixed_assets_investment',...
            'Integrity'}; 

% 调试参数
numIterations = 50; % 迭代次数
pause_second = 0.01; % 演化过程图片停留秒数
threshold_distance = 200; %【调试】目前仅根据地理距离是否超过200km判断连接性
total_carbon_quota = 120*10000; % 设2025年总配额为120亿吨


% 【重要参数————碳价格！！！】
carbonInfo.price = 70;  % 中国碳交易市场价格，70元/吨；美国13美元 欧洲86美元; 70 (100) 140 560 1803;1000
carbonInfo.cost = 2189; % 边际减排成本2189元/吨，董金池ES&T；强碳中和情景1803元/吨
carbonInfo.benifit = round(56*7.3); % 2020年SSC为51$（3%折现率）2025为56

% 分析模式控制参数，按组合生成不同图片。
year = 2020;
iteration_figures = 1; % 是否进行多次迭代绘图 默认0-否，论文需要1-是
                      
iteration_figures_Main_max = 100; % 默认为1不循环（建议至少100次起）；
                                
Analys_mode_2020 = 1;   % 基于2020排放数据的分析模式：1-2020策略 2-2021策略 3-2022策略 4-2023策略 5-2023试点"优良"城市 
                        %  0——反事实地随机生成n个；-1——反事实-2023政策前移

% 【——————————————开始分析前，优先调整此处的模式！！！————————————————】
Analys_mode_2020_counterfacutal = 0;    % 是否进行反事实情景分析，默认进行。 
Analys_mode_2020_carbonPrice = 0;           % [参数图]是否进行"碳价格"参数分析————并储存结果（仅限2020年） 默认为1；调试时为0
Analys_mode_2020_model_design = 1;          % [参数图]是否进行模型敏感性分析（仅限2020年）默认为0-否；调试时为1-是 

% 敏感性分析时，修改这里即可！！
Analys_mode_2020_model_design_var = 2;      % [要进行敏感性分析的变量] 1-奖励系数 2-惩罚系数 3-实际减排 4-当前分配系数
Analys_mode_2020_model_design_var_type = 0; % [基于上,组合使用] 0-正常参数 1-统一3倍激励/惩罚 2-统一1倍 3-统一无……;
                                            % 当前实际减排／统一［0.7, 1］／统一［0.5, 1］/ 统一 [0, 1]（可解释为政策约束）
                                            % 当前分配系数 /统一110%／统一100％／统一90％（通过碳配额进行约束）
Analys_mode_counterfactual = 4;             % 基于2010/2015数据的，反事实情景：0-随机初始策略 1-无试点无赏罚 2-有试点无赏罚 3-有试点有赏罚 4-当前的试点政策前移。

Analys_mode_description = 0;          % 是否进行【描述性统计】
Analys_mode_dynamicDiffusion = 0;     % 是否动态展示网络演化过程，默认为1。仅限2020随机生成时为0，提高速度。
Counterfactual_percentage = 0.02;     % 反事实情景1~3的初始化合作概率。

CO2_reduction_mode = 1; % 碳减排能力模式：1-单位GDP下降(2025十四五目标) 2-单位GDP下降(2030达峰目标)
fermi = true;%true;   % 是否按费米规则【注意】迭代次数也要增加
fermi_k = 3000;       % 费米函数-噪声参数，代表个体随机性。噪声越高越随机/非理性（概率0.5）；噪声越低，越确定/理性
                      % 【注意】用来调整单位范围,几十更好？【找依据！】参数范围（收益-几万(亿元)，按3000比较合适）
neighbor_rand = 1;    % 是否随机选择邻居（与费米规则组合使用）
neighbor_rand_threshold = 0.6; % 随机选择邻居的百分比（至少会考虑一个邻居的收益）
neighbor_rand_seed = 0;        % 随机选择邻居时，是否固定种子

gravity_mode = 3;  % 重力模型模式： 0-地理阈值 1-人口+距离 2-人口+GDP+距离 3-人口+GDP+碳排放+距离 4、DI指数 -1=无需输出连接性
lonelyCity = 0;    % 孤立城市是否随机考虑以纳入网络（仅限邻居决策模式中）？

strategy_mode = 1;   % 默认决策规则（正常不要调此值，仅调试时为0）：1-盲从邻居。2-自己完全理性，无交互（一次迭代就完成）
strategy_mode_mixed = 1;  % 是否混合策略。随机二选一：0-完全理性决策，无交互 vs 1-最高收益邻居
strategy_mode_mixed_threshold = 0.05;  % 混合决策时，完全理性的概率阈值【论文注意！】会带来随机性，稳定所需的迭代次数不一致，应多次计算作为敏感性分析。
% strategy_mode_mixed_seed = 0; % 目前没用上。混合决策时，是否固定种子

community_detection_mode = 1; % 社区检测模式

color_Yes = [0.9272 0.7298 0.1973];
color_No = [0.2422 0.1504 0.6603];
color_Tpye1 = "#008d00"; color_Tpye1_rgb = [0 141 0]/255;
color_Tpye2 = "#ff9200"; color_Tpye2_rgb = [255 146 0]/255;
color_Tpye3 = "#e5086a"; color_Tpye3_rgb = [229 8 106]/255;
color_Tpye4 = "#cfb99e"; color_Tpye4_rgb = [207 185 158]/255;
quota_mode = 1;     % 碳配额模式：1-历史排放+DI，110%/100%/95%/90%


debug_values_CarbonPrice = [70, 100, 140, 560, 1803]; %正常分析时，去掉这行，自己按需求输出
debug_values_modelDesign_type = [0 1 2 3];
debug_values_Counterfacutal = [1 0 -1]; %Analys_mode_2020的几种模式:基线、基线随机、2023政策提前
excel_output = 0;       % 结果输出Excel，默认为1输出，调试为0不输出节约时间
rng_shuffle_model = 0;  % 当前时间随机种子，默认为1，调试为0优化代码？
draw_realtime = 0; %默认为0，后续自动改数值

% 【0414】便于调参时，自动输出结果
outputData_carbonPrice = struct();
outputData_matrix = struct();
outputData_counterfactual = struct();
outputData_modelDesign = struct();



%% 主程序————网络演化

if Analys_mode_2020_counterfacutal == 0 ||...
        Analys_mode_2020_carbonPrice == 0 ||...        % [参数图]是否进行"碳价格"参数分析————并储存结果（仅限2020年） 默认为1；调试时为0
        Analys_mode_2020_model_design == 0
    debug_mode = 1;         % [0414]调试专用，默认为1，无需修改。每次将一个参数的多个值，整合为一张图
end

if debug_mode == 1 %【0414】若进行调试[0415]默认为1，必然执行
    
    if Analys_mode_2020_carbonPrice == 1
        debug_values = debug_values_CarbonPrice;        
    elseif Analys_mode_2020_model_design == 1
        debug_values = debug_values_modelDesign_type;
    elseif Analys_mode_2020_counterfacutal == 1 % 进行反事实情景分析时
        debug_values = debug_values_Counterfacutal; %【反事实情景】不执行下面的for循环
    else
        draw_realtime = 1; %不调试时，就出实时DI分类图
        debug_values = 1;  %不执行下面的for循环 %【0414批注】这种方法无效
    end

end

% 【0414循环自动出图】
iteration_debug = 0;
%【0414待优化】控制整个大循环，因为1次大循环时，无法用for实现。解决方法————————注释这个for循环
for debug_var = debug_values %【——————————————————敏感性分析，大循环————————————————————————】
iteration_debug = iteration_debug + 1;
% 【0414】待完成，实时输出


if debug_mode == 1 && Analys_mode_2020_carbonPrice == 1
    carbonInfo.price = debug_var; % 300次534秒；200次544秒≈9分钟； 100次192秒≈3分钟
elseif debug_mode == 1 && Analys_mode_2020_model_design == 1
    Analys_mode_2020_model_design_var_type = debug_var; 
    
    %【注意，需要在第一节手动调要进行敏感性分析的变量！！】
    % Analys_mode_2020_model_design_var = 1;  
    % 1-奖励系数：70元（50次80秒；100次157秒）1803元（100次 158秒）
    % 2-惩罚系数 50次89秒
    % 3-实际减排 
    % 4-当前分配系数
elseif debug_mode == 1 && Analys_mode_2020_counterfacutal == 1
    Analys_mode_2020 = debug_var; %
end

% 【思路1.1】根据经纬度，直接计算邻接矩阵
dataPath = fullfile(parentPath, 'Data');
cd(dataPath); % userpath(dataPath);


% 数据读取
[featureData,adjMatrix,connectivity] = Input_adjacency(filename, target_variables, threshold_distance, year, gravity_mode);
numAgents = length(featureData.City);
disp(['Number of cities involved is: ', num2str(numAgents)]);



%【假设/找依据】 ，城市的分类
% 方式1-根据 总GDP 和 总CO2排放 分类。【可尝试】考虑按人均再试试？追求人均意义的均等
GDP_threshold = median(featureData.GDP_100M);
CO2_threshold = median(featureData.Total);
featureData.Type(featureData.GDP_100M > GDP_threshold & featureData.Total <= CO2_threshold) = 1; % 发达，低CO2排放，已达峰（北上广深）
featureData.Type(featureData.GDP_100M > GDP_threshold & featureData.Total > CO2_threshold) =  2; % 发达，高CO2排放，快要达峰（唐山、德州）
featureData.Type(featureData.GDP_100M <= GDP_threshold & featureData.Total <= CO2_threshold) = 3; % 欠发达，低CO2排放，更远期达峰，技术升级/平衡发展可调控（榆林、鄂尔多斯、吕梁）
featureData.Type(featureData.GDP_100M <= GDP_threshold & featureData.Total > CO2_threshold) = 4; % 欠发达，高CO2排放，多年后达峰（廊坊、洛阳）

% 方式2-脱钩/解耦指数（decoupling index）DI=(△GDP-△CO2)/△GDP 参考刘竹论文2022 science bulletin
% 横坐标：△GDP或△人口    纵坐标：△CO2    四个象限，不同HI范围，对应不同的状态。其中：
% DI < 0：同为正-未脱钩，在发展（重工业能源密集，唐山、德州） 同为负-未脱钩，已经衰退（采矿为主的能源，陕西榆林、鄂尔多斯、山西吕梁）
% 0< DI <1：【思考，政策发力点？】 同为正-弱解耦/将脱钩，潜力股/有自发动力？  同为负-隐性弱解耦，经济衰退、排放降低
% DI > 1： GDP正 CO2负，强脱钩已实现低碳发展（北京上海深圳）； GDP负 CO2正，强脱钩，经济衰退且高排放（东北）
featureData.Type_DI_GDP(featureData.DI_GDP >= 1) = 1;                         % 强解耦，已实现绿色发展/达峰，最严管控
featureData.Type_DI_GDP(featureData.DI_GDP >=0 & featureData.DI_GDP <1) = 2;  % 弱解耦，将达峰。发力点，强处罚管控？
featureData.Type_DI_GDP(featureData.DI_GDP <0 & featureData.DI_GDP >=-1) = 3; % 未解耦-弱依赖，弱管控
featureData.Type_DI_GDP(featureData.DI_GDP <-1 ) = 4;                         % 未解耦-强依赖，高排放产业，奖励减排


%【重要，优先，假设/找依据】计算减碳能力/减排量，便于后续分类计算payoff，并将减碳作为收益——奖励依据
featureData.CO2_reduction_effort = rand(numAgents,1); % 随机生成减碳系数/实际减排程度系数（有政策时）
if Analys_mode_2020_model_design == 0 ...% 不进行敏感性分析时
        || (Analys_mode_2020_model_design == 1 && ... % 1或进行敏感性分析
        Analys_mode_2020_model_design_var ~= 3) ... %     且[不]关注[减排能力]
        || (Analys_mode_2020_model_design == 1 && ... % 2或进行敏感性分析
        Analys_mode_2020_model_design_var == 3 && ... %     且关注[减排能力]
        Analys_mode_2020_model_design_var_type  == 0) %  且参数为[默认]
    for i = 1:numAgents
        switch featureData.Type_DI_GDP(i)
            case 1 % 已脱钩/强解耦
                featureData.CO2_reduction_effort(i) = 0.7 + (1-0.7)*rand; % 强脱钩城市，至少付出70%的努力
            case 2 % 将脱钩/若解耦
                featureData.CO2_reduction_effort(i) = 0.5 + (1-0.5)*rand; % 弱脱钩城市，至少付出50%的努力
            case 3 % 弱依赖/未解耦
                featureData.CO2_reduction_effort(i) = 0.3 + (1-0.3)*rand; % 将脱钩城市，至少付出30%的努力
            case 4 % 强依赖/未解耦
                featureData.CO2_reduction_effort(i) = rand; % 未脱钩，随机努力
        end
    end

    % 敏感性分析————减排系数
elseif Analys_mode_2020_model_design == 1 &&...       %进行[敏感性分析]
        Analys_mode_2020_model_design_var == 3 && ... %且关注[减排能力]
        Analys_mode_2020_model_design_var_type ~= 0   %且需要[更换参数]
    for i = 1:numAgents
        switch Analys_mode_2020_model_design_var_type
            case 1 % 实际减排系数δ————统一[0.7, 1]
                featureData.CO2_reduction_effort(i) = 0.7 + (1-0.7)*rand;
            case 2 % 实际减排系数δ————统一[0.3, 1]
                featureData.CO2_reduction_effort(i) = 0.5 + (1-0.5)*rand;
            case 3 % 实际减排系数δ————统一[0, 1]
                featureData.CO2_reduction_effort(i) = rand;
        end
    end
end

% 【注意！】这里是[五年后的减排能力/减排量]。另，未来的GDP会变化，应当是逐年计算最好。  单位：万吨

switch CO2_reduction_mode
    case 1  % 单位GDP排放下降(2025十四五目标)
        if year == 2020 % 到2025年，单位国内生产总值二氧化碳排放比2020年下降18%
            % 【论文假设？】排放量不变，GDP增速固定（按4% ？），单位GDP排放下降（吨/万元）。即主要通过经济增长来实现减排目标
            % 几千(万吨) - 几千(亿)*1.04^5 * 几(吨/万元=万吨/亿) * (1-18%) *努力系数
            featureData.CO2_reduction = featureData.Total - featureData.GDP_100M .*(1 + 0.04)^5 .* featureData.CO2_emissions_per_GDP...
                *(1 - 0.18) .* featureData.CO2_reduction_effort  ;
            % 【注意，论文假设】如果没有减排政策的城市，认为减排量不变（一旦有政策，就认为会减排）
            % 【找依据/文献】减排的经济效益（理论上也是分城市） 目前每吨收益51美元（3%贴现率）-SSC
%         else
%             featureData.CO2_reduction =;
        end
    case 2 % 单位GDP下降（2030十五五，达峰目标）
        % 比2005年下降65%以上 = 每年降幅大于（1-0.89643）= 10.357%降幅
end


% 碳配额分配（最好都基于DI？）
if Analys_mode_2020_model_design == 0 ...% 不进行敏感性分析时
        || (Analys_mode_2020_model_design == 1 && ... % 或进行敏感性分析
          Analys_mode_2020_model_design_var ~= 4) ... %     且[不]关注[碳配额系数]
        || (Analys_mode_2020_model_design == 1 && ... % 或进行敏感性分析
             Analys_mode_2020_model_design_var == 4 && ... %     且关注[碳配额系数]
             Analys_mode_2020_model_design_var_type  == 0) %     且参数为[默认]
    
    switch quota_mode
        case 1 % 【论文采用】按历史排放量分配碳配额
            for i = 1:numAgents
                switch featureData.Type_DI_GDP(i)
                    case 1 % 已脱钩/强解耦
                        featureData.CO2_quota(i) = featureData.historical_emmision(i) * 0.95;
                    case 2 % 将脱钩/若解耦
                        featureData.CO2_quota(i) = featureData.historical_emmision(i) * 0.98;
                    case 3 % 弱依赖/未解耦
                        featureData.CO2_quota(i) = featureData.historical_emmision(i) * 1.05;
                    case 4 % 强依赖/未解耦
                        featureData.CO2_quota(i) = featureData.historical_emmision(i) * 1.1;
                end
            end
        case 2 % 按人口平均 Egalitarianism（平等主义）
            total_population = sum(featureData.Permanent_population_10K); %总人口（万人）
            for i = 1:numAgents
                switch featureData.Type_DI_GDP(i)
                    case 1 % 已脱钩/强解耦
                        featureData.CO2_quota(i) = featureData.Permanent_population_10K(i)/ total_population *total_carbon_quota * 0.95;
                    case 2 % 将脱钩/若解耦
                        featureData.CO2_quota(i) = featureData.Permanent_population_10K(i)/ total_population *total_carbon_quota * 1;
                    case 3 % 弱依赖/未解耦
                        featureData.CO2_quota(i) = featureData.Permanent_population_10K(i)/ total_population *total_carbon_quota * 1;
                    case 4 % 强依赖/未解耦
                        featureData.CO2_quota(i) = featureData.Permanent_population_10K(i)/ total_population *total_carbon_quota * 1.05;
                end
            end
        case 3 % 按单位GDP碳排放 Economic Activity（经济活动）
    end

    % 敏感性分析————碳配额系数
elseif Analys_mode_2020_model_design == 1 &&...       %进行[敏感性分析]
        Analys_mode_2020_model_design_var == 4 && ... %且关注[碳配额系数]
        Analys_mode_2020_model_design_var_type ~= 0   %且需要[更换参数]
     for i = 1:numAgents
         switch Analys_mode_2020_model_design_var_type
             case 1 % 统一110%
                 featureData.CO2_quota(i) = featureData.historical_emmision(i) * 1.10;
             case 2 % 统一100%
                 featureData.CO2_quota(i) = featureData.historical_emmision(i) ;
             case 3 % 统一90%
                 featureData.CO2_quota(i) = featureData.historical_emmision(i) * 0.90;
         end
     end
end

% fieldNames = fieldnames(featureData); % 获取结构体字段的名称
varNames = featureData.Properties.VariableNames;
disp('Field names in the featureData:');
disp(varNames);

outputPath = fullfile(parentPath, 'Figures & Tables'); 
cd(outputPath); %userpath(outputPath);
writetable(featureData,'Output.xlsx', 'Sheet', num2str(year),'WriteMode','overwritesheet');
% 【可优化】标注清楚，每一个输出的含义、是否需要打开查看/只是作为其他步骤的参数
addpath("Maps_2023\");
addpath("2023行政区划\");
cd(currentPath);

%% 描述性统计-实际政策实施情况

if Analys_mode_description
    years = [2020, 2021, 2022, 2023];
    figure;
    hold on;
    % subplot(2,2,1);
    % scatter(featureData.Longitude(featureData.Strategy_2020 == 1), featureData.Latitude(featureData.Strategy_2020 ==1), ...
    %     15, featureData.Strategy_2020(featureData.Strategy_2020 == 1) ,'filled');
    % scatter(featureData.Longitude(featureData.Strategy_2020 == 2), featureData.Latitude(featureData.Strategy_2020 ==2), ...
    %     15, featureData.Strategy_2020(featureData.Strategy_2020 == 2) ,'filled');

    figure;worldmap('china'); framem('off'); gridm("off");
    scatterm(featureData.Longitude(featureData.Strategy_2020 == 1), featureData.Latitude(featureData.Strategy_2020==1), 10, 'filled');
    figure;worldmap('china'); framem('off'); gridm("off");
    scatterm(featureData.Longitude, featureData.Latitude, 10, featureData.Strategy_2021 , 'filled');
    figure;worldmap('china'); framem('off'); gridm("off");
    scatterm(featureData.Longitude, featureData.Latitude, 10, featureData.Strategy_2022 , 'filled');
    figure;worldmap('china'); framem('off'); gridm("off");
    scatterm(featureData.Longitude, featureData.Latitude, 10, featureData.Strategy_2023 , 'filled');

    subplot(2,3,1);
    scatter(featureData.Longitude, featureData.Latitude, 10, featureData.Strategy_2020 , 'filled');
    xlabel('Longitude');ylabel('Latitude');
    subplot(2,3,2);
    scatter(featureData.Longitude, featureData.Latitude, 10, featureData.Strategy_2021 , 'filled');
    xlabel('Longitude');ylabel('Latitude');
    subplot(2,3,3);
    scatter(featureData.Longitude, featureData.Latitude, 10, featureData.Strategy_2022 , 'filled');
    xlabel('Longitude');ylabel('Latitude');
    subplot(2,3,4);
    scatter(featureData.Longitude, featureData.Latitude, 10, featureData.Strategy_2023 , 'filled');
    xlabel('Longitude');ylabel('Latitude');
    % [频数变化图]
    subplot(2,3,5);
    strategyMatrix_years = [featureData.Strategy_2020, featureData.Strategy_2021, featureData.Strategy_2022, featureData.Strategy_2023];
    strategy_Yes = sum(strategyMatrix_years == 1);
    strategy_No  = sum(strategyMatrix_years == 2);
    h = bar(years, [strategy_Yes; strategy_No], 'grouped','FaceColor','flat');
    h(1).FaceColor = color_No;
    h(2).FaceColor = 'yellow';
    legend({'Yes','No'});
    subplot(2,3,6);
    scatter(featureData.Longitude, featureData.Latitude, 10, featureData.Good_Strategy_2023 , 'filled');
    xlabel('Longitude');ylabel('Latitude');

    fig = gcf;  % 获取当前图形窗口句柄
    fig.WindowState = 'maximized';
    hold off
end

%% 仿真分析-网络演化与策略传播

% 多次绘图矩阵的初始化 0413
strategyFreq_file_1_matrix = zeros(iteration_figures_Main_max, 1+numIterations);
strategyFreq_file_Type1_1_matrix = zeros(iteration_figures_Main_max, 1+numIterations);
strategyFreq_file_Type2_1_matrix = zeros(iteration_figures_Main_max, 1+numIterations);
strategyFreq_file_Type3_1_matrix = zeros(iteration_figures_Main_max, 1+numIterations);
strategyFreq_file_Type4_1_matrix = zeros(iteration_figures_Main_max, 1+numIterations);

iteration_Main = 1;
while iteration_Main < iteration_figures_Main_max + 1
% 随机初始化城市策略（仅在反事实情景用）
numStrategies = 2; %【注意】只假设了两种纯策略【后续突破】混合策略

% 初始化策略，按不同分析需求，输入初始化策略-实施减排政策情况。
FoldingCode_initial_strategy = 1;
while FoldingCode_initial_strategy == 1 % 此while循环仅用于折叠代码0413
if featureData.Year == 2020 % 基于2020排放数据分析
    switch Analys_mode_2020
        case 0 %以2020年随机生成
            strategyMatrix_rand = rand(numAgents,1); 
            strategyMatrix = -(strategyMatrix_rand <= Counterfactual_percentage) + 2; %约2%的试点城市（首批11个试点）
            sheetName_mode = '2020反事实-随机试点';
        case -1 % 基于2020数据，2023政策前移
            strategyMatrix = featureData.Strategy_2023; 
            sheetName_mode = '2020反事实-2023政策';
            strategyMatrix_2023 = strategyMatrix; %【0415批注】绘图严谨，储存文件要同步更新初始化
        case 1
            strategyMatrix = featureData.Strategy_2020; 
            sheetName_mode = '2020政策';%以2020年的政策实施情况(发布文件或规划)为准           
        case 2
            strategyMatrix = featureData.Strategy_2021; 
            sheetName_mode = '2021政策';
        case 3
            strategyMatrix = featureData.Strategy_2022; 
            sheetName_mode = '2022政策';
        case 4
            strategyMatrix = featureData.Strategy_2023; 
            sheetName_mode = '2023政策';
        case 5
            strategyMatrix = featureData.Good_Strategy_2023; 
            sheetName_mode = '2023优良政策';%以2023年被评为"优良"的减排试点政策城市名单为准
    end
else %基于2010或2015的排放数据
    % 判定反事实分析的情景。【待完成】收益策略也要同步修改。
    switch Analys_mode_counterfactual
        case 0
            strategyMatrix = randi([1, numStrategies], numAgents, 1); %情景0-随机初始策略，有赏罚
            sheetName_mode = '反事实-随机';
        case 1
            strategyMatrix = zeros(numAgents,1) + 2;  %情景1-无试点、无赏罚
            sheetName_mode = '反事实-无试点无赏罚'; %【注意】这里不会凭空产生新策略，相当于只有处罚
        case 2
            strategyMatrix_rand = rand(numAgents,1);    %情景2-有试点、无赏罚
            strategyMatrix = -(strategyMatrix_rand <= Counterfactual_percentage) + 2; %约5%的试点城市（首批11个试点）
            sheetName_mode = '反事实-有试点无赏罚';
        case 3
            strategyMatrix_rand = rand(numAgents,1);    %情景3-有试点、有赏罚
            strategyMatrix = -(strategyMatrix_rand <= Counterfactual_percentage) + 2; %约5%的试点城市（首批11个试点）
            sheetName_mode = '反事实-有试点有赏罚';
        case 4
            switch Analys_mode_2020     %情景4-当前的试点政策前移、有赏罚时，选择不同的前移节点
                case 1
                    strategyMatrix = featureData.Strategy_2020; 
                    sheetName_mode = '反事实-2020政策前移';
                case 2
                    strategyMatrix = featureData.Strategy_2021; 
                    sheetName_mode = '反事实-2021政策前移';
                case 3
                    strategyMatrix = featureData.Strategy_2022; 
                    sheetName_mode = '反事实-2022政策前移';
                case 4
                    strategyMatrix = featureData.Strategy_2023; 
                    sheetName_mode = '反事实-2023政策前移';
                case 5
                    strategyMatrix = featureData.Good_Strategy_2023; 
                    sheetName_mode = '反事实-2022优良政策前移';
            end 
    end
end

strategyMatrix_initial = strategyMatrix;

% 初始情况的频率
for strategy = 1:numStrategies
    strategyFreq_initial(strategy, 1) = sum(strategyMatrix_initial(:, 1) == strategy) / numAgents;
    strategyFreq_initial1(strategy, 1) = sum(strategyMatrix_initial((featureData.Type_DI_GDP == 1), 1) == strategy) / numAgents;
    strategyFreq_initial2(strategy, 1) = sum(strategyMatrix_initial((featureData.Type_DI_GDP == 2), 1) == strategy) / numAgents;
    strategyFreq_initial3(strategy, 1) = sum(strategyMatrix_initial((featureData.Type_DI_GDP == 3), 1) == strategy) / numAgents;
    strategyFreq_initial4(strategy, 1) = sum(strategyMatrix_initial((featureData.Type_DI_GDP == 4), 1) == strategy) / numAgents;
end


% 进行网络演化博弈计算
% numIterations = 5;  % 迭代次数

% 初始化博弈结果矩阵
gameResults = zeros(numAgents, numIterations); 

FoldingCode_initial_strategy = FoldingCode_initial_strategy + 1;
end

% 【知识点】博弈过程的4个元素包括:决策人、策略集、收益矩阵和次序
% 进行博弈迭代计算 【关键之一】
if Analys_mode_dynamicDiffusion
    figure;
    fig = gcf;
    fig.WindowState = 'maximized';
end

% [0413优化]筛选出邻居的数据表，优化代码，减少运行时间
% 收益函数计算用到的变量：GDP_100M、Type_DI_GDP、CO2_reduction、Total、CO2_quota
variables_payoff = {'GDP_100M' ,'Type_DI_GDP', 'CO2_reduction', 'Total', 'CO2_quota'};
featureData_agents = featureData(:, variables_payoff);
featureData_agents_array = table2array(featureData_agents);

%【核心代码】网络演化分析
for iteration = 1:numIterations
    if rng_shuffle_model == 1 %以当前时间为种子，进行随机
        rng('shuffle'); %【0414注意】非常耗时，可以不用？
    end
    newStrategyMatrix = strategyMatrix; %复制当前策略矩阵便于计算
    
    % 【重要！注意！】这里只按Agent逐一算了一次，是单向的，没有回溯（固定博弈序列）。目前先用随机种子+多次迭代来解决？
    % 【重要，待优化/待扩展】优化迭代规则，不用按同样的序列遍历，减少计算量，更快达到局部最优/稳定解

    % 更新代理人策略
    for agent = 1:numAgents

        
        currentPayoff = agent_payoff_array(featureData_agents_array(agent,:), strategyMatrix(agent), carbonInfo,...
            Analys_mode_2020_model_design, Analys_mode_2020_model_design_var, Analys_mode_2020_model_design_var_type);
        bestStrategy = strategyMatrix(agent); %初始化最佳策略，认为是当前策略

        % 获取当前代理人的邻居节点
        neighbors = find(adjMatrix(agent, :) == 1 ); 

        % 【论文假设？】孤立城市，讨巧的解决方案——随机选一个/按最邻近城市比较，以保证一定的随机性？
        if lonelyCity
           if isempty(neighbors)
            % [~,neighbors] = maxk(connectivity(agent,:), 1); % 选1个连接度最高的邻居比较 
             neighbors = randi([1,numAgents]); %随机选择一个城市比较
           end
        end

        neighborPayoffs = zeros(length(neighbors),1);
        probabilities = zeros(length(neighbors),1);
        neighbor_count = 0;

        % 【0413优化】
        featureData_neighbors_array = featureData_agents_array(neighbors, :);

        % 【论文注意，非常重要，可能致命】这里只与邻居比较，如果网络结构不相连，就不可能凭空传播到！!
        % 碳交易价格极高时可以————低概率的独立理性决策
     
        for neighbor = 1: length(neighbors)
            neighbor_count = neighbor_count + 1;
            neighborPayoffs(neighbor_count) = agent_payoff_array(featureData_neighbors_array(neighbor, :), strategyMatrix(agent), carbonInfo, Analys_mode_2020_model_design, Analys_mode_2020_model_design_var, Analys_mode_2020_model_design_var_type);
            probabilities(neighbor_count) = 1 / (1 + exp( - ( neighborPayoffs(neighbor_count)- currentPayoff)  / fermi_k) ); %注意，仅当邻居收益更高时才有用
        end


        % 用费米函数，计算Agent选择每个邻居的策略的概率
%         probabilities = 1 ./ (1 + exp(fermi_k * (neighborPayoffs - max(neighborPayoffs)))); % 根据所有邻居的Payoff，计算每个邻居的概率，列向量
        neighbor_count = 0;
        
        %【关键步骤】策略更新规则
        % 当采用混合决策时
        if strategy_mode_mixed && (rand > strategy_mode_mixed_threshold) % 如果采取混测策略，根据概率选择本次迭代中，本agent的策略
            strategy_mode = 1; %盲从邻居
        elseif strategy_mode_mixed
            strategy_mode = 0; %完全理性
        end

        % 按策略更新规则，进行策略传播
        switch strategy_mode
            case 1 % 模式1-盲从最大收益邻居
                % 【注意，论文假设】这里按收益最高的邻居策略来（可能是纯粹的GDP高，就能吸引都合作）
                for neighbor = neighbors
                    neighbor_count = neighbor_count + 1;
                    % 【可拓展】应该是按相似性，确定博弈次序，与处境相似者博弈。
                    
                    % 固定随机种子
                    if fermi && neighbor_rand && neighbor_rand_seed 
                        rng(iteration);
                    end
                    %【问题】这一段代码没有用？
                    if fermi && neighbor_rand && rand() < neighbor_rand_threshold
                       %【论文注意】稳健性分析？避免随机性的影响，应该进行100次模拟？
                        continue
%                         break % 费米规则时，按百分比随机选择邻居
                    end

                    if neighborPayoffs(neighbor_count) > currentPayoff
                        if fermi  % 当邻居收益更高时，按概率决定是否采纳邻居策略
                            rand_num = rand();
                            if rand_num < probabilities(neighbor_count)
                                bestStrategy = strategyMatrix(neighbor);
                            end
                        else % 直接按最高收益邻居
                            bestStrategy = strategyMatrix(neighbor);
                            %【可优化？】这里不需要每次改变策略都计算收益？
                            %【错误，不是直接把邻居收益给自己】currentPayoff = neighborPayoffs(neighbor_count);
                            currentPayoff = agent_payoff(featureData(agent,:), bestStrategy, carbonInfo,...
                                Analys_mode_2020_model_design, Analys_mode_2020_model_design_var, Analys_mode_2020_model_design_var_type); % 相比之前，改用了邻居的策略
                        end
                    end
                    
                    % 【标记】原先费米规则随机选择邻居的代码
                end
                
            case 0 % 自己完全独立理性决策，没有交互
                Payoff_cooperate = agent_payoff_array(featureData_agents_array(agent,:), 1, carbonInfo,...
                    Analys_mode_2020_model_design, Analys_mode_2020_model_design_var, Analys_mode_2020_model_design_var_type);
                Payoff_defect = agent_payoff_array(featureData_agents_array(agent,:), 2, carbonInfo,...
                    Analys_mode_2020_model_design, Analys_mode_2020_model_design_var, Analys_mode_2020_model_design_var_type);
                if Payoff_cooperate >= Payoff_defect
                    bestStrategy = 1;
                else
                    bestStrategy = 2;
                end
        end

        % 选择最优策略(按收益最高的邻居的策略)
        newStrategyMatrix(agent) = bestStrategy;
        % 【可尝试】原则：本省内邻居总收益提高
    end
    
    % 更新代理人策略数据
    strategyMatrix = newStrategyMatrix;

    % 保存博弈结果
    gameResults(:, iteration) = strategyMatrix;
    % 【图片，注意，统一调整】保存的是第一次迭代后的结果，画图中要考虑初始值的情况！！
    gameResults_all = [strategyMatrix_initial, gameResults]; % 加上初始策略情况

    % 【博弈过程动态绘图】
    if Analys_mode_dynamicDiffusion

        % 1、绘制策略分布直方图
        subplot(1, 3, 1);
        C = categorical(strategyMatrix,[1 2],{'Yes','No'});
        h = histogram(C, 'BarWidth', 0.5); % 绘制策略分布直方图
        xlabel('Strategy');
        ylabel('Frequency');
        title('Strategy Distribution - Iteration ', num2str(iteration)); % 设置标题
        drawnow; % 更新图形显示
    
        % 2、空间位置
        subplot(1, 3, 2);
        scatter(featureData.Longitude(strategyMatrix == 2), ...
                featureData.Latitude(strategyMatrix == 2), 10, 	color_Yes, 'filled');
        hold on
        scatter(featureData.Longitude(strategyMatrix == 1), ...
                featureData.Latitude(strategyMatrix == 1), 15, 	color_No, 'filled'); 
        xlabel('Longitude');
        ylabel('Latitude');
    
        if iteration == numIterations %【注意】静态网络结构，只在第一次迭代画连线即可
            connectivity_min = min(connectivity(:));
            connectivity_max = max(connectivity(:));
            connectivity_plot = (connectivity - connectivity_min) / (connectivity_max - connectivity_min);
    %         connectivity_plot = rescale(connectivity())*10 + 1 ;
            for i = 1:numAgents
                for j = i:numAgents
                    if adjMatrix(i,j) == 1
                        line([featureData.Longitude(i), featureData.Longitude(j)], ...
                             [featureData.Latitude(i), featureData.Latitude(j)], ...
                             'Color', [0.5, 0.5, 0.5], ...
                             'LineWidth', connectivity_plot(i,j));            
                    end
                end
            end
        end
        hold off
        title(['City Strategies - Iteration ', num2str(iteration)]);
    %     colorbar;
        legend('No','Yes');
        
        % 3、绘制城市网络图
        if iteration == numIterations % 最后画图
            subplot(1, 3, 3);
            imagesc(gameResults_all);
            xlim([0, iteration]);
            %title('策略变化历史');
            xlabel('Iterations');
            ylabel('Cities');
            legend('No','Yes');
        end
            
        % 暂停以观察动态变化
    %     pause(pause_second);
    end
end

cd(outputPath);
if excel_output == 1
    sheetName = strcat('策略变化',num2str(year),'排放+',sheetName_mode) ;
    writematrix([featureData.Code,gameResults_all], 'Output.xlsx', 'WriteMode', 'overwritesheet', 'Sheet', sheetName);
end


%% 节点分析-策略的频率变化图
cd(outputPath);

% 根据演化结果中，每个城市的策略，计算整体频率，便于绘制折线图
FoldingCode_strategy_frequency = 1;
while FoldingCode_strategy_frequency == 1 % 此while仅用于折叠代码


% 基于当前年份数据，计算各类DI的数量
numType1 = sum(featureData.Type_DI_GDP == 1);
numType2 = sum(featureData.Type_DI_GDP == 2);
numType3 = sum(featureData.Type_DI_GDP == 3);
numType4 = sum(featureData.Type_DI_GDP == 4);

% 初始化（不同DI的折线分别初始化）
strategyFreq = zeros(numStrategies, numIterations);
strategyFreq_Type1 = zeros(numStrategies, numIterations);
strategyFreq_Type2 = zeros(numStrategies, numIterations);
strategyFreq_Type3 = zeros(numStrategies, numIterations);
strategyFreq_Type4 = zeros(numStrategies, numIterations);
strategyFreq_initial = zeros(numStrategies, 1);
strategyFreq_initial1 = zeros(numStrategies, 1);
strategyFreq_initial2 = zeros(numStrategies, 1);
strategyFreq_initial3 = zeros(numStrategies, 1);
strategyFreq_initial4 = zeros(numStrategies, 1);

% 计算策略频率
for iteration = 1:numIterations
    for strategy = 1:numStrategies
        strategyFreq(strategy, iteration) = sum(gameResults(:, iteration) == strategy) / numAgents;
        strategyFreq_Type1(strategy, iteration) = sum(gameResults((featureData.Type_DI_GDP == 1), iteration) == strategy) / numAgents;
        strategyFreq_Type2(strategy, iteration) = sum(gameResults((featureData.Type_DI_GDP == 2), iteration) == strategy) / numAgents;
        strategyFreq_Type3(strategy, iteration) = sum(gameResults((featureData.Type_DI_GDP == 3), iteration) == strategy) / numAgents;
        strategyFreq_Type4(strategy, iteration) = sum(gameResults((featureData.Type_DI_GDP == 4), iteration) == strategy) / numAgents;
    end
end

% 补上初始情况，一共 1 + iterations 次的结果
strategyFreq = [strategyFreq_initial, strategyFreq]; 
strategyFreq_Type1 = [strategyFreq_initial1, strategyFreq_Type1];
strategyFreq_Type2 = [strategyFreq_initial2, strategyFreq_Type2];
strategyFreq_Type3 = [strategyFreq_initial3, strategyFreq_Type3];
strategyFreq_Type4 = [strategyFreq_initial4, strategyFreq_Type4];

% 有2行，其实只需要合作的一行就够，用于储存到文件中
strategyFreq_file_1 = strategyFreq(1,:);
if Analys_mode_2020 == -1 % 反事实2023政策前移
    strategyFreq_file_1(1) = sum(strategyMatrix_2023 == 1) / numAgents;
end
strategyFreq_file_Type1_1 = strategyFreq_Type1(1,:); 
strategyFreq_file_Type2_1 = strategyFreq_Type2(1,:); 
strategyFreq_file_Type3_1 = strategyFreq_Type3(1,:); 
strategyFreq_file_Type4_1 = strategyFreq_Type4(1,:); 
FoldingCode_strategy_frequency = FoldingCode_strategy_frequency + 1;

% 把向量结果复制到Main的矩阵中，只有2次及以上循环时，才输出这个矩阵。
strategyFreq_file_1_matrix(iteration_Main, :) = strategyFreq_file_1;
strategyFreq_file_Type1_1_matrix(iteration_Main, :) = strategyFreq_file_Type1_1;
strategyFreq_file_Type2_1_matrix(iteration_Main, :) = strategyFreq_file_Type2_1;
strategyFreq_file_Type3_1_matrix(iteration_Main, :) = strategyFreq_file_Type3_1;
strategyFreq_file_Type4_1_matrix(iteration_Main, :) = strategyFreq_file_Type4_1;

end

% 保存当前频率矩阵（行向量叠加）
% 【0413注意】 这里对应的是每一次循环中iteration的结果，不是每一个大循环iteration_Main的结果
if iteration_Main == 1 %第一次迭代时
    save('Current_frequency_matrix.mat',"strategyFreq_file_1"); % 临时储存变量
    save('Current_frequency_matrix_Type1.mat',"strategyFreq_file_Type1_1");
    save('Current_frequency_matrix_Type2.mat',"strategyFreq_file_Type2_1");
    save('Current_frequency_matrix_Type3.mat',"strategyFreq_file_Type3_1");
    save('Current_frequency_matrix_Type4.mat',"strategyFreq_file_Type4_1");
    %【0413注意】只循环一次时的结果没用上，要改成单次只输出一条线
    % （基于下面0413调试改一下变量即可）

elseif iteration_Main == iteration_figures_Main_max % 最后一次迭代时，保存变量
    save('Current_frequency_matrix.mat',"strategyFreq_file_1_matrix",'-append');
    save('Current_frequency_matrix_Type1.mat',"strategyFreq_file_Type1_1_matrix",'-append');
    save('Current_frequency_matrix_Type2.mat',"strategyFreq_file_Type2_1_matrix",'-append');
    save('Current_frequency_matrix_Type3.mat',"strategyFreq_file_Type3_1_matrix",'-append');
    save('Current_frequency_matrix_Type4.mat',"strategyFreq_file_Type4_1_matrix",'-append');
end

iteration_Main = iteration_Main + 1;

end % 主程序的while循环结束 ———— iteration_Main


%% 【实时结果，仅供展示】While循环结束后的，含置信区间的折线图
% 【0413新版————当前实时结果——有标准差区间的频率图】（Main_iteration都完成后才）绘制策略频率变化图
% 【0413注意】只需要读取"....Martrix"这个变量即可
cd(outputPath);

%【0414待完成】按DI分类的实时结果输出             
% 若需实时输出时，在最后一次迭代，保存一个合并的文件
    if draw_realtime == 1
        realtime_struct = struct(); % 【0415批注】为复合画图函数的输入格式
        realtime_struct.('strategyFreq_file_1_matrix') = strategyFreq_file_1_matrix; %load('Current_frequency_matrix.mat','strategyFreq_file_1_matrix');
        realtime_matrix = [];
        strategyFreq_varTypes = {strategyFreq_file_Type1_1_matrix, strategyFreq_file_Type2_1_matrix, strategyFreq_file_Type3_1_matrix, strategyFreq_file_Type4_1_matrix};
        for i_realtime = 1:4
            realtime_filename = sprintf('Current_frequency_matrix_Type%d.mat',i_realtime);
            realtime_var = sprintf('strategyFreq_file_Type%d_1_matrix', i_realtime);
            realtime_matrix = load(realtime_filename, realtime_var);
            realtime_struct.(realtime_var) = cell2mat(strategyFreq_varTypes(i_realtime)); %strategyFreq_file_1_matrix; 
%             outputData_matrix.(output_var_name) = strategyFreq_file_1_matrix;
        end
        realtime_filename_draw = 'Realtime_output';
        save(realtime_filename_draw, "realtime_struct");      
        drawFrequency_matrix(realtime_filename_draw, numIterations, 1);
    end


% 主程序循环1次，只画折线图
if iteration_figures_Main_max == 1 
    % 【0413注：旧版本，单次，可运行】绘制策略频率变化图
    figure;
    plot(0:numIterations, strategyFreq(1, :), 'LineWidth', 2 , 'DisplayName', 'All Cities');
    hold on;
    % plot(0:numIterations, strategyFreq(2, :), 'LineWidth', 2 , 'DisplayName', 'No');
    plot(0:numIterations, strategyFreq_Type1(1, :), ':', 'LineWidth', 1.5 , 'DisplayName', 'Strong Decoupling','Color', color_Tpye1);
    plot(0:numIterations, strategyFreq_Type2(1, :), ':', 'LineWidth', 1.5 , 'DisplayName', 'Weak Decoupling','Color', color_Tpye2);
    plot(0:numIterations, strategyFreq_Type3(1, :), ':', 'LineWidth', 1.5 , 'DisplayName', 'Potential Decoupling','Color', color_Tpye3);
    plot(0:numIterations, strategyFreq_Type4(1, :), ':', 'LineWidth', 1.5 , 'DisplayName', 'No Decoupling','Color', color_Tpye4);
    ylim([0 1.001])
    xlim([0 numIterations]); %xticks(0:numIterations);%xticks([0:10]);
    ylabel('Frequency');
    xlabel('Iterations');
    legend('Location','northeast');
    % legend('策略1', '策略2');
    % title('策略频率随时间的变化');
    grid off;
    hold off;



% 【主要执行的部分】主程序循环次数 ＞ 1次时，绘制带有置信区间的图
else % 按需求保存文件
    

    %【【【———————————————————— 碳价格 ——————————————————————】】】保存文件，并按碳价格，改变量名
    if Analys_mode_2020_carbonPrice == 1
        output_var_name = sprintf('AAA_%d_yuan_per_ton', carbonInfo.price);
        output_matrix_name_carbonPrice = 'Carbon Price';
        outputData_matrix.(output_var_name) = strategyFreq_file_1_matrix; % 只保存总体的频率矩阵，若有需要再存DI
        if exist(output_matrix_name_carbonPrice,"file") == 0 
            % 若文件不存在
            save(output_matrix_name_carbonPrice, "outputData_matrix"); 
        else 
            % 若文件存在，则append
            save(output_matrix_name_carbonPrice, "outputData_matrix", '-append');
        end
    end


    % 【反事实情景】
    if Analys_mode_2020_counterfacutal == 1
        %【0414批注，0415已完成优化】反事实情景的图需要基线情况，但是也会导致默认分析也输出
        
        %【【【————————————————————反事实0————2020基线————————————————————】】】
        if Analys_mode_2020 == 1  %  1——2020基线；
            output_var_name = sprintf('Baseline_2020');
        end
        %【【【————————————————————反事实1————2020随机试点————————————————————】】】
        if Analys_mode_2020 == 0  %  0——反事实地随机生成n个；
            output_var_name = sprintf('Counterfactual_2020_rand');
        end
        %【【【————————————————————反事实2————20203政策提前到2020————————————————————】】】
        if Analys_mode_2020 == -1 % -1——反事实-2023政策前移
            output_var_name = sprintf('Counterfactual_2023_Strategy');
        end

        output_matrix_name_counterfactual = 'Counterfactual';
        outputData_matrix.(output_var_name) = strategyFreq_file_1_matrix; % 只保存总体的频率矩阵，若有需要再存DI
        if exist(output_matrix_name_counterfactual,"file") == 0 
            save(output_matrix_name_counterfactual, "outputData_matrix"); 
        else 
            save(output_matrix_name_counterfactual, "outputData_matrix", '-append');
        end
    end


    %【【【【————————————————————敏感性分析————————————————————】】】】
% Analys_mode_2020_model_design_var = 1;      % [要进行敏感性分析的变量] 1-奖励系数 2-惩罚系数 3-实际减排 4-当前分配系数
% Analys_mode_2020_model_design_var_type = 2; % [基于上,组合使用] 0-正常参数 1-统一3倍激励/惩罚 2-统一1倍 3-统一无……;
%                                             % 当前实际减排／统一［0.7, 1］／统一［0.5, 1］/ 统一 [0, 1]（可解释为政策约束）
%                                             % 当前分配系数 /统一110%／统一100％／统一90％（通过碳配额进行约束）

    if Analys_mode_2020_model_design == 1
        switch Analys_mode_2020_model_design_var
            %【0414可优化】这里并没有区分70元、1803元的变量名

            case 1 % 【奖励系数】  0：正常 1：统一3倍 2：统一1倍 3：统一无
                switch Analys_mode_2020_model_design_var_type
                    case 0
                        %output_var_name = sprintf('AAA_%d_', carbonInfo.price);
                        output_var_name = sprintf('Default');
                    case 1
                        output_var_name = sprintf('All_3_times_incentives');
                    case 2
                        output_var_name = sprintf('All_1_times_incentives');
                    case 3
                        output_var_name = sprintf('All_No_incentives');
                end
                output_matrix_name_incentive = 'Incentives for emission reductions';
                outputData_matrix.(output_var_name) = strategyFreq_file_1_matrix; % 只保存总体的频率矩阵，若有需要再存DI
                if exist(output_matrix_name_incentive, "file") == 0
                    save(output_matrix_name_incentive, "outputData_matrix");
                else
                    save(output_matrix_name_incentive, "outputData_matrix", '-append');
                end


            case 2 % 【惩罚系数】   0：正常 1：统一3倍 2：统一1倍 3：统一无
                switch Analys_mode_2020_model_design_var_type
                    case 0
                        output_var_name = sprintf('Default');
                    case 1
                        output_var_name = sprintf('All_3_times_penalties');
                    case 2
                        output_var_name = sprintf('All_1_times_penalties');
                    case 3
                        output_var_name = sprintf('All_No_penalties');
                end
                output_matrix_name_penalties = 'Penalties for emission reductions';
                outputData_matrix.(output_var_name) = strategyFreq_file_1_matrix; 
                if exist(output_matrix_name_penalties, "file") == 0
                    save(output_matrix_name_penalties, "outputData_matrix");
                else
                    save(output_matrix_name_penalties, "outputData_matrix", '-append');
                end


            case 3 % 【实际减排系数】 0：当前实际减排 1：统一［0.7, 1］ 2：统一［0.5, 1］ 3：统一 [0, 1]
                switch Analys_mode_2020_model_design_var_type
                    case 0
                        output_var_name = sprintf('Default');
                    case 1
                        output_var_name = sprintf('Reduction_ratio_70_to_100_percents');
                    case 2
                        output_var_name = sprintf('Reduction_ratio_50_to_100_percents');
                    case 3
                        output_var_name = sprintf('Reduction_ratio_0_to_100_percents');
                end
                output_matrix_name_reduction = 'Acutal emission reduction';
                outputData_matrix.(output_var_name) = strategyFreq_file_1_matrix;
                if exist(output_matrix_name_reduction, "file") == 0
                    save(output_matrix_name_reduction, "outputData_matrix");
                else
                    save(output_matrix_name_reduction, "outputData_matrix", '-append');
                end
            case 4 % 【碳配额系数】 0：当前 1：统一110% 2：统一100％: 3：统一90％
                switch Analys_mode_2020_model_design_var_type
                    case 0
                        output_var_name = sprintf('Default');
                    case 1
                        output_var_name = sprintf('All_quota_110_percents');
                    case 2
                        output_var_name = sprintf('All_quota_100_percents');
                    case 3
                        output_var_name = sprintf('All_quota_90_percents');
                end
                output_matrix_name_quota = 'Carbon quota allocation factor';
                outputData_matrix.(output_var_name) = strategyFreq_file_1_matrix;
                if exist(output_matrix_name_quota, "file") == 0
                    save(output_matrix_name_quota, "outputData_matrix");
                else
                    save(output_matrix_name_quota, "outputData_matrix", '-append');
                end
        end
    end



end

%% 【Final——按分析模式出图】不同参数变化下的频率变化图
% 【0414注意】此处不按DI分类输出，仅按总的结果看
% Analys_mode_2020_carbonPrice = 0;           % [参数图]是否进行"碳价格"参数分析————并储存结果（仅限2020年） 默认为1；调试时为0
% Analys_mode_2020_model_design = 0;          % [参数图]是否进行模型敏感性分析（仅限2020年）默认为0-否；调试时为1-是 
% Analys_mode_2020_model_design_var = 1;      % [要进行敏感性分析的变量] 1-奖励系数 2-惩罚系数 3-实际减排 4-当前分配系数
% Analys_mode_2020_model_design_var_type = 2; % [基于上,组合使用] 0-正常参数 1-统一3倍激励/惩罚 2-统一1倍 3-统一无……;
%                                             % 当前实际减排／统一［0.7, 1］／统一［0.5, 1］/ 统一 [0, 1]（可解释为政策约束）
%                                             % 当前分配系数 /统一110%／统一100％／统一90％（通过碳配额进行约束）


% 当所有参数的全部循环都结束时，才绘图

if iteration_debug == length(debug_values) && length(debug_values) > 1

    % 【正文1】不同碳价格
    if Analys_mode_2020_carbonPrice == 1
        filename_draw = output_matrix_name_carbonPrice; % 碳价格矩阵的文件名称
        DI_draw = 0; % 默认为0，不用分DI绘制（若需，还要保存相应结果）
        drawFrequency_matrix(filename_draw, numIterations, DI_draw);
    end

    % 【正文2】反事实情景:2020随机试点 + 2023政策提前
    if Analys_mode_2020_counterfacutal == 1
        filename_draw = output_matrix_name_counterfactual; % 碳价格矩阵的文件名称
        DI_draw = 0; % 默认为0，不用分DI绘制（若需，还要保存相应结果）
        drawFrequency_matrix(filename_draw, numIterations, DI_draw);
    end

    % 【SI 敏感性分析】
    if Analys_mode_2020_model_design == 1
        switch Analys_mode_2020_model_design_var
            case 1 % 激励系数
                filename_draw = output_matrix_name_incentive;
            case 2 % 惩罚系数
                filename_draw = output_matrix_name_penalties;
            case 3 % 实际减排系数
                filename_draw = output_matrix_name_reduction;
            case 4 % 碳配额系数
                filename_draw = output_matrix_name_quota;
        end
        DI_draw = 0; % 默认为0，不用分DI绘制（若需，还要保存相应结果）

        drawFrequency_matrix(filename_draw, numIterations, DI_draw);
    end
end



end %【【【【【【【【【【【【【【  0414仅限调参、敏感性分析专用  】】】】】】】】】】】

% % 调试专用
if debug_mode == 1
    return;
end


%% 节点分析-行为扩散度 Diffusion
% 利用广度优先搜索，计算策略扩散度
% 广度优先搜索：按照距离从近到远的顺序对各节点进行搜索
% 深度优先搜索：则沿着一条路径不断往下搜索直到不能再继续为止，然后再折返，开始搜索下一条路径。
x_label = featureData.Longitude;
y_label = featureData.Latitude;
coordinates = horzcat(x_label, y_label);
[numNodes, ~] = size(coordinates);

% "合作"行为扩散度图-以稳定状态的策略为准搜索
figure;
hold on;
diffusion_degree = zeros(numAgents,1);
for i = 1:numNodes
    diffusion_degree(i) = diffusion(adjMatrix, strategyMatrix, i, gameResults_all); % 计算某个节点的行为扩散度
end
featureData.diffusion = diffusion_degree;

scatter(featureData.Longitude(strategyMatrix == 2), ...
        featureData.Latitude(strategyMatrix == 2), 10, featureData.diffusion(strategyMatrix == 2) ,'filled', 'Marker','square'); 
scatter(featureData.Longitude(strategyMatrix == 1), ...
        featureData.Latitude(strategyMatrix == 1), 15, featureData.diffusion(strategyMatrix == 1) , 'filled'); 
% scatter(coordinates(:,1), coordinates(:,2), 10,diffusion_degree ,'filled');

% 标签-扩散度前十的城市
[~, diffusion_degreeRank] = sort(diffusion_degree, 'descend');
sortedIndices = diffusion_degreeRank;
text(coordinates(sortedIndices(1:5), 1), coordinates(sortedIndices(1:5), 2), ...
    cellstr(featureData.City(sortedIndices(1:5))), 'FontSize', 12, 'FontWeight', 'normal','Color',[0.9 0 0]);

legend({'No','Yes'},'Location','best');
xlabel('Longitude');
ylabel('Latitude');
% ylabel('Label for Colorbar', 'Rotation', -90, 'HorizontalAlignment','right');
colormap("turbo");
% colormap(flipud(colormap));
colorbar;
hold off;

%【地图】
figure;worldmap('china');gridm('off');framem('off');
scatterm(featureData.Latitude(strategyMatrix == 2), ...
        featureData.Longitude(strategyMatrix == 2), 10, featureData.diffusion(strategyMatrix == 2) ,'filled', 'Marker','square'); 
scatterm(featureData.Latitude(strategyMatrix == 1), ...
        featureData.Longitude(strategyMatrix == 1), 15, featureData.diffusion(strategyMatrix == 1) , 'filled'); 


%% 节点分析-社区检测Community Detection

% 【可运行】绘制节点之间的连线
x_label = featureData.Longitude;
y_label = featureData.Latitude;
coordinates = horzcat(x_label, y_label);
[numNodes, ~] = size(coordinates);



communities = ones(numNodes, 1); % 正整数值，默认都为1
% 判断每个节点所属的社区
switch community_detection_mode
    
    case 0 % 自己写，按[是否相连/邻接矩阵]判断，有重复？
        currentCommunity = 2;
        for i = 1:numNodes
            if communities(i) == 1 % 节点没有社区时 %communities(i) = currentCommunity;
                neighbors = find(adjMatrix(i, :)); % 根据[是否连接]筛选
                if ~isempty(neighbors)
                    communities(i) = currentCommunity; % 有邻居时，才算社区。
                    communityMembers = i; % 初始社区，仅有自己
                    for j = 1:length(neighbors)
                        if communities(j) == 1 % 如果邻居j没有社区时
                            if strategyMatrix(i) == strategyMatrix(neighbors(j)) % 根据 策略相同 进一步筛选
                                communityMembers = [communityMembers, neighbors(j)];
                            end
                        else  % 邻居j已有社区
                            if strategyMatrix(i) == strategyMatrix(neighbors(j))
                                communities(i) = communities(j); % 若策略相同，加入邻居的社区
                            end
                        end
                    end
                    communities(communityMembers) = currentCommunity;
                    currentCommunity = currentCommunity + 1;
                end 
            end
        end

    case 1 % Toolbox-Reichardt【注意】CDTB不能处理加权图，只能处理0和1的邻接矩阵
        %communities = GCReichardt(connectivity, 3); % 默认参数1，Martelot's implementation of gamma-modularity maximization.
        communities = GCReichardt(adjMatrix, 1) + 1;       
    case 2 % Toolbox-Modularity Maximization
        communities = GCModulMax3(adjMatrix) + 1; % 纽曼贪心算法 Newman, Mark EJ. "Fast algorithm for detecting community structure in networks." Physical review E 69.6 (2004): 066133.
    case 3 % Toolbox-Ronhovde 不好用
        communities = GCRonhovde(adjMatrix, 1) + 1; % Martelot's implementation of gamma-modularity maximization.
end
featureData.communitiy = communities;
writematrix([featureData.Code, featureData.communitiy], 'Output-community.xlsx', 'WriteMode', 'overwritesheet', 'Sheet', 'community');

% 直方图展示社区
figure
h = histogram(communities, unique(communities));
xlabel('Communities'); ylabel('Frequency');


% 将独立社区统一赋值为0，便于后续颜色区分
for i = 1:numNodes
    neighbors = find(adjMatrix(i, :));
    if isempty(neighbors)
        communities(i) = 1; 
    end
end

numCommunities = max(communities); % 26时颜色更好，与四极匹配？
rng('default') ;% rng(1); %97.9=rng(0) 98=rng(1)
communityColors = prism(numCommunities); % prism/turbo/parula/copper/pink/Autumn/spring/cool/hot/jet/colormap
communityColors(1,:) = [0.75 0.75 0.75];


%【地图】
figure
worldmap('china');gridm('off');framem('off');
hold on;
for i = 1:numNodes
    color = communityColors(communities(i), :);
    if strategyMatrix(i) == 1
        marker = 'o';
    else
        marker = 'x';
    end
    scatterm(y_label(i), x_label(i), 20, color, marker, 'LineWidth', 1.5);
end


fig = gcf; % 获取当前窗口句柄
fig.Position = [100, 100, 700, 700];
% 设置坐标轴标签和标题
xlabel('Longitude');
ylabel('Latitude');
title('Community Distribution');
% 显示图例【待调整】应显示合作/叛逃的图形（颜色是社区聚类的情况）
% legend('节点连线', '节点位置');
% 设置图形属性
axis equal;  % 使 x 轴和 y 轴的刻度相等，保持图形比例
grid on;    % 显示网格线
hold off;


%% 节点分析-各种中心性

% 创建图对象
G = graph(adjMatrix); %,featureData.City);【注意-节点名称不唯一】

x_label = featureData.Longitude;
y_label = featureData.Latitude;
coordinates = horzcat(x_label, y_label);
[numNodes, ~] = size(coordinates);

% 【注意】中心性的正确用法：C = centrality(G, TYPE)
%   'degree' -      number of edges connected to node i. 节点的重要性或中心性
%   'closeness' -   inverse sum of distances between node i and all reachable nodes. 节点与整个网络的亲近程度
%   'betweenness' - Number of shortest paths between other nodes that pass through node i. 识别信息流动的关键节点
%   'pagerank' -    ratio of time spent at node i while randomly traversing the graph.  入度和出度共同决定节点的重要性
%   'eigenvector' - eigenvector of largest eigenvalue of the adjacency matrix. 识别连接到其他重要节点的节点（卫星城市/资源供应点）

% 计算度中心性
degreeCentrality = centrality(G,"degree");

% 计算接近中心性-距离
closenessCentrality = centrality(G,"closeness");

% 计算介数中心性-包含的最短路径数量
betweennessCentrality = centrality(G,"betweenness");

% 计算声望中心性/网页排序-连接节点的重要性
pagerankCentrality = centrality(G,"pagerank");

% 特征向量中心性
eigenvectorCentrality = centrality(G,"eigenvector");

% 根据中心性值排序节点索引
[~, degreeRank] = sort(degreeCentrality, 'descend');
[~, closenessRank] = sort(closenessCentrality, 'descend');
[~, betweennessRank] = sort(betweennessCentrality, 'descend');
[~, pagerankRank] = sort(pagerankCentrality, 'descend');
[~, eigenvectorRank] = sort(eigenvectorCentrality, 'descend');


% 绘制中心性图-scatter-V2
centralities = {degreeCentrality, closenessCentrality, betweennessCentrality, eigenvectorCentrality}; %pagerankCentrality
% centralityNames = {'度中心性', '接近中心性', '介数中心性', '特征向量中心性'}; %'网页排序中心性'
centralityNames = {'Degree Centrality', 'Closeness Centrality', 'Betweenness Centrality', 'Eigenvector Centrality'}; %'网页排序中心性'

figure;
for i = 1:length(centralities)
    subplot(2, 2, i)
    scatter(coordinates(:, 1), coordinates(:, 2), 10, centralities{i}, 'filled');
    %[地图]
%     worldmap('china');framem('off');gridm('off');mlabel('off');
%     scatterm(coordinates(:, 2), coordinates(:, 1), 10, centralities{i}, 'filled');
    colormap(jet);
    colorbar;
    title(centralityNames{i}, 'FontSize',15);
    
    % 添加节点标签
    [~, sortedIndices] = sort(centralities{i}, 'descend');
    text(coordinates(sortedIndices(1:10), 1), coordinates(sortedIndices(1:10), 2), ...
        cellstr(featureData.City(sortedIndices(1:10))), 'FontSize', 16, 'FontWeight', 'normal');

    % 生成圆环图所需标签
    if i == 2 % 接近中心性
        featureData.City_circular_label = cell(numAgents, 1);
        featureData.City_circular_label = cellfun(@(x) ' ', featureData.City_circular_label, 'UniformOutput', false);
        featureData.City_circular_label(sortedIndices(1:10)) = featureData.City(sortedIndices(1:10));
    end
end

fig = gcf;
fig.WindowState = 'maximized';


%% 网络总体结构指标-聚类系数
% 基于邻接矩阵adjMatrix，与小世界特征进行对比

% 聚类系数图
% 聚类系数 = (2 * 该节点的邻居节点之间形成的三角形数量) / (度数 * (度数 - 1))
[clusteringCoefficients, clusteringCoefficients_Yes] = clustering_coef(adjMatrix,strategyMatrix, featureData.Type_DI_GDP);
featureData.clusteringCoefficients = clusteringCoefficients;
featureData.clusteringCoefficients_Yes = clusteringCoefficients_Yes;

figure;
subplot(1, 2, 1);
hold on;
scatter(featureData.Longitude, featureData.Latitude, 15, featureData.clusteringCoefficients , 'filled'); 
xlabel('Longitude');
ylabel('Latitude');
colorbar;clim([0, 1]);
subplot(1, 2, 2);
scatter(featureData.Longitude, featureData.Latitude, 15, featureData.clusteringCoefficients_Yes , 'filled'); 
title('Current clustering coefficients');
% scatter(featureData.Longitude(strategyMatrix == 2), ...
%         featureData.Latitude(strategyMatrix == 2), 10, featureData.clusteringCoefficients_Yes(strategyMatrix == 2) ,'filled');%, 'Marker','square'); 
% scatter(featureData.Longitude(strategyMatrix == 1), ...
%         featureData.Latitude(strategyMatrix == 1), 15, featureData.clusteringCoefficients_Yes(strategyMatrix == 1) , 'filled'); 

xlabel('Longitude');
ylabel('Latitude');
colormap("parula");
colorbar;clim([0, 1]);
hold off;
fig = gcf;  % 获取当前图形窗口句柄
% fig.WindowState = 'maximized';
fig.Position = [100, 100, 1200, 400]; % [left, bottom, width, height]

if Analys_mode_2020_carbonPrice

    % 【实际政策情况】
    [~, clusteringCoefficients_Yes1] = clustering_coef(adjMatrix, featureData.Strategy_2021, featureData.Type_DI_GDP);
    [~, clusteringCoefficients_Yes2] = clustering_coef(adjMatrix, featureData.Strategy_2022, featureData.Type_DI_GDP);
    [~, clusteringCoefficients_Yes3] = clustering_coef(adjMatrix, featureData.Strategy_2023, featureData.Type_DI_GDP);
    [~, clusteringCoefficients_Yes4] = clustering_coef(adjMatrix, featureData.Good_Strategy_2023, featureData.Type_DI_GDP);

    figure;
    hold on;
    subplot(2,2,1);
    scatter(featureData.Longitude, featureData.Latitude, 15, clusteringCoefficients_Yes1 , 'filled'); 
    xlabel('Longitude');ylabel('Latitude');
    subplot(2,2,2);
    scatter(featureData.Longitude, featureData.Latitude, 15, clusteringCoefficients_Yes2 , 'filled'); 
    xlabel('Longitude');ylabel('Latitude');
    subplot(2,2,3);
    scatter(featureData.Longitude, featureData.Latitude, 15, clusteringCoefficients_Yes3 , 'filled'); 
    xlabel('Longitude');ylabel('Latitude');
    subplot(2,2,4);
    scatter(featureData.Longitude, featureData.Latitude, 15, clusteringCoefficients_Yes4 , 'filled'); 
    xlabel('Longitude');ylabel('Latitude');
    colormap("turbo");
    colorbar;clim([0, 1]);
    fig = gcf;  % 获取当前图形窗口句柄
    fig.WindowState = 'maximized';
    hold off
end

%% 邻接矩阵圆环图-与小世界对比
figure;
circularGraph(adjMatrix,'label',featureData.City_circular_label); % 标记出接近中心性前10的城市 
colormap('prism');
% Marker = 'none' 'o'; %'Colormap',myColorMap


figure
% 指标1-度分布
% 小世界网络通常具有幂律度分布
degrees = sum(adjMatrix, 2); % 计算每个节点的度
[f, x] = cdfplot(degrees); % 计算累积分布函数
hold on
pd = fitdist(degrees+1,'Exponential'); %'Lognormal'); % 拟合对数正态分布
N = length(adjMatrix);
k = round(mean(degrees)/2);
p = 0.3;    % p=0 is a ring lattice, and p = 1 is a random graph
rewiredGraph = WattsStrogatz(N, k, p); % 【注意】要先在命令行点开一下才能运行？
% mean node degree 2*K 则 k=平均度数/2

adjMatrix_SW = zeros(numNodes, numNodes);
% 遍历边的列表，将连接的节点在邻接矩阵中标记为连接
for i = 1:size(rewiredGraph.Edges, 1)
    node1 = rewiredGraph.Edges.EndNodes(i, 1);
    node2 = rewiredGraph.Edges.EndNodes(i, 2);
    adjMatrix_SW(node1, node2) = 1;
    adjMatrix_SW(node2, node1) = 1; % 对于无向图，需要设置对称元素
end

rewiredDegrees = sum(adjMatrix_SW, 2);
[f, x] = cdfplot(rewiredDegrees); % 计算累积分布函数
legend('原始网络', '小世界网络');
hold off

% 绘制小世界网络度分布的直方图
figure
histogram(degrees, 'Normalization', 'probability', 'BinWidth', 0.6);
hold on
histogram(rewiredDegrees, 'Normalization', 'probability', 'BinWidth', 0.6,'FaceColor','r');
legend('原始网络', '小世界网络');
xlabel('Degrees');
ylabel('Probility');
hold off