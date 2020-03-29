function [sys,x0,str,ts] =Main_ACC_HostVehicleCtrl1(t,x,u,flag)
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

%==============================================================
% Initialization, flag = 0��mdlInitializeSizes
% Return the sizes, initial conditions, and sample times for the S-function.
%==============================================================
function [sys,x0,str,ts] = mdlInitializeSizes
sizes = simsizes;%��������ģ������Ľṹ����simsizes������
sizes.NumContStates  = 0;  %ģ������״̬�����ĸ���
sizes.NumDiscStates  = 4;  %ģ����ɢ״̬�����ĸ���,ʵ����û���õ������ֵ,ֻ�����������ʾ��ɢģ��
sizes.NumOutputs     = 9;  %S��������������������������������
sizes.NumInputs      = 10; %S����ģ����������ĸ�������CarSim�������
sizes.DirFeedthrough = 1;  %ģ���Ƿ����ֱ�ӹ�ͨ(direct feedthrough). 1 means there is direct feedthrough.
% ֱ����ͨ��ʾϵͳ�������ɱ����ʱ���Ƿ��ܵ�����Ŀ��ơ�
% a.  ���������mdlOutputs��flag==3��������u�ĺ����������������u��mdlOutputs�б����ʣ������ֱ����ͨ��
% b.  ����һ���䲽��S-Function�ġ���һ������ʱ�䡱������mdlGetTimeOfNextVarHit��flag==4���п��Է�������u��
% ��ȷ����ֱ����ͨ��־��ʮ����Ҫ�ģ���Ϊ��Ӱ��ģ���п��ִ��˳�򣬲����ü���������
sizes.NumSampleTimes = 1;  %ģ��Ĳ���������>=1

sys = simsizes(sizes);    %������󸳸�sys���

x0 = zeros(sizes.NumDiscStates,1);%initial the  state vector�� of no use

str = [];             % ����������Set str to an empty matrix.

ts  = [0.05 0];       % ts=[period, offset].��������sample time=0.05,50ms 

%--Global parameters and initialization
global InitialGapflag; 
    InitialGapflag = 0; % the first few inputs don't count. Gap it.
global E_gradient;
    E_gradient = [0.904837418035960;
        0.818730753077982;
        0.740818220681718;
        0.670320046035639;
        0.606530659712633;
        0.548811636094026;
        0.496585303791409;
        0.449328964117222;
        0.406569659740599;
        0.367879441171442;
        0.332871083698080;
        0.301194211912202;
        0.272531793034013;
        0.246596963941606;
        0.223130160148430;
        0.201896517994655;
        0.182683524052735;
        0.165298888221587;
        0.149568619222635;
        0.135335283236613;
        0.122456428252982;
        0.110803158362334;
        0.100258843722804;
        0.0907179532894125;
        0.0820849986238988;
        0.0742735782143339;
        0.0672055127397498;
        0.0608100626252180;
        0.0550232200564072;
        0.0497870683678639];

global MPCParameters; 
    MPCParameters.Np      = 30;% predictive horizon
    MPCParameters.Nc      = 30;% control horizon
    MPCParameters.Nx      = 4; %number of state variables
    MPCParameters.Nu      = 1; %number of control inputs
    MPCParameters.Ny      = 1; %number of output variables  
    MPCParameters.Ts      = 0.05; %Set the sample time
    MPCParameters.Q       = 100; % cost weight factor 
    MPCParameters.R       = 0.1; % cost weight factor 
    MPCParameters.S       = 0.5; % cost weight factor 
    MPCParameters.qp_solver = 0; %0: default, quadprog; 1:qpOASES; 2:CVXGEN
    MPCParameters.umin      = -5.0;  % the min of deceleration
    MPCParameters.umax      = 3.5;  % the max of acceleration
    MPCParameters.dumin     = -5.0; % minimum limits of jerk
    MPCParameters.dumax     = 5.0; % maximum limits of jerk
    MPCParameters.dist_CG   = 1.5; % maximum limits of jerk
global WarmStart;
    WarmStart = zeros(MPCParameters.Np,1);
%  End of mdlInitializeSizes

%==============================================================
% Update the discrete states, flag = 2�� mdlUpdate
% Handle discrete state updates, sample time hits, and major time step
% requirements.
%==============================================================
function sys = mdlUpdates(t,x,u)
%  ����û���õ�������̣��ں��ڵĳ���ģ�黯ʱ���Լ�������������ܡ�
    sys = x;    
