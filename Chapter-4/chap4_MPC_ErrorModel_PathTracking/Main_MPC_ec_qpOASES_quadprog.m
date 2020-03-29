function [sys,x0,str,ts] =Main_MPC_ec_qpOASES_quadprog(t,x,u,flag)
%***************************************************************%
% This is a Simulink/Carsim joint simulation solution for path tracking use
% MPC with tracking error model.
% Use constant high speed, curve path tracking 
% state vector =[epsi,ed,measured_delta_f]
% control input = [steer_SW]
%
% Input:
% t�ǲ���ʱ��, x��״̬����, u������(������simulinkģ�������,��CarSim�����),
% flag�Ƿ�������е�״̬��־(�������жϵ�ǰ�ǳ�ʼ���������е�)
%
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
sizes.NumDiscStates  = 3;  %ģ����ɢ״̬�����ĸ���,ʵ����û���õ������ֵ��ֻ�����������ʾ��ɢģ��
sizes.NumOutputs     = 11;  %S��������������������������������
sizes.NumInputs      = 38; %S����ģ����������ĸ�������CarSim�������
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

%-----------------------------------------------------------------------%
    global InitialGapflag; 
    InitialGapflag = 0; % the first few inputs don't count. Gap it.
    
    global VehiclePara; % for SUV
    VehiclePara.Lf  = 1.05;
    VehiclePara.Lr  = 1.55;
    VehiclePara.L   = 2.6;  %VehiclePara.Lf + VehiclePara.Lr;
%     VehiclePara.Tr  = 1.565;  %c,or 1.57. ע����᳤��lc��δȷ��
%     VehiclePara.mu  = 0.85; % 0.55; %����Ħ������
%     VehiclePara.Iz  = 2059.2;   %IΪ������Z���ת���������������в���  
%     VehiclePara.Ix  = 700.7;   %IΪ������Z���ת���������������в���  
%     VehiclePara.Radius = 0.379;  % ��̥�����뾶   
    
    global MPCParameters; 
    MPCParameters.Np  = 70;% predictive horizon Assume Np=Nc
    MPCParameters.Ts  = 0.05; % 0.1;  
    MPCParameters.Nx  = 2; %the number of state variables
    MPCParameters.Ny  = 2; %the number of output variables      
    MPCParameters.Nu  = 1; %the number of control inputs
    
    global CostWeights; 
    CostWeights.Wephi   = 5; %state vector =[beta,yawrate,e_phi,s,e_y]
    CostWeights.Wey     = 100;
    CostWeights.deltaf  = 1000;% on Du
    
    global Constraints;  
    Constraints.dumax   = 0.08; %*MPCParameters.Ts; % Units: rad,0.174rad/s = 10deg/s, 0.08rad/s=4.6deg/s  
    Constraints.umax    = 0.471; % Units: rad.  0.4rad=23deg, 0.471rad=27deg
    
    Constraints.DPhimax = pi/3;  %  ������ƫ��60deg
    Constraints.Dymax   = 1.7; % unit:m. cross-track-error max 2m

    global WayPoints_IndexPre;
    WayPoints_IndexPre = 1;

    global WarmStart;
    WarmStart = zeros(MPCParameters.Np,1);

    global qpOASES_hotstart_flag;
    qpOASES_hotstart_flag = 1;
    
    global qpOASES_QP;
    qpOASES_QP = 0;
    
    global Sol_method;
    Sol_method = 3;% 1- quadprog   
                   % 2- qpOASES  
                   % 3- OPQP                     
                   % 4- gurobi   
    global Reftraj;
     Reftraj = load('WayPoints_Alt3fromFHWA_Samples.mat');    
    
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
global CostWeights;     
global Constraints;
global WayPoints_IndexPre;
global Reftraj;
global Sol_method;
global WarmStart;
global qpOASES_hotstart_flag;
global qpOASES_QP;
    
