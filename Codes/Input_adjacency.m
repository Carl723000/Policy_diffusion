function [selected_variables_table,adjacency_matrix,connectivity] = Input_adjacency(filename, target_variables, threshold_distance, year, gravity_mode)
% function adjacency_matrix = city_network_adjacency(filename, target_variable, threshold_distance)
    % filename: EXCEL数据集文件名
    % target_variables: 包含一系列变量名的cell数组
    % threshold_distance: 阈值距离，小于此距离的城市之间将建立连接
    % year：录入数据对应的年份
    % gravity_mode：引力模型的类别，影响邻接矩阵的结果

    Year_now = num2str(year);
    Year_history = num2str(year-5);
    % 读取EXCEL数据集文件
    data = readtable(filename, 'Sheet', Year_now);
    data1 = readtable(filename, 'Sheet', Year_history, 'Range', 'R:AN');
%     data1 = readtable(filename, 'Sheet', '2005');
%     historical_emmision = data1(data1.Integrity == 1,'Total');
%     variables_history = {'Total', 'Integrity'};
%     data1 = readtable(filename, 'Sheet', Year_history,'SelectedVariableNames', variables_history);
    data1 = data1(data1.Integrity ==1, 1);
    data1.Properties.VariableNames{1} = 'historical_emmision';

    % 【疑惑】应该是每个城市，作为一个结构体。还是所有城市作为一整个结构体？
    % 【解决方案】还是表格，暂不弄复杂了
    % 【方式1-一个结构体】输出已读取的变量作为一个结构体 selected_variables
%     selected_variables = struct();
%     for i = 1:length(target_variables)
%         selected_variables.(target_variables{i}) = data.(target_variables{i});
%     end
    % 根据输入的变量名获取指定的变量 
    % Inputdata = data.(target_variable);
    % selected_variables = cell2struct(cell(length(target_variables), 1), target_variables, 1);
    % for i = 1:length(target_variables)
    %     selected_variables.(target_variables{i}) = data.(target_variables{i});
    % end
    %【方式2-结构体数组-待完成】读取成编号调用
%       selected_variables = struct('City',{}, 'Longitude',{}, 'Latitude', {},'Permanent_population_10K',{},'GDP_100M',{}, ...
%              'Total',{}, 'Per_capita_emissions',{}, 'CO2_emissions_per_GDP',{});

    % 2020年至今的碳政策实施情况    
    if year == 2020
        variables_2020 = {'Strategy_2020', 'Strategy_2021', 'Strategy_2022', 'Strategy_2023', 'Good_Strategy_2023'};
        target_variables = [target_variables, variables_2020];
    end

    %【方式3-表格】