% End of mdlUpdate.

%==============================================================
% Calculate outputs, flag = 3�� mdlOutputs
% Return the block outputs. 
%==============================================================
function sys = mdlOutputs(t,x,u)

global InitialGapflag;
global E_gradient;
global MPCParameters;
global WarmStart;

Vlimits     = 30.0; % �趨��·���٣�road speed limits
CTHW        = 3.0;  % �趨Constant Time-Head-Way (CTHW), ������Ϊ3s
Dsafe       = 3.0;    % �趨ǰ���뱾������С��ȫ���룬������Ϊ3m

Vh          = 0;
Ah          = 0;
ah_opt      = 0;
dr_al       = 0;
Vr_al       = 0;
A_al        = 0;

t_Start     = tic; % ��ʼ��ʱ 
if InitialGapflag < 2 %  get rid of the first two inputs
    InitialGapflag = InitialGapflag + 1;%
else
    %***********Step (1). ����ǰ���Լ�������״̬ **********************% 
    Target.Vt    = u(1)/3.6; %ǰ�������ٶȣ���λ��km/h-->m/s
    Target.Xt    = u(2);     %ǰ��X����
    Target.Yt    = u(3);     %ǰ��Y����
    Target.Yawt  = u(4);     %ǰ�������
    Target.acc   = u(5)*9.8; %ǰ��������ٶȣ���λ��g's-->m/s2 
    EgoV.Vh      = u(6)/3.6; %���������ٶȣ���λ��km/h-->m/s
    EgoV.Xh      = u(7);     %����X����
    EgoV.Yh      = u(8);     %����Y����
    EgoV.Yawh    = u(9);     %���������
    EgoV.acc     = u(10)*9.8;%����������ٶȣ���λ��g's-->m/s2 
  
    %********Step(2): ����ǰ���Լ�������״̬�����״�����****************%
    [Detected, dr_al, Dangle] = func_Radar_Sensor_Processing(Target, EgoV);    
    if 0 == Detected %���δ��⵽Ŀ�꣬������ǰ���ĳ�����Ϊ��·���٣�����ٶ�Ϊ0
        Target.Vt   = Vlimits;
        Target.acc  = 0;   
    end

    Vh      = EgoV.Vh;
    Ah      = EgoV.acc;    
    Vr_al   = Target.Vt - EgoV.Vh;
    A_al    = Target.acc;
    aal_P       = cell(MPCParameters.Np,1); 
    for i = 1:1:MPCParameters.Np
        aal_P{i,1} = Target.acc * E_gradient(i); 
    end

    %**Step(3): update longitudinal vehilce model, with inertial delay***%    
    Ts  = MPCParameters.Ts; % 50ms
    tao = 0.1; %inertial delay time
    StateSpaceModel.A =  [1     Ts  0   -Ts*Ts/2;
                          0     1   0   -Ts;
                          0     0   1   Ts;
                          0     0   0   1-Ts/tao ];
    StateSpaceModel.B1 = [0;        0;     0;      Ts/tao]; 
    StateSpaceModel.B2 = [Ts*Ts/2;  Ts;    0;      0]; 
    StateSpaceModel.C  = [1         0      -CTHW   0];
    % Gmin_host <= H*U <= Gmax_host
    H_env =[1 0 0 0;
            0 0 1 0];
    Gmin_host = [Dsafe; 0];     %[��С��Ծ���;������С����]
    Gmax_host = [500;Vlimits;]; %[�����Ծ���(��Ϊ����ֵ);���������(��Ϊ��·����)]
    
    kesi_host = [dr_al;  Vr_al;  EgoV.Vh;  EgoV.acc ];
    
    %****Step(4):  MPC formulation;********************%
    %Update Theta, PHI and GAMMA for future states prediction
    [PHI0, THETA0, GAMMA0, PHI, THETA, GAMMA] = func_Update_PHI_THETA_GAMMA(StateSpaceModel, MPCParameters);

    %Update H and g for cost function J=0.5*U'*H*U + g'*U
    U2 = cell2mat(aal_P);
    [H, g] = func_Update_H_g(kesi_host, U2, PHI, THETA, GAMMA, MPCParameters);
    
    %****Step(5):  Call qp-solver********************%
    switch MPCParameters.qp_solver,
        case 0 % default qp-solver: quadprog
            [A, b, Aeq, beq, lb, ub] = func_Constraints_du_quadprog(MPCParameters, Ah, ...
                         kesi_host, U2, PHI0, THETA0, GAMMA0, H_env, Gmin_host, Gmax_host);
            options = optimset('Display','off', ...
                            'TolFun', 1e-8, ...
                            'MaxIter', 2000, ...
                            'Algorithm', 'active-set', ...
                            'FinDiffType', 'forward', ...
                            'RelLineSrchBnd', [], ...
                            'RelLineSrchBndDuration', 1, ...
                            'TolConSQP', 1e-8); 
            warning off all  % close the warnings during computation     

            U0 = WarmStart;           
            [U, FVAL, EXITFLAG] = quadprog(H, g, A, b, Aeq, beq, lb, ub, U0, options); %
            WarmStart = shiftHorizon(U);     % Prepare restart, nominal close loop 
            if (1 ~= EXITFLAG) %if optimization NOT succeeded.
                U(1) = 0.0;
                fprintf('MPC solver not converged!\n');                  
            end
            ah_opt =  U(1);
 
        case 1 % qpOASES
            [A, lb, ub, lbA, ubA] = func_Constraints_du_qpOASES(MPCParameters, Ah, ...
                      kesi_host, U2, PHI0, THETA0, GAMMA0, H_env, Gmin_host, Gmax_host);
            options = qpOASES_options('default', ...
                                'printLevel', 0); 
            
            [U, FVAL, EXITFLAG, iter, lambda] = qpOASES(H, g, A, lb, ub, lbA, ubA, options); %
            if (0 ~= EXITFLAG) %if optimization NOT succeeded.
                U(1) = 0.0;
                fprintf('MPC solver: qpOASES not converged!\n');                  
            end
            ah_opt =  U(1);

        case 2 % CVXGEN
            %--����License���ƣ����鲻�ṩCVXGEN���solver�����߿���������
            [vars, status] = MPC_HostVehicleController_CVXGEN_CTHW(kesi_host, ...
                                    Ah, aal_P, Gmin_host, Gmax_host, CTHW);
            if (1 == status.converged) %if optimization succeeded.
                ah_opt = vars.u_0; 
            else
                ah_opt = 0;
            fprintf('MPC solver not converged!\n');                  
            end

        otherwise % Unexpected flags %
            error(['unexpected qp-solver, Sol_method=',num2str(flag)]); % Error handling
    end %  end of switch
  