t_Elapsed       = 0;
Ctrl_SteerSW    = 0;
PosX            = 0;
PosY            = 0;
PosPsi          = 0;
Vel             = 0;
e_psi           = 0;
e_d             = 0;
fwa_opt         = 0;
fwa_measured    = 0;
Station         = 0;
    
if InitialGapflag < 2 %  get rid of the first two inputs,  because no data from CarSim
    InitialGapflag = InitialGapflag + 1;
else % start control
    InitialGapflag = InitialGapflag + 1;
%***********Step (2). State estimation and Location **********************% 
    t_Start = tic; % ��ʼ��ʱ  
    %-----Update State Estimation of measured Vehicle Configuration--------%
    [VehStateMeasured, ParaHAT] = func_StateEstimation(u);   
    PosX        = VehStateMeasured.X;
    PosY        = VehStateMeasured.Y;
    PosPsi      = VehStateMeasured.phi;    
    Vel         = VehStateMeasured.x_dot; 
    fwa_measured  = VehStateMeasured.fwa; % rad
    Station     = VehStateMeasured.Station;
    if(Vel < 1.0)
        Vel = 1.0;
    end
    %********Step(3): Given reference trajectory, update vehicle state and bounds *******************% 
    [WPIndex, RefP, RefK, Uaug, PrjP] = func_RefTraj_LocalPlanning( MPCParameters,... 
                            VehiclePara,... 
                            WayPoints_IndexPre,... 
                            Reftraj.WayPoints_Collect,... 
                            VehStateMeasured ); % 
                            
    if ( WPIndex <= 0)
       fprintf('Error: WPIndex <= 0 \n');% ����
    else
        epsi = PrjP.epsi;  
        if(epsi > pi/2)
           epsi = epsi - pi;
        end
        if(epsi < -pi/2)
           epsi = epsi + pi;
        end
        if(epsi > Constraints.DPhimax)
           epsi = Constraints.DPhimax;
        end
        if(epsi < -Constraints.DPhimax)
           epsi = -Constraints.DPhimax;
        end
        ed   = PrjP.ey;       
        if(ed > Constraints.Dymax)
           ed = Constraints.Dymax;
        end
        if(ed < -Constraints.Dymax)
           ed = -Constraints.Dymax;
        end        
%         Xm = [epsi; ed];  
        Xm = [epsi; ed; fwa_measured];
        WayPoints_IndexPre = WPIndex;        
    end

    %****Step(4):  update MPC_error_model_augmented SSM ******************%
    % x(k+1) = Au*x(k)+Bu1*u1 + Bu2 * u2
    [StateSpaceModel] = func_Update_ecMPC_SSM_Augmented(VehiclePara, MPCParameters, Vel);
    
     %****Step(4):  update Constraints and bounds ********************%
    Np   = MPCParameters.Np;
    Nx   = MPCParameters.Nx;
    Nu   = MPCParameters.Nu;
    Naug = Nx + Nu;
    
%     Eymax       = zeros(Np,1);
%     Eymin       = zeros(Np,1);     
%     LM_right    = -5;
%     LM_middle   = 0;
%     Yroad_L     = -2.5;
%     for i =1:1:Np  % ע��ey�Ǵ����ŵ�, Np = 25
%         Eymax(i,1) = (LM_middle - Yroad_L);
%         Eymin(i,1) = (LM_right - Yroad_L);             
%     end
%     [Envelope] = func_ConstraintsBounds(VehiclePara, MPCParameters, Constraints, StateSpaceModel, Vel, CarHat,  Eymax, Eymin); 
    
    %**** Update Cost Weighting Regulation functions ********************%
