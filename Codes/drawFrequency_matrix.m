function [] = drawFrequency_matrix(filename, numIterations, DI_draw) %, varargin) %不定数量的参数输入
% filename: 储存了strategyFreq_file_1_matrix等变量的文件名
%   例如 文件名：'Frequency_matrix_CarbonPrice'
%        变量名：'CarbonPrice_%d'% 
% DI_draw：是否按DI分类绘图，目前仅限展示实时结果用
% numIteration：频率变化图的横坐标x


filename_load = sprintf('%s.mat',filename);

StructData_loaded = load(filename_load); % 注意，读取的是[结构体]
% 不按DI分类时，结构体的相应字段，作为图例的标注

if DI_draw ~= 1 % 不按DI区分，全部main循环结束后才画图
    
    matrix_names = fieldnames(StructData_loaded.outputData_matrix);
    num_matrix = numel(matrix_names);
    
    figure;
    for i = 1:num_matrix % 依次遍历 n 个参数并绘图
        % 读取每一种参数下数多次迭代的矩阵结果
        matrix_name = matrix_names{i};
        matrix_data = StructData_loaded.outputData_matrix.(matrix_name);
        colors = {[0 0.4470 0.7410],...
                    [0.8500 0.3250 0.0980],...
                    [0.9290 0.6940 0.1250],...
                    [0.4940 0.1840 0.5560],...
                    [0.4660 0.6740 0.1880]};  % 自行定义颜色【0414注意】这样最多画5个值
%         colors = {[1 0 0],...
%                     [0 0 1],...
%                     [0 1 0],...
%                     [0.4940 0.1840 0.5560],...
%                     [0.4660 0.6740 0.1880]}; % [0414批注]反事实情景图的颜色
        matrix_color = colors{i};

        mean_matrix = mean(matrix_data, 1);
        std_matrix = std(matrix_data, 0, 1);
        x = 0:numIterations;
        y = mean_matrix;
        yStd = std_matrix;
        xConfidence = [x, fliplr(x)]; % 创建闭合的 x 坐标
        yConfidence = [y + yStd, fliplr(y - yStd)]; % 创建闭合的 y 坐标

        display_name = strrep(strrep(matrix_name, '_', ' '),'AAA','');
        % 绘图
        plot(0:numIterations, mean_matrix, 'LineWidth', 2 , 'DisplayName', display_name, 'Color', matrix_color);
        hold on;
        fill(xConfidence, yConfidence, matrix_color,'FaceAlpha', 0.15, 'EdgeColor','none','DisplayName','Standard deviation');
        if i == num_matrix
            ylim([0 1.001])
            xlim([0 numIterations]);
            lgd = legend('Location','best','Orientation','horizontal','NumColumns',2,'FontSize',12);
            title(lgd, filename); % 以文件名命名图例标题
            ylabel('Frequency');
            xlabel('Iterations');
            set(gca,'Fontsize',12)
            fig = gcf; % 获取当前窗口句柄
            fig.Position = [500, 100, 800, 600]; % [left, bottom, width, height]
            box on;
            grid off;
            hold off;
        end
    end