end % end of if Initialflag < 1 % 

[Throttle, Brake] = func_AccelerationTrackingController(ah_opt);

t_Elapsed = toc( t_Start ); %computation time 

sys = [Throttle; Brake; t_Elapsed;  Vh; Ah; ah_opt; dr_al; Vr_al; A_al];
% end  %End of mdlOutputs.

%==============================================================
% sub functions
%==============================================================    

function [Detected, Distance, Dangle] = func_Radar_Sensor_Processing(Target, EgoV)
%***************************************************************% 
% % Input:
%    Target��ǰ����״̬
%    EgoV������״̬
% Output:
%    Detected���״�������1��ʾ��⵽Ŀ�꣬0��ʾδ��⵽Ŀ��
%    Distance: ǰ���뱾������Ծ��룬δ��⵽Ŀ����Ĭ��Ϊ
% str�Ǳ�������,����Ϊ��
% ts��һ��1��2������, ts(1)�ǲ�������, ts(2)��ƫ����
%***************************************************************% 
    L_Radar = 200; % Radar detect length:70 m
    R_Radar = 0.6; % Radar detect range:34.4deg=0.6rad
    DistY = Target.Yt - EgoV.Yh;
    DistX = Target.Xt - EgoV.Xh;

    Distance  = sqrt( DistY*DistY + DistX*DistX );
    Theta     = atan2(DistY, DistX);
    Theta_Deg = Theta*180/pi;
    Dangle    = Theta_Deg - mod(EgoV.Yawh, 360);
    if abs(Dangle) >= 270
        Dangle = 360 - abs(Dangle);
    end
    
    if abs(Dangle) >= R_Radar
        Distance = L_Radar;        
    end
     
    if Distance < L_Radar
        Detected = 1; %��⵽ǰ��
    else
        Detected = 0; %δ��⵽ǰ��        
    end

function [Throttle, Brake] = func_AccelerationTrackingController(ahopt)

K_brake         = 0.3;
K_throttle      = 0.1; %0.05;
Brake_Sat       = 15;
Throttle_Sat    = 1;