%     Q = diag([CostWeights.Wephi, CostWeights.Wey]);
%     R = CostWeights.deltaf;
    
    [Q, R] = func_CostWeightingRegulation(CostWeights, Constraints);

    %================MPC problem formulation==================================%
    % Update Theta and PHI, then H and f
    [PHI, THETA, GAMMA] = func_PHI_THETA_Cal(StateSpaceModel, MPCParameters);

    [H, f, g] = func_H_f_Cal(Xm, Uaug, PHI, THETA, GAMMA, Q, R, MPCParameters); 
    
    %=========Call qp-solver==========================%
    switch Sol_method
    case 1 % quadprog
        [A, b, Aeq, beq, lb, ub] = func_Bounds_Constraints_quadprog(MPCParameters, Constraints, fwa_measured);
        options = optimset('Display','off', ...
                            'TolFun', 1e-8, ...
                            'MaxIter', 2000, ...
                            'Algorithm', 'active-set', ...
                            'FinDiffType', 'forward', ...
                            'RelLineSrchBnd', [], ...
                            'RelLineSrchBndDuration', 1, ...
                            'TolConSQP', 1e-8); 
        warning off all  % close the warnings during computation     

        u0 = WarmStart;           
        [U, FVAL, EXITFLAG] = quadprog(H, f, A, b, Aeq, beq, lb, ub, u0, options); %
        WarmStart = shiftHorizon(U);     % Prepare restart, nominal close loop 
        fwa_opt = U(1) + fwa_measured;
        
    case 2 % qpOASES
        [A, lb, ub, lbA, ubA] = func_Bounds_Constraints_qpOASES(MPCParameters, Constraints, fwa_measured);
        options = qpOASES_options('default', ...
                            'printLevel', 0); 

        %=======================USE QP==================%
        [U, FVAL, EXITFLAG, iter, lambda] = qpOASES(H, g, A, lb, ub, lbA, ubA, options); %
        
        %=======================USE SQP==================%
%         try
%             H=sparse(H);
%             A=sparse(A);
%         catch
%             fprintf('qpOASES Error reported\n'); 
%         end
%         if (qpOASES_hotstart_flag)
%             [qpOASES_QP, U, FVAL, EXITFLAG, iter, lambda] = qpOASES_sequence('i', H, g, A, lb, ub, lbA, ubA, options);
%             qpOASES_hotstart_flag = 1;
%         else    
%             [U, FVAL, EXITFLAG, iter, lambda] = qpOASES_sequence('m', qpOASES_QP, H, g, A, lb, ub, lbA, ubA, options); %
%         end
        
        fwa_opt = U(1) + fwa_measured;
        
    case 3 %OSQP
        [A, l_constr, u_constr] = func_Bounds_Constraints_OSQP(MPCParameters, Constraints, fwa_measured);
        % define problem
        problem.P = sparse(H);
        problem.q = f;
        problem.A = sparse(A);
        problem.l = [l_constr];
        problem.u = [u_constr];

        % Setup settings
%         settings.alpha = 1.6;
%         settings.rho = 0.1;
%         settings.sigma = 0.1;
%         settings.eps_prim_inf = 1e-5;
%         settings.eps_dual_inf = 1e-5;
%         settings.eps_rel = 1e-5;
%         settings.eps_abs = 1e-5;
%         settings.max_iter = 2500;
        settings.verbose = 0;
        settings.warm_start = 1;
        settings.scaling = 0; % Disable scaling. Pure Matlab implementation does not support it yet      
        
        % Setup and solve the problem with osqp       
        solver = osqp;
        solver.setup(problem.P, problem.q, problem.A, problem.l, problem.u, settings);
        resOSQP = solver.solve();
        %resOSQP.x: primal variables
        %resOSQP.y: dual variables
        %resOSQP.info.status
        %resOSQP.info.status_val
        %resOSQP.info.polish
        
        if (1 == resOSQP.info.status_val)
            U_opt =  resOSQP.x(1);
        else
            U_opt = 0;
            fprintf('OSQP failed, OSQP_status= %d\n', resOSQP.info.status_val);     
        end
        fwa_opt =  U_opt + fwa_measured;
        
    case 4 %gurobi
        try
            clear model;
            model.Q = sparse(H);
            model.obj = f';       
            model.A = sparse(A);
            model.rhs = b;
            model.sense = '<';
            model.lb = lb; %(optional)
            model.ub = ub; 
            result = gurobi(model);
            U = result.x;
        catch gurobiError
            fprintf('gurobi Error reported\n');          
        end
        fwa_opt = U(1) + fwa_measured;
        
    otherwise % default
        fprintf('Unknown qp-solver, Sol_method= %d\n', Sol_method);     
    end % end of switch
    
    %====================================================================%
    Ctrl_SteerSW = 19 * fwa_opt*180/pi; % in deg.    
      
    t_Elapsed = toc( t_Start ); %computation time
    
    e_psi           = PrjP.epsi;
    e_d             = PrjP.ey;     

