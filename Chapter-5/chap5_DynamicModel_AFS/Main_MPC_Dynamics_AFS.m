function [sys,x0,str,ts] =Main_MPC_Dynamics_AFS(t,x,u,flag)
%***************************************************************%
% �ó����ܣ������Ի��ĳ�������ѧģ�ͣ�С�Ƕȼ��裩���MPC��������
% ʵ�ֲ�ͬ·������������µ�˫���߸��٣�������Simulink/CarSimʵ�����Ϸ���
% MATLAB�汾��R2013b,CarSim�汾��8.1
% ״̬��=[y_dot,x_dot,phi,phi_dot,Y,X]��������Ϊǰ��ƫ��delta_f

% Input:
% t�ǲ���ʱ��, x��״̬����, u������(������simulinkģ�������,��CarSim�����),
% flag�Ƿ�������е�״̬��־(�������жϵ�ǰ�ǳ�ʼ���������е�)

% Output:
% sys�������flag�Ĳ�ͬ����ͬ(���潫���flag����sys�ĺ���), 
% x0��״̬�����ĳ�ʼֵ, 
% str�Ǳ�������,����Ϊ��
% ts��һ��1��2������, ts(1)�ǲ�������, ts(2)��ƫ����
%---------------------------------------------------------------%
% Published by: Kai Liu
% Email:leoking1025@bit.edu.cn
% My github: https://github.com/leoking99-BIT
%***************************************************************% 
    switch flag,
        case 0 % Initialization %
            [sys,x0,str,ts] = mdlInitializeSizes; % Initialization
        case 2 % Update %
            sys = mdlUpdates(t,x,u); % Update discrete states
        case 3 % Outputs %
            sys = mdlOutputs(t,x,u); % Calculate outputs
        case {1,4,9} % Unused flags
            sys = [];            
        otherwise % Unexpected flags %
            error(['unhandled flag = ',num2str(flag)]); % Error handling
    end %  end of switch    
%  End sfuntmpl

function [sys,x0,str,ts] = mdlInitializeSizes
%==============================================================
% Initialization, flag = 0��mdlInitializeSizes
% Return the sizes, initial conditions, and sample times for the S-function.
%==============================================================
sizes = simsizes;%��������ģ������Ľṹ����simsizes������
sizes.NumContStates  = 0;  %ģ������״̬�����ĸ���
sizes.NumDiscStates  = 6;  %ģ����ɢ״̬�����ĸ���,ʵ����û���õ������ֵ��ֻ�����������ʾ��ɢģ��
sizes.NumOutputs     = 7;  %S��������������������������������
sizes.NumInputs      = 25; %S����ģ����������ĸ�������CarSim�������
sizes.DirFeedthrough = 1;  %ģ���Ƿ����ֱ�ӹ�ͨ(direct feedthrough). 
sizes.NumSampleTimes = 1;  %ģ��Ĳ���������>=1
sys = simsizes(sizes);    %������󸳸�sys���
x0 = zeros(sizes.NumDiscStates,1);%initial the  state vector�� of no use

str = [];             % ����������Set str to an empty matrix.
ts  = [0.05 0];       % ts=[period, offset].��������sample time=0.05s 

%--Global parameters and initialization
    % [y, e] = func_RLSFilter_Ccf('initial', 0.95, 10, 10);
    % [y, e] = func_RLSFilter_Ccr('initial', 0.95, 10, 10);
    % [y, e] = func_RLSFilter_Clf('initial', 0.95, 10, 10);
    % [y, e] = func_RLSFilter_Clr('initial', 0.95, 10, 10);

global InitialGapflag; 
    InitialGapflag = 0; % the first few inputs don't count. Gap it.
    
global VehiclePara; % for SUV
    VehiclePara.m   = 1600;   %mΪ��������,Kg; Sprung mass = 1370
    VehiclePara.g   = 9.81;
    VehiclePara.hCG = 0.65;%m
    VehiclePara.Lf  = 1.12;  % 1.05
    VehiclePara.Lr  = 1.48;  % 1.55
    VehiclePara.L   = 2.6;  %VehiclePara.Lf + VehiclePara.Lr;
    VehiclePara.Tr  = 1.565;  %c,or 1.57. ע����᳤��lc��δȷ��
    VehiclePara.mu  = 0.85; % 0.55; %����Ħ������
    VehiclePara.Iz  = 2059.2;   %IΪ������Z���ת���������������в���  
    VehiclePara.Ix  = 700.7;   %IΪ������Z���ת���������������в���  
    VehiclePara.Radius = 0.387;  % ��̥�����뾶   
    