%     selected_variables_table = data(:, target_variables);
%     selected_variables_table = [selected_variables_table, data1];
    selected_variables_table = data(data.Integrity ==1, target_variables);
    selected_variables_table = [selected_variables_table, data1];
    
    if year ~= 2020
        Current_strategys = readtable(filename, 'Sheet', '2020', 'Range', 'AG:AN');%【待修改】不同年份数据，函数输入参数
        Current_strategys = Current_strategys(Current_strategys.Integrity == 1, 1:5);
        selected_variables_table = [selected_variables_table, Current_strategys];
    end
    
    city_latitudes = selected_variables_table.Latitude;
    city_longitudes = selected_variables_table.Longitude;
    
    % 计算城市之间的距离
    num_cities = length(city_longitudes);
    distances = zeros(num_cities);
    % 重力模型参数
    %【可扩展】根据实证数据，拟合距离/排放/GDP与连接性的关系，所得系数作为参数。
    % 但是，本研究中，"连接性"并没有可真实对应的内容（航线流量 vs 行距）。
    k = 1;  % 比例常数    % k1 = 10^(-5);  k2 = 1;
    alpha = 1;      % 人口参数
    beta = 1;       % GDP参数
    gamma = 1;     % 距离参数
    delta = 1;      % 碳排放参数
    epsilon = 1;    % DI指数参数
    % 初始化各种邻接矩阵
    connectivity_pop = zeros(num_cities,num_cities);
    connectivity_pop_gdp = zeros(num_cities,num_cities);
    connectivity_pop_gdp_carbon = zeros(num_cities,num_cities);
    connectivity_DI = zeros(num_cities,num_cities);
    for i = 1:num_cities
        for j = 1:num_cities
            distances(i,j) = haversine(city_latitudes(i), city_longitudes(i), city_latitudes(j), city_longitudes(j)); % 单位：km
            if i ~= j && gravity_mode ~=-1
                switch gravity_mode
                    case 1
                        % 1-人口+距离；几百万人+几百km
                        connectivity_pop(i,j) = k * (selected_variables_table.Permanent_population_10K(i)^(alpha*0.5)) ...
                            * (selected_variables_table.Permanent_population_10K(j)^(alpha*0.5)) ...
                            / (distances(i,j)^(gamma));
                    case 2
                        % 2-人口+GDP+距离 几百(万人)+几百(km)+几千(亿)
                        connectivity_pop_gdp(i,j) = k * (selected_variables_table.Permanent_population_10K(i)^(alpha*0.5)) ...
                            * (selected_variables_table.Permanent_population_10K(j)^(alpha*0.5)) ...
                            * (selected_variables_table.GDP_100M(i)^(beta*0.7)) ...
                            * (selected_variables_table.GDP_100M(j)^(beta*0.7)) ...
                            / (distances(i,j)^(gamma));
                    case 3
                        % 3-人口+GDP+碳排放+距离 几百(万人)+几百(km)+几千(亿)+几千(万吨)
                        connectivity_pop_gdp_carbon(i,j) = k *((selected_variables_table.Permanent_population_10K(i)^(alpha)) ...
                            * (selected_variables_table.Permanent_population_10K(j)^(alpha)) ...
                            * (selected_variables_table.GDP_100M(i)^(beta)) ...
                            * (selected_variables_table.GDP_100M(j)^(beta)) ...
                            * (selected_variables_table.Total(i)^(delta)) ...
                            * (selected_variables_table.Total(j)^(delta)) ...
                            )^(1/3) ...
                            / (distances(i,j)^(gamma));
                        %                                      【报错】2,12 不对称； 70,180不对称；1,134不对称
                    case 4
                        % 4-DI+距离
                        connectivity_DI(i,j) = k * (selected_variables_table.DI_POP(i)^epsilon) ...
                            * (selected_variables_table.DI_POP(j)^epsilon) ...
                            * (selected_variables_table.GDP_100M(i)^(beta)) ...
                            * (selected_variables_table.GDP_100M(j)^(beta)) ...
                            / (distances(i,j)^(gamma));
                        %                                       【报错】163,90不对称
                end
            end
        end
    end

    % 选择模式，生成邻接矩阵
    switch gravity_mode
        case -1 % 不用输出
            adjacency_matrix = [];
            connectivity = [];
        case 0  % 地理距离阈值
            adjacency_matrix = distances <= threshold_distance;
            connectivity = distances;
            % 【注意，重要】这里生成的是0/1变量，仅包括是否相连接，不包括距离。
        case 1  % 人口+距离
            %connectivity_pop_threshold = mean(connectivity_pop(:)); % 连接性大于均值算连接
            connectivity_pop_threshold = prctile(connectivity_pop(:),98); % 连接性大于97分位数算连接    
            adjacency_matrix = connectivity_pop >= connectivity_pop_threshold;
            connectivity = connectivity_pop;
        case 2  % 人口+GDP+距离
            connectivity_pop_gdp_threshold = prctile(connectivity_pop_gdp(:),98);            
            adjacency_matrix = connectivity_pop_gdp >= connectivity_pop_gdp_threshold; 
            connectivity = connectivity_pop_gdp;
        case 3  % 人口+GDP+碳排放+距离
            connectivity_pop_gdp_carbon_threshold = prctile(connectivity_pop_gdp_carbon(:),98);            
            adjacency_matrix = connectivity_pop_gdp_carbon >= connectivity_pop_gdp_carbon_threshold;  
            connectivity = connectivity_pop_gdp_carbon;
         case 4 % DI指数
            connectivity_DI_threshold = prctile(connectivity_DI(:),98);            
            adjacency_matrix = connectivity_DI >= connectivity_DI_threshold;   
            connectivity = connectivity_DI;
    end

    % 重力模型建立
end

function distance = haversine(lat1, lon1, lat2, lon2)
    % 计算两点之间的距离（使用Haversine公式）
    earth_radius = 6371;  % 地球半径，单位：千米
    dlat = deg2rad(lat2 - lat1);
    dlon = deg2rad(lon2 - lon1);
    a = sin(dlat/2)^2 + cos(deg2rad(lat1)) * cos(deg2rad(lat2)) * sin(dlon/2)^2;
    c = 2 * atan2(sqrt(a), sqrt(1-a));
    distance = earth_radius * c;
end