end % end of if Initialflag < 2 % 


sys = [Ctrl_SteerSW; t_Elapsed; PosX; PosY; PosPsi; Station; Vel; e_psi; e_d; fwa_opt; fwa_measured]; %

% end  %End of mdlOutputs.

%==============================================================
% sub functions
%==============================================================    

%***************************************************************%
% **** State estimation
%***************************************************************%
function [VehStatemeasured, HATParameter] = func_StateEstimation(ModelInput)
%***************************************************************%
% we should do state estimation, but for simplicity we deem that the
% measurements are accurate
% Update the state vector according to the input of the S function,
%           usually do State Estimation from measured Vehicle Configuration
%***************************************************************%  
    %******����ӿ�ת��***%        
    g = 9.81;
    VehStatemeasured.X       = round(100*ModelInput(1))/100;%��λΪm, ����2λС��
    VehStatemeasured.Y       = round(100*ModelInput(2))/100;%��λΪm, ����2λС��    
    VehStatemeasured.phi     = (round(10*ModelInput(3))/10)*pi/180; %����ǣ�Unit��deg-->rad������1λС��    
    VehStatemeasured.x_dot   = ModelInput(4)/3.6; %Unit:km/h-->m/s������1λС��  
    VehStatemeasured.y_dot   = ModelInput(5)/3.6; %Unit:km/h-->m/s������1λС��   
    VehStatemeasured.phi_dot = (round(10*ModelInput(6))/10)*pi/180; %Unit��deg/s-->rad/s������1λС��      
    VehStatemeasured.beta    = (round(10*ModelInput(7))/10)*pi/180;% side slip, Unit:deg-->rad������1λС��    
    VehStatemeasured.delta_f = (round(10*0.5*(ModelInput(8)+ ModelInput(9)))/10); % deg
    VehStatemeasured.fwa     = VehStatemeasured.delta_f * pi/180;  % deg-->rad
    VehStatemeasured.Steer_SW= ModelInput(10); %deg
    VehStatemeasured.Ax      = g*ModelInput(11);%��λΪm/s^2, ����2λС��
    VehStatemeasured.Ay      = g*ModelInput(12);%��λΪm/s^2, ����2λС��
    VehStatemeasured.yawrate_dot = ModelInput(13); %rad/s^2
    % Here I don't explore the state estimation process, and deem the
    % measured values are accurate!!! 
    HATParameter.alpha_l1   = (round(10*ModelInput(14))/10)*pi/180; % deg-->rad������1λС��   
    HATParameter.alpha_l2   = (round(10*ModelInput(15))/10)*pi/180; % deg-->rad������1λС��   
    HATParameter.alpha_r1   = (round(10*ModelInput(16))/10)*pi/180; % deg-->rad������1λС��   
    HATParameter.alpha_r2   = (round(10*ModelInput(17))/10)*pi/180; % deg-->rad������1λС��     
    HATParameter.alphaf     = (round(10*0.5 * (ModelInput(14)+ ModelInput(16)))/10)*pi/180; % deg-->rad������1λС��   
    HATParameter.alphar     = (round(10*0.5 * (ModelInput(15)+ ModelInput(17)))/10)*pi/180; % deg-->rad������1λС��  
    
    HATParameter.Fz_l1      = round(10*ModelInput(18))/10; % N 
    HATParameter.Fz_l2      = round(10*ModelInput(19))/10; % N 
    HATParameter.Fz_r1      = round(10*ModelInput(20))/10; % N 
    HATParameter.Fz_r2      = round(10*ModelInput(21))/10; % N 
    
    HATParameter.Fy_l1      = round(10*ModelInput(22))/10; % N 
    HATParameter.Fy_l2      = round(10*ModelInput(23))/10; % N 
    HATParameter.Fy_r1      = round(10*ModelInput(24))/10; % N 
    HATParameter.Fy_r2      = round(10*ModelInput(25))/10; % N 
    HATParameter.Fyf        = HATParameter.Fy_l1 + HATParameter.Fy_r1;
    HATParameter.Fyr        = HATParameter.Fy_l2 + HATParameter.Fy_r2;
    
    HATParameter.Fx_L1      = ModelInput(26);
    HATParameter.Fx_L2      = ModelInput(27);
    HATParameter.Fx_R1      = ModelInput(28);
    HATParameter.Fx_R2      = ModelInput(29);
    