if ahopt < 0 % Brake control
    Brake = K_brake * ahopt;
    if Brake > Brake_Sat
        Brake = Brake_Sat;
    end
    Throttle = 0;
else % throttle control 
    Brake       = 0;
    Throttle    = K_throttle  *ahopt;
    if Throttle > Throttle_Sat
        Throttle = Throttle_Sat;
    end
    if Throttle < 0
        Throttle = 0;
    end
    
end

function u0 = shiftHorizon(u) %shift control horizon
    u0 = [u(:,2:size(u,2)), u(:,size(u,2))];  %  size(u,2))

function [PHI0, THETA0, GAMMA0, PHI, THETA, GAMMA] = func_Update_PHI_THETA_GAMMA(StateSpaceModel, MPCParameters)
%***************************************************************%
% Ԥ��������ʽ Y(t)=PHI*kesi(t)+THETA*DU(t) + GAMMA*U2(t) 
% Y(t) = [Eta(t+1|t) Eta(t+2|t) Eta(t+3|t) ... Eta(t+Np|t)]'
%***************************************************************%
    Np = MPCParameters.Np;
    Nc = MPCParameters.Nc;
    Nx = MPCParameters.Nx;
    Ny = MPCParameters.Ny;
    Nu = MPCParameters.Nu;
    A  = StateSpaceModel.A;
    B1 = StateSpaceModel.B1;
    B2 = StateSpaceModel.B2;
    C  = StateSpaceModel.C;

    PHI0_cell=cell(Np,1);                            %PHI=[CA CA^2  CA^3 ... CA^Np]' 
    THETA0_cell=cell(Np,Nc);                         %THETA
    GAMMA0_cell=cell(Np,Nc);                         %GAMMA
    PHI_cell=cell(Np,1);                            %PHI=[CA CA^2  CA^3 ... CA^Np]' 
    THETA_cell=cell(Np,Nc);                         %THETA
    GAMMA_cell=cell(Np,Nc);                         %GAMMA
    for j=1:1:Np
        PHI0_cell{j,1}=A^j;  
        PHI_cell{j,1}=C*PHI0_cell{j,1};             %  demision:Ny* Nx
        for k=1:1:Nc
            if k<=j
                A_j_k = A^(j-k);
                THETA0_cell{j,k}=A_j_k*B1;        
                GAMMA0_cell{j,k}=A_j_k*B2;        
                
                THETA_cell{j,k}=C*A_j_k*B1;        %  demision:Ny*Nu
                GAMMA_cell{j,k}=C*A_j_k*B2;        %  demision:Ny*Nu
            else 
                THETA0_cell{j,k}=zeros(Nx,Nu);
                GAMMA0_cell{j,k}=zeros(Nx,Nu);
                
                THETA_cell{j,k}=zeros(Ny,Nu);
                GAMMA_cell{j,k}=zeros(Ny,Nu);
            end
        end
    end
    PHI0=cell2mat(PHI0_cell);    % size(PHI)=[(Ny*Np) * Nx]
    THETA0=cell2mat(THETA0_cell);% size(THETA)=[Ny*Np Nu*Nc]
    GAMMA0=cell2mat(GAMMA0_cell);% size(THETA)=[Ny*Np Nu*Nc]
   
    PHI=cell2mat(PHI_cell);    % size(PHI)=[(Ny*Np) * Nx]
    THETA=cell2mat(THETA_cell);% size(THETA)=[Ny*Np Nu*Nc]
    GAMMA=cell2mat(GAMMA_cell);% size(THETA)=[Ny*Np Nu*Nc]
% end %EoF