global MPCParameters; 
    MPCParameters.Np  = 25;% predictive horizon Assume Np=Nc
    MPCParameters.Nc  = 15; %  Tsplit
    MPCParameters.Ts  = 0.05; % the sample time of near term  
    MPCParameters.Nx  = 6; %the number of state variables
    MPCParameters.Ny  = 2; %the number of output variables      
    MPCParameters.Nu  = 1; %the number of control inputs
    
global WarmStart;
    WarmStart = zeros(MPCParameters.Nu * MPCParameters.Nc,1);
    
global CostWeights; 
    CostWeights.Wephi    = 100; %state vector =[beta,yawrate,e_phi,s,e_y]
    CostWeights.Wey      = 100;
    CostWeights.WDdeltaf = 1000;

global Constraints;
%     Constraints.dumax   = 0.08; % Units: rad,0.08rad=4.6deg
%     Constraints.dumax   = 0.1; % Units: rad,0.1rad=5.7deg  
    Constraints.dumax   = 0.0148; % Units: rad,0.0148rad = 0.8deg
    Constraints.umax    = 0.4;  % Units: rad, 0.4rad=23deg
    
    Constraints.ycmin   = [-0.5;  -5];
    Constraints.ycmax   = [0.5;   5];

global WayPoints_IndexPre;
    WayPoints_IndexPre = 1;

global Reftraj;
    Reftraj = load('Waypoints_Double_Line_Shift.mat'); 
    
%  End of mdlInitializeSizes

function sys = mdlUpdates(t,x,u)
%==============================================================
% Update the discrete states, flag = 2�� mdlUpdate
% Handle discrete state updates, sample time hits, and major time step
% requirements.
%==============================================================
%  ����û���õ�������̣��ں��ڵĳ���ģ�黯ʱ���Լ�������������ܡ�
    sys = x;    
% End of mdlUpdate.

function sys = mdlOutputs(t,x,u)
%==============================================================
% Calculate outputs, flag = 3�� mdlOutputs
% Return the block outputs. 
%==============================================================
%***********Step (1). Parameters Initialization ***************************************%

global InitialGapflag;
global VehiclePara;
global MPCParameters; 
global WarmStart;
global CostWeights;     
global Constraints;
global WayPoints_IndexPre;
global Reftraj;
    
Ts = MPCParameters.Ts;
Np = MPCParameters.Np;
Nc = MPCParameters.Nc;
Nx = MPCParameters.Nx;
Ny = MPCParameters.Ny;
Nu = MPCParameters.Nu;
Naug = Nx + Nu;

Steer_SW_deg    = 0;
t_Elapsed       = 0;
PosX            = 0;
PosY            = 0;
PosPhi          = 0;
e_psi           = 0;
e_y             = 0;

if InitialGapflag < 2 %  get rid of the first two inputs
    InitialGapflag = InitialGapflag + 1;