%     HATParameter.GearStat    = ModelInput(30);
    VehStatemeasured.Roll_Shad   = ModelInput(30)*pi/180;% deg-->rad 
    HATParameter.Roll        = ModelInput(31)*pi/180;% deg-->rad 
    HATParameter.Rollrate    = ModelInput(32)*pi/180;% deg/s-->rad/s
    HATParameter.Roll_accel  = ModelInput(33); % rad/s^2
    HATParameter.Z0          = ModelInput(34); %m
    VehStatemeasured.Station     = ModelInput(35); %m
    HATParameter.Zcg_TM      = ModelInput(35); %m
    HATParameter.Zcg_SM      = ModelInput(36); %m
    HATParameter.Ay_CG       = ModelInput(37)*g; %m/s^2
    HATParameter.Ay_Bf_SM    = ModelInput(38)*g; %m/s^2
    
% end % end of func_StateEstimation

function u0 = shiftHorizon(u) %shift control horizon
    u0 = [u(:,2:size(u,2)), u(:,size(u,2))];  %  size(u,2))

function  [PHI, THETA,GAMMA] = func_PHI_THETA_Cal(StateSpaceModel, MPCParameters)
%***************************************************************%
% Ԥ��������ʽ Y(t)=PHI*kesi(t)+THETA*DU(t) 
% Y(t) = [Eta(t+1|t) Eta(t+2|t) Eta(t+3|t) ... Eta(t+Np|t)]'
%***************************************************************%
    Np = MPCParameters.Np;
    Nx = MPCParameters.Nx;
    Ny = MPCParameters.Ny;
    Nu = MPCParameters.Nu;
    Naug = Nx+Nu;
    Au  = StateSpaceModel.Au;% demision:Naug * Naug
    Bu1 = StateSpaceModel.Bu1;% demision:Naug * Nu
    Bu2 = StateSpaceModel.Bu2;% demision:Naug * Nu    
    C  = StateSpaceModel.C;% demision:Ny * Naug   

    PHI_cell=cell(Np,1);                            % PHI=[CA CA^2  CA^3 ... CA^Np]' 
    THETA_cell=cell(Np,Np);                         % theta
    GAMMA_cell=cell(Np,Np);                         % gamma
    
    PHI_cell{1,1}=C*Au;
    for i=2:1:Np
        PHI_cell{i,1}=PHI_cell{i-1,1}*Au;            % demision:Ny* Naug
    end
    for i=1:1:Np
        for j=1:1:Np
            if i >= j
                CAu = C*Au^(i-j);% demision:Ny * Naug   
                THETA_cell{i,j}=CAu * Bu1;        % demision:Ny*Nu
                GAMMA_cell{i,j}=CAu * Bu2;        % demision:Ny*Nu
            else 
                THETA_cell{i,j}=zeros(Ny,Nu);
                GAMMA_cell{i,j}=zeros(Ny,Nu);
            end
        end
    end
    PHI   = cell2mat(PHI_cell);%size(PHI)=[(Ny*Np) * Naug]
    THETA = cell2mat(THETA_cell);%size(THETA)=[Ny*Np Nu*Np]
    GAMMA = cell2mat(GAMMA_cell);%size(THETA)=[Ny*Np Nu*Np]
    
