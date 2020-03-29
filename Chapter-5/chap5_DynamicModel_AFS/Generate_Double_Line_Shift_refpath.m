%***************************************************************%
% ��������˫��������Ĳο���·
% �趨�����ٶ�Ϊ1m/s, ����ʱ��Ϊ0.1s, ���ÿ��·����x�����ϵľ���Ϊ0.1m
% �����Ĳο�·�������.mat�ļ���[X_ref, Yref, Heading_ref]
%---------------------------------------------------------------%
% Published by: Kai Liu
% Email:leoking1025@gmail.com
% My homepage: https://sites.google.com/site/kailiumiracle/ 
%***************************************************************%
    %---------------˫���߹켣��״����-------%
    shape = 2.4;%�������ƣ����ڲο��켣����
    dx1 = 25; 
    dx2 = 21.95;%û���κ�ʵ�����壬ֻ�ǲ�������
    dy1 = 4.05; 
    dy2 = 5.7;%û���κ�ʵ�����壬ֻ�ǲ�������
    Xs1 = 27.19; 
    Xs2 = 56.46;%��������

    DataNum = 3000; %
    DLS_path_cell = cell(DataNum,1);
    Ts    = 0.1;   
    X_DOT = 1.0;  %��������ϵ�������ٶ�
    
%%    
    X_0   = -50;  % �ο�·����X�����ʼ����
    Line_segment_Num = 500;
    for p = 1 : 1 : Line_segment_Num
        X_ref       = X_0 + X_DOT * p * Ts; %���ȼ����δ��X��λ��
        Y_ref       = 0;
        Heading_ref = 0;
        DLS_path_cell{p,1} = [X_ref, Y_ref, Heading_ref];
    end

    X_0 = 0;
    for p = 1 : 1 : DataNum-Line_segment_Num
        X_ref       = X_0 + X_DOT * p * Ts; %���ȼ����δ��X��λ��
        z1          = shape/dx1*(X_ref - Xs1) - shape/2;
        z2          = shape/dx2*(X_ref - Xs2) - shape/2;
        Y_ref       = dy1/2*(1+tanh(z1)) - dy2/2*(1+tanh(z2));
        Heading_ref = atan(dy1*(1/cosh(z1))^2*(1.2/dx1) - dy2*(1/cosh(z2))^2*(1.2/dx2));
        DLS_path_cell{Line_segment_Num + p,1} = [X_ref, Y_ref, Heading_ref];
    end
    
    
    DLS_path=cell2mat(DLS_path_cell);

    save Waypoints_Double_Line_Shift.mat DLS_path;

%%
figure(1)
plot(DLS_path(:,1), DLS_path(:,2), 'k');

figure(2)
plot(1:DataNum, DLS_path(:,3), 'b');