function [H, g] = func_Update_H_g(kesi, U2, PHI, THETA, GAMMA, MPCParameters)
%***************************************************************%
% trajectory planning
%***************************************************************%
    Np = MPCParameters.Np;
    Nc = MPCParameters.Nc;   
    Q  = MPCParameters.Q;
    R  = MPCParameters.R;
    S  = MPCParameters.S;
        
    Qq = kron(eye(Np), Q);  % Q = [Np*Nx] *  [Np*Nx] 
    Rr = kron(eye(Nc), R);  % R = [Nc*Nu] *  [Nc*Nu]
    Ss = kron(eye(Nc), S);

    A_t=zeros(Nc,Nc);
    for p=1:1:Nc
        for q=1:1:Nc
            if p >= q 
                A_t(p,q)=1;
            else 
                A_t(p,q)=0;
            end
        end 
    end 

    PHI_kesi = PHI * kesi;
    GAMMA_U2 = GAMMA * U2;
    Yr = MPCParameters.dist_CG * ones(Nc, 1);
    H = THETA'*Qq*THETA + Rr + A_t'*Ss*A_t;  
    f = (PHI_kesi' + GAMMA_U2' - Yr')*Qq*THETA;
    g = f';
% end %EoF

function  [A, b, Aeq, beq, lb, ub] = func_Constraints_du_quadprog(MPCParameters, um, ...
                           kesi, U2, PHI0, THETA0, GAMMA0, H, Gmin_host, Gmax_host)
%************************************************************************%
% generate the constraints of the vehicle
%  
%************************************************************************%
    Np   = MPCParameters.Np;
    Nc   = Np;    
    dumin = MPCParameters.dumin;
    dumax = MPCParameters.dumax;
    umin = MPCParameters.umin;  
    umax = MPCParameters.umax;  
    Umin = kron(ones(Nc,1),umin);
    Umax = kron(ones(Nc,1),umax);
    Ut   = kron(ones(Nc,1),um);
%----(1) A*x<=b----------%
    A_t=zeros(Nc,Nc);
    for p=1:1:Nc
        for q=1:1:Nc
            if p >= q 
                A_t(p,q)=1;
            else 
                A_t(p,q)=0;
            end
        end 
    end 
    A_H = kron(eye(Nc,Nc),  H);
    G_MAX = kron(ones(Nc,1), Gmax_host);
    G_MIN = kron(ones(Nc,1), Gmin_host);
    A_cell=cell(4,1);
    A_cell{1,1} = A_t; %
    A_cell{2,1} = -A_t;
    A_cell{3,1} = A_H*THETA0;
    A_cell{4,1} = -A_H*THETA0;
    A=cell2mat(A_cell);  %
    
    b_cell=cell(4, 1);
    b_cell{1,1} = Umax - Ut; %
    b_cell{2,1} = -Umin + Ut;
    b_cell{3,1} =  G_MAX - A_H*PHI0*kesi - A_H*GAMMA0*U2;
    b_cell{4,1} = -G_MIN + A_H*PHI0*kesi + A_H*GAMMA0*U2;
    b=cell2mat(b_cell);  % 

%----(2) Aeq*x=beq----------%
    Aeq = [];
    beq = [];

%----(3) lb=<x<=ub----------%
    lb=kron(ones(Nc,1), dumin);
    ub=kron(ones(Nc,1), dumax);
% end %EoF

function [A, lb, ub, lbA, ubA] = func_Constraints_du_qpOASES(MPCParameters, um, ...
                         kesi, U2, PHI0, THETA0, GAMMA0, H, Gmin_host, Gmax_host)
    Np   = MPCParameters.Np;
    Nc   = Np;
    dumin = MPCParameters.dumin;
    dumax = MPCParameters.dumax;
    umin = MPCParameters.umin;
    umax = MPCParameters.umax;  
    Umin = kron(ones(Nc,1), umin);
    Umax = kron(ones(Nc,1), umax);
    Ut   = kron(ones(Nc,1),um);
%----(1) lbA <= A_t*x<=ubA----------%
    A_t=zeros(Nc,Nc);
    for p=1:1:Nc
        for q=1:1:Nc
            if p >= q 
                A_t(p,q)=1;
            else 
                A_t(p,q)=0;
            end
        end 
    end
    A_H = kron(eye(Nc,Nc),  H);
    G_MAX = kron(ones(Nc,1), Gmax_host);
    G_MIN = kron(ones(Nc,1), Gmin_host);
  
    A_cell=cell(2,1);
    A_cell{1,1} = A_t; %
    A_cell{2,1} = A_H*THETA0;
    A=cell2mat(A_cell);  %

    ubA_cell=cell(2, 1);
    lbA_cell=cell(2, 1);
    ubA_cell{1,1} = Umax - Ut;
    lbA_cell{1,1} = Umin - Ut;
    ubA_cell{2,1} = G_MAX - A_H*PHI0*kesi - A_H*GAMMA0*U2;
    lbA_cell{2,1} = G_MIN - A_H*PHI0*kesi - A_H*GAMMA0*U2;
    ubA=cell2mat(ubA_cell);
    lbA=cell2mat(lbA_cell);

%---- lb=<x<=ub----------%
    lb=kron(ones(Nc,1), dumin);
    ub=kron(ones(Nc,1), dumax);
% end %EoF