else % start control
    InitialGapflag = InitialGapflag + 1;
    %**********Step (2). Update state and tire-stiffness estimation ******% 
    t_Start = tic; % ��ʼ��ʱ  
    %-----Update State Estimation of measured Vehicle Configuration-------%
    y_dot = u(1)/3.6; %CarSim�������km/h��ת��Ϊm/s
    x_dot = u(2)/3.6;%CarSim�������km/h��ת��Ϊm/s
    if (0 == x_dot) %��x_dot=0��������Ϊһ���ǳ�С��������ֹ���ַ�ĸΪ������
        x_dot = 0.001;
    end
    PosPhi = u(3)*pi/180; %CarSim�����Ϊ�Ƕȣ��Ƕ�ת��Ϊ����
    phi_dot = u(4)*pi/180;% deg/s-->rad/s
    PosY = u(5);%��λΪm
    PosX = u(6);%��λΪ��
    steer_L1 = u(7);
    steer_R1 = u(8);
    steer_deg = 0.5*(steer_L1 + steer_R1);
    delta_f_rad = steer_deg*pi/180;
    Beta = u(9)*pi/180;% �������Ĳ�ƫ��, Unit:deg-->rad
    slip_ratio_L1 = u(10);
    slip_ratio_L2 = u(11);
    slip_ratio_R1 = u(12);
    slip_ratio_R2 = u(13);
    Sf = 0.5*(slip_ratio_L1 +slip_ratio_R1);%ǰ�ֵĻ�����
    Sr = 0.5*(slip_ratio_L2 +slip_ratio_R2);%���ֵĻ�����
    alpha_L1 = u(14);
    alpha_L2 = u(15);
    alpha_R1 = u(16);
    alpha_R2 = u(17);
    alpha_f = 0.5*(alpha_L1 + alpha_R1);
    alpha_r = 0.5*(alpha_L2 + alpha_R2);
    Fy_l1      = round(10*u(18))/10; % N 
    Fy_l2      = round(10*u(19))/10; % N 
    Fy_r1      = round(10*u(20))/10; % N 
    Fy_r2      = round(10*u(21))/10; % N 
    Fyf        = Fy_l1 + Fy_r1;
    Fyr        = Fy_l2 + Fy_r2;
    Fx_L1      = u(22);
    Fx_L2      = u(23);
    Fx_R1      = u(24);
    Fx_R2      = u(25);    
    Fxf        = Fx_L1 + Fx_R1;
    Fxr        = Fx_L2 + Fx_R2;

    %-----Update augmented state vector--------------% 
    kesi    = zeros(Naug, 1);
    kesi(1) = y_dot;
    kesi(2) = x_dot;
    kesi(3) = PosPhi;
    kesi(4) = phi_dot;
    kesi(5) = PosY;
    kesi(6) = PosX;
    kesi(7) = delta_f_rad;   
    
    % C_cf C_cr C_lf C_lr�ֱ�Ϊǰ���ֵ��ݺ����ƫ�նȣ��������в���    
    %----Estimate Lateral Cornering stiffness with RLS-------------------%  
    alpha_f_Hat = (Beta + phi_dot*VehiclePara.Lf/x_dot - delta_f_rad);
    [Fyf_hat, Ccf_1] = func_RLSEstimation_Ccf(alpha_f_Hat, Fyf);
    C_cf = sum(Ccf_1);
    if C_cf > -30000
        C_cf = -110000;
    end
    alpha_r_Hat = (Beta - phi_dot*VehiclePara.Lr/x_dot);
    [Fyr_hat, Ccr_1] = func_RLSEstimation_Ccr(alpha_r_Hat, Fyr);
    C_cr = sum(Ccr_1);
    if C_cr > -30000
        C_cr = -92000;
    end

    %-----Estimate Longitudinal Cornering stiffness with RLS--------------%
    Sf_Hat = Sf;
    [Fxf_hat, Clf_1] = func_RLSEstimation_Clf(Sf_Hat, Fxf);
    C_lf = sum(Clf_1);
    
    Sr_Hat = Sr;
    [Fxr_hat, Clr_1] = func_RLSEstimation_Clf(Sr_Hat, Fxr);
    C_lr = sum(Clr_1);
    
    %-----Use Constant tire stiffness  -------------------%  
%     C_cf = -57218; 
%     C_cr = -67587; 
%     
%     C_lf = 12650; 
%     C_lr = 99141;

    %*******Step(3): ����״̬���� **********************************%    
    % �����Ҳ����Ҫ�ľ����ǿ������Ļ��������ö���ѧģ��
    % �þ����복������������أ�ͨ���Զ���ѧ��������ſ˱Ⱦ���õ�
    [Ad, Bd] = func_Model_linearization_Jacobian(kesi, Sf, Sr, C_cf, ...
                                             C_cr, C_lf, C_lr, ...
                                             MPCParameters, VehiclePara);

    A_cell = cell(2,2);
    A_cell{1,1} = Ad;
    A_cell{1,2} = Bd;
    A_cell{2,1} = zeros(Nu,Nx);
    A_cell{2,2} = eye(Nu);
    A = cell2mat(A_cell);
    
    B_cell = cell(2,1);
    B_cell{1,1} = Bd;
    B_cell{2,1} = eye(Nu);
    B = cell2mat(B_cell);

    C = [0 0 1 0 0 0 0;
         0 0 0 0 1 0 0];
                                                                             
	%*******Step(4): �ο��켣���� **********************************%    