elseif DI_draw == 1 % 按DI区分，每一次main循环实时图
   strategyFreq_file_1_matrix = StructData_loaded.realtime_struct.strategyFreq_file_1_matrix;
   strategyFreq_file_Type1_1_matrix = StructData_loaded.realtime_struct.strategyFreq_file_Type1_1_matrix;
   strategyFreq_file_Type2_1_matrix = StructData_loaded.realtime_struct.strategyFreq_file_Type2_1_matrix;
   strategyFreq_file_Type3_1_matrix = StructData_loaded.realtime_struct.strategyFreq_file_Type3_1_matrix;
   strategyFreq_file_Type4_1_matrix = StructData_loaded.realtime_struct.strategyFreq_file_Type4_1_matrix;

    %【0414待完成】调成函数的输入参数
    color_Tpye1 = "#008d00"; color_Tpye1_rgb = [0 141 0]/255;      % strong decoupling
    color_Tpye2 = "#ff9200"; color_Tpye2_rgb = [255 146 0]/255;    % weak decoupling
    color_Tpye3 = "#e5086a"; color_Tpye3_rgb = [229 8 106]/255;    % potential decoupling
    color_Tpye4 = "#cfb99e"; color_Tpye4_rgb = [207 185 158]/255;  % no decoupling

    mean_matrix = mean(strategyFreq_file_1_matrix, 1);
    std_matrix = std(strategyFreq_file_1_matrix, 0, 1);
    mean_matrix_type1 = mean(strategyFreq_file_Type1_1_matrix, 1);
    mean_matrix_type2 = mean(strategyFreq_file_Type2_1_matrix, 1);
    mean_matrix_type3 = mean(strategyFreq_file_Type3_1_matrix, 1);
    mean_matrix_type4 = mean(strategyFreq_file_Type4_1_matrix, 1);
    std_matrix_type1 = std(strategyFreq_file_Type1_1_matrix, 0, 1);
    std_matrix_type2 = std(strategyFreq_file_Type2_1_matrix, 0, 1);
    std_matrix_type3 = std(strategyFreq_file_Type3_1_matrix, 0, 1);
    std_matrix_type4 = std(strategyFreq_file_Type4_1_matrix, 0, 1);

    figure; % 按均值，画折线
    plot(0:numIterations, mean_matrix, 'LineWidth', 2 , 'DisplayName', 'All Cities');
    hold on;
    plot(0:numIterations, mean_matrix_type1, ':', 'LineWidth', 1.5 , 'DisplayName', 'Strong Decoupling','Color', color_Tpye1);
    plot(0:numIterations, mean_matrix_type2, ':', 'LineWidth', 1.5 , 'DisplayName', 'Weak Decoupling','Color', color_Tpye2);
    plot(0:numIterations, mean_matrix_type3, ':', 'LineWidth', 1.5 , 'DisplayName', 'Potential Decoupling','Color', color_Tpye3);
    plot(0:numIterations, mean_matrix_type4, ':', 'LineWidth', 1.5 , 'DisplayName', 'No Decoupling','Color', color_Tpye4);
    ylim([0 1.001])
    xlim([0 numIterations]); %xticks(0:numIterations);%xticks([0:10]);
    legend('Location','northeast');
    ylabel('Frequency');
    xlabel('Iterations');

    % 按标准差，画置信区间
    x = 0:numIterations;
    y = mean_matrix;
    yStd = std_matrix;
    y_Type1 = mean_matrix_type1;
    y_Type2 = mean_matrix_type2;
    y_Type3 = mean_matrix_type3;
    y_Type4 = mean_matrix_type4;
    yStd_Type1 = std_matrix_type1;
    yStd_Type2 = std_matrix_type2;
    yStd_Type3 = std_matrix_type3;
    yStd_Type4 = std_matrix_type4;

    xConfidence = [x, fliplr(x)]; % 创建闭合的 x 坐标
    yConfidence = [y + yStd, fliplr(y - yStd)]; % 创建闭合的 y 坐标
    yConfidence_Type1 = [y_Type1 + yStd_Type1, fliplr(y_Type1 - yStd_Type1)];
    yConfidence_Type2 = [y_Type2 + yStd_Type2, fliplr(y_Type2 - yStd_Type2)];
    yConfidence_Type3 = [y_Type3 + yStd_Type3, fliplr(y_Type3 - yStd_Type3)];
    yConfidence_Type4 = [y_Type4 + yStd_Type4, fliplr(y_Type4 - yStd_Type4)];

    fill(xConfidence, yConfidence, 'b','FaceAlpha', 0.15, 'EdgeColor','none','DisplayName','Standard deviation');
    fill(xConfidence, yConfidence_Type1, color_Tpye1_rgb, 'FaceAlpha', 0.1, 'EdgeColor','none','DisplayName','Standard deviation');
    fill(xConfidence, yConfidence_Type2, color_Tpye2_rgb, 'FaceAlpha', 0.1, 'EdgeColor','none','DisplayName','Standard deviation');
    fill(xConfidence, yConfidence_Type3, color_Tpye3_rgb, 'FaceAlpha', 0.1, 'EdgeColor','none','DisplayName','Standard deviation');
    fill(xConfidence, yConfidence_Type4, color_Tpye4_rgb, 'FaceAlpha', 0.2, 'EdgeColor','none','DisplayName','Standard deviation');
    xlim([0,numIterations]);
    ylim([0 1.001]);
    ylabel('Frequency');
    xlabel('Iterations');
    legend('Location','northeast');
    lgd = legend('Location','best','Orientation','vertical','NumColumns',2,'FontSize',12);
    fig = gcf; % 获取当前窗口句柄
    fig.Position = [500, 100, 600, 500];
    grid off;
    hold off;
end