function  [H, f, g] = func_H_f_Cal(kesi, U_ref, PHI, THETA, GAMMA, YQ, UR, MPCParameters)
%***************************************************************%
% trajectory planning
%***************************************************************%
    Np = MPCParameters.Np;
    Nc = Np;     
    QQ = kron(speye(Np),YQ);  %            Q = [Np*Ny] *  [Np*Ny] 
    RR = kron(speye(Nc),UR);  %            R = [Nc*Nu] *  [Nc*Nu]

    error = PHI * kesi + GAMMA * cell2mat(U_ref); %[(Nx*Np) * 1]

    H = THETA'*QQ*THETA + RR;  
    f = error'*QQ*THETA;
    g = f';
    
function  [A, b, Aeq, beq, lb, ub] = func_Bounds_Constraints_quadprog(MPCParameters, Constraints, um)
%************************************************************************%
% generate the constraints of the vehicle
%  
%************************************************************************%
    Np   = MPCParameters.Np;
    Nc   = Np;    
    dumax = Constraints.dumax;
    umax = Constraints.umax;  
    Umin = kron(ones(Nc,1),-umax);
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
    A_cell=cell(2,1);
    A_cell{1,1} = A_t; %
    A_cell{2,1} = -A_t;
    A=cell2mat(A_cell);  %
    
    
    b_cell=cell(2, 1);
    b_cell{1,1} = Umax - Ut; %
    b_cell{2,1} = -Umin + Ut;
    b=cell2mat(b_cell);  % 

%----(2) Aeq*x=beq----------%
    Aeq = [];
    beq = [];

%----(3) lb=<x<=ub----------%
    lb=kron(ones(Nc,1),-dumax);
    ub=kron(ones(Nc,1),dumax);

function [A_t, lb, ub, lbA, ubA] = func_Bounds_Constraints_qpOASES(MPCParameters, Constraints, um)
    Np   = MPCParameters.Np;
    Nc   = Np;    
    dumax = Constraints.dumax;
    umax = Constraints.umax;  
    Umin = kron(ones(Nc,1),-umax);
    Umax = kron(ones(Nc,1),umax);
    Ut   = kron(ones(Nc,1),um);
%----(1) lbA <= A*x<=ubA----------%
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

    ubA = Umax - Ut; %
    lbA = Umin - Ut;
%---- lb=<x<=ub----------%
    lb=kron(ones(Nc,1),-dumax);
    ub=kron(ones(Nc,1),dumax);


function [A, l_constr, u_constr] = func_Bounds_Constraints_OSQP(MPCParameters, Constraints, um)
    Np   = MPCParameters.Np;
    Nc   = Np;    
    dumax = Constraints.dumax;
    umax = Constraints.umax;  
    Umin = kron(ones(Nc,1),-umax);
    Umax = kron(ones(Nc,1),umax);
    Ut   = kron(ones(Nc,1),um);
%----(1) lbA <= A*x<=ubA----------%
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

    A_cell=cell(2,1);
    A_cell{1,1} = A_t; %
    A_cell{2,1} = eye(Np);
    A=cell2mat(A_cell);  %
    
    
    l_constr=cell(2, 1);
    u_constr=cell(2, 1);
    l_constr{1,1} = Umin - Ut;    
    u_constr{1,1} = Umax - Ut; %
    l_constr{2,1} = kron(ones(Nc,1),-dumax);    
    u_constr{2,1} = kron(ones(Nc,1),dumax); %
    l_constr=cell2mat(l_constr);  % 
    u_constr=cell2mat(u_constr);  % 