%     %���¼�Ϊ������ɢ������ģ��Ԥ����һʱ��״̬�� 
%     [state_k1, Yita_ref] = func_Reftraj_doublelane(kesi, Sf, Sr, MPCParameters, ...
%                                          VehiclePara, C_cf, C_cr, C_lf, C_lr);
%     d_k = state_k1-Ad*kesi(1:6,1)-Bd*kesi(7,1);%����falcone��ʽ��2.11b�����d(k,t)
%     d_piao_k = zeros(Nx+Nu, 1);%d_k��������ʽ
%     d_piao_k(1:6,1) = d_k;
%     d_piao_k(7,1) = 0;
    
%      e_psi = kesi(3) - state_k1(3);
%      if(e_psi > pi)
%          e_psi = e_psi - 2*pi;
%      end
%      if(e_psi < -pi)
%          e_psi = e_psi + 2*pi;
%      end
%      e_y   = kesi(5) - state_k1(5);
     
     
    [WPIndex, Yita_ref, RefU] = func_RefTraj_LocalPlanning_DSL(MPCParameters,... 
                                            VehiclePara,... 
                                            WayPoints_IndexPre,... 
                                            Reftraj.DLS_path,... 
                                            kesi);
    if ( WPIndex <= 0)
       fprintf('Error: WPIndex <= 0 \n');    %����
    else      
        WayPoints_IndexPre = WPIndex;        
    end
    
    d_piao_k = zeros(Nx+Nu, 1);%d_k��������ʽ
   
    %****Step(5):  MPC formulation;********************% 
    %------Update prediction, ETA = PSI*kesi + GAMMA*PHI - Yref ----%
    PSI_cell=cell(Np,1);
    THETA_cell=cell(Np,Nc);
    GAMMA_cell=cell(Np,Np);
    PHI_cell=cell(Np,1);
    for p=1:1:Np;
        PHI_cell{p,1}=d_piao_k;%��������˵�������Ҫʵʱ���µģ�����Ϊ�˼�㣬������һ�ν���
        for q=1:1:Np;
            if q<=p;
                GAMMA_cell{p,q}=C*A^(p-q);
            else 
                GAMMA_cell{p,q}=zeros(Ny,Nx+Nu);
            end 
        end
    end
    for j=1:1:Np
     PSI_cell{j,1}=C*A^j;
        for k=1:1:Nc
            if k<=j
                THETA_cell{j,k}=C*A^(j-k)*B;
            else 
                THETA_cell{j,k}=zeros(Ny,Nu);
            end
        end
    end
    PSI=cell2mat(PSI_cell);%size(PSI)=[Ny*Np Nx+Nu]
    THETA=cell2mat(THETA_cell);%size(THETA)=[Ny*Np Nu*Nc]
    GAMMA=cell2mat(GAMMA_cell);%��д��GAMMA
    PHI=cell2mat(PHI_cell);
    
    %------Update Q and R
    temp = [CostWeights.Wephi, CostWeights.Wey];
    Qq = diag(temp);
    Q = kron(eye(Np), Qq);
    R = kron(eye(Nc), CostWeights.WDdeltaf);
    
    %------Update H and f, J=0.5*DU'*H*DU + f'*DU
    H = THETA'*Q*THETA + R;
    H = 0.5*(H+H');
    error_1 = PSI*kesi + GAMMA*PHI - Yita_ref; %��ƫ��
    f = error_1'*Q*THETA;
    g = f';
    
    %------Update Constaints and bounds ����Լ��---%
    %������Լ��
    A_t = zeros(Nc,Nc);%��falcone���� P181
    for p = 1:1:Nc
        for q = 1:1:Nc
            if (p >= q)
                A_t(p,q) = 1;
            else 
                A_t(p,q) = 0;
            end
        end 
    end 
    A_I = kron(A_t,eye(Nu));%������ڿ˻�
    
    Ut=kron(ones(Nc,1), delta_f_rad);
    umin = -Constraints.umax;%ά������Ʊ����ĸ�����ͬ
    umax = Constraints.umax; 
    Umin=kron(ones(Nc,1), umin);
    Umax=kron(ones(Nc,1), umax);

    A_cons_cell = { A_I; 
                    -A_I};
    A_cons=cell2mat(A_cons_cell);%����ⷽ�̣�״̬������ʽԼ���������ת��Ϊ����ֵ��ȡֵ��Χ  
   
    b_cons_cell = { Umax - Ut; 
                    -Umin + Ut};
    b_cons = cell2mat(b_cons_cell);%����ⷽ�̣�״̬������ʽԼ����ȡֵ
  
%     ycmax = Constraints.ycmax;
%     ycmin = Constraints.ycmin;
%     Ycmax = kron(ones(Np,1),ycmax);
%     Ycmin = kron(ones(Np,1),ycmin);  %�����Լ��   
%    
%     A_cons_cell = { A_I; 
%                     -A_I;
%                     THETA;
%                     -THETA};
%     A_cons=cell2mat(A_cons_cell);%����ⷽ�̣�״̬������ʽԼ���������ת��Ϊ����ֵ��ȡֵ��Χ  
%    
%     b_cons_cell = { Umax - Ut; 
%                     -Umin + Ut; 
%                     Ycmax - error_1; 
%                     -Ycmin + error_1};
%     b_cons = cell2mat(b_cons_cell);%����ⷽ�̣�״̬������ʽԼ����ȡֵ
   
    lb=kron(ones(Nc,1), -Constraints.dumax);
    ub=kron(ones(Nc,1), Constraints.dumax);
    
    %****Step(9):  Call quadprog for MPC solver;********************% 
%     options = optimset('quadprog', 'Algorithm', 'active-set');
    options = optimoptions('quadprog', 'Display','off', ...
                            'Algorithm', 'active-set'); 
    DU0 = WarmStart;
    [DU, FVAL, EXITFLAG] = quadprog(H, g, A_cons, b_cons, [], [], lb, ub, DU0, options); %
%     [DU, FVAL, EXITFLAG] = quadprog(H, g, [], [], [], [], lb, ub, DU0, options); %
    WarmStart = shiftHorizon(DU, Nu);     % Prepare restart, nominal close loop 
    
    Steer_SW_deg = 18 * (delta_f_rad + DU(1))*180/pi;
    
    t_Elapsed = toc( t_Start ); %computation time
end % end of if Initialflag < 2 % 

sys = [Steer_SW_deg; t_Elapsed; PosX; PosY; PosPhi; e_psi; e_y];
% end  %End of mdlOutputs.

%==============================================================
% sub functions
%==============================================================  
function U0 = shiftHorizon(U, Nu) %shift control horizon
    U0 = [U(Nu+1:size(U,1)); zeros(Nu,1)]; % shiftHorizon��Prepare restart
    
function [WPIndex, Yita_ref, RefU] = func_RefTraj_LocalPlanning_DSL( MPCParameters, VehiclePara, WayPoints_Index, WayPoints_Collect, VehStateVector)
    lf = VehiclePara.Lf;
    lr = VehiclePara.Lr;
    lfr = VehiclePara.L;
    m   = VehiclePara.m;
    Iz  = VehiclePara.Iz;   %IΪ������Z���ת���������������в���  
    Ts = MPCParameters.Ts;
    Np  = MPCParameters.Np;
    Nx  = MPCParameters.Nx;
    Nu  = MPCParameters.Nu;
    
    PosPsi  = VehStateVector(3);  
    PosY    = VehStateVector(5);
    PosX    = VehStateVector(6);
%*********** WaypointData2VehicleCoords ************************% 
    ds          = 0.1;%m
    WPNum       = length(WayPoints_Collect(:,1));
    
    %--------���ҵ��ο�·���Ͼ��복������ĵ�--------------------------%  
    Dist_MIN    = 1000;
    index_min   = 0;
    for i=WayPoints_Index:1:WPNum 
        deltax  = WayPoints_Collect(i,1) - PosX;
        deltay  = WayPoints_Collect(i,2) - PosY;
        Dist    = sqrt(power(deltax,2) + power(deltay,2)); %·�㵽�������ĵľ���
        if Dist < Dist_MIN
            Dist_MIN = Dist; 
            index_min = i;
        end
    end
    
    if (index_min < 1) 
        WPIndex = -1; %���û���ҵ��򡣡�
    else if ( index_min >= WPNum)
            WPIndex = -2; %���û���ҵ��򡣡�
        else
            WPIndex = index_min;
        end
    end

    Yita_ref_cell=cell(Np,1);
    for p=1:1:Np
%         X_ref = WayPoints_Collect(WPIndex+p, 1);
        Y_ref = WayPoints_Collect(WPIndex+p, 2);
        Heading_ref = WayPoints_Collect(WPIndex+p, 2);
        Yita_ref_cell{p,1} = [Heading_ref; Y_ref];
    end
    Yita_ref=cell2mat(Yita_ref_cell);
    
    RefU = zeros(Np,1);
    
% end % End of func

function [state_k1, Yita_ref] = func_Reftraj_doublelane(kesi, Sf, Sr, MPCParameters, VehiclePara, Ccf, Ccr, Clf, Clr)

% ˫���߹켣��״����
    shape=2.4;%�������ƣ����ڲο��켣����
    dx1=25; dx2=21.95;%û���κ�ʵ�����壬ֻ�ǲ�������
    dy1=4.05; dy2=5.7;%û���κ�ʵ�����壬ֻ�ǲ�������
    Xs1=27.19; Xs2=56.46;%��������

    lf = VehiclePara.Lf;
    lr = VehiclePara.Lr;
    lfr = VehiclePara.L;
    m   = VehiclePara.m;
    Iz  = VehiclePara.Iz;   %IΪ������Z���ת���������������в���  
    Ts = MPCParameters.Ts;
    Np  = MPCParameters.Np;
    Nx  = MPCParameters.Nx;
    Nu  = MPCParameters.Nu;
   
    y_dot   = kesi(1);%u(1)==X(1)
    x_dot   = kesi(2);%u(2)==X(2)
    phi     = kesi(3); %u(3)==X(3)
    phi_dot = kesi(4);
    Y       = kesi(5);
    X       = kesi(6);
    delta_f = kesi(7);   

    state_k1 = zeros(Nx, 1);
    state_k1(1,1)=y_dot+Ts*(-x_dot*phi_dot+2*(Ccf*(delta_f-(y_dot+lf*phi_dot)/x_dot)+Ccr*(lr*phi_dot-y_dot)/x_dot)/m);
    state_k1(2,1)=x_dot+Ts*(y_dot*phi_dot+2*(Clf*Sf+Clr*Sr+Ccf*delta_f*(delta_f-(y_dot+phi_dot*lf)/x_dot))/m);
    state_k1(3,1)=phi+Ts*phi_dot;
    state_k1(4,1)=phi_dot+Ts*((2*lf*Ccf*(delta_f-(y_dot+lf*phi_dot)/x_dot)-2*lr*Ccr*(lr*phi_dot-y_dot)/x_dot)/Iz);
    state_k1(5,1)=Y+Ts*(x_dot*sin(phi)+y_dot*cos(phi));
    state_k1(6,1)=X+Ts*(x_dot*cos(phi)-y_dot*sin(phi));
    
%     T_all = 20.0;    
    Yita_ref_cell=cell(Np,1);
    X_DOT=x_dot*cos(phi)-y_dot*sin(phi);%��������ϵ�������ٶ�
    for p=1:1:Np
        X_predict = X+X_DOT*p*Ts;%���ȼ����δ��X��λ��
        z1      = shape/dx1*(X_predict-Xs1) - shape/2;
        z2      = shape/dx2*(X_predict-Xs2) - shape/2;
        Y_ref   = dy1/2*(1+tanh(z1)) - dy2/2*(1+tanh(z2));
        phi_ref = atan(dy1*(1/cosh(z1))^2*(1.2/dx1) - dy2*(1/cosh(z2))^2*(1.2/dx2));
        Yita_ref_cell{p,1} = [phi_ref; Y_ref];
    end
    Yita_ref=cell2mat(Yita_ref_cell);
% end % End of func















