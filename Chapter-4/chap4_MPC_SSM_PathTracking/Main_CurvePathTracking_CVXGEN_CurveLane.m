function [sys,x0,str,ts] =Main_CurvePathTracking_CVXGEN_CurveLane(t,x,u,flag)
%***************************************************************%
% This is a Simulink/Carsim joint simulation solution for safe driving
% envelope control of high speed autonomous vehicle
% Linearized spatial bicycle vehicle dynamic model is applied.
% No successive linearizarion. No two time scale of prediction horizon
% Constant high speed, curve path tracking 
% state vector =[beta,yawrate,e_phi,s,e_y]
% control input = [steer_SW]
% many other parameters are also outputed for comparision.

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
sizes.NumDiscStates  = 3;  %ģ����ɢ״̬�����ĸ���,ʵ����û���õ������ֵ��ֻ�����������ʾ��ɢģ��
sizes.NumOutputs     = 8;  %S��������������������������������
sizes.NumInputs      = 7; %S����ģ����������ĸ�������CarSim�������
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
    
    global VehiclePara; 
    VehiclePara.m  = 1540;   %mΪ��������,Kg; Sprung mass = 1370
    VehiclePara.g  = 9.8;
    VehiclePara.Lf = 1.11;  %a
    VehiclePara.Lr = 1.67;  %b��ǰ���־��복�����ĵľ��룬�������в���
    VehiclePara.L  = 2.78;  %VehiclePara.Lf + VehiclePara.Lr;
    VehiclePara.Lc = 1.59;  %c,or 1.57. ע����᳤��lc��δȷ��
    VehiclePara.I  = 2315.3;   %IΪ������Z���ת���������������в���
    VehiclePara.mu = 1.0; % 0.55; %����Ħ��������
    VehiclePara.Radius = 0.261;  % ��̥�����뾶
    
    global MPCParameters; 
    MPCParameters.Np  = 40;% predictive horizon Assume Np=Nc
    MPCParameters.Ts  = 0.05; %Set the sample time of near term 
    MPCParameters.Nx  = 3; %the number of state variables
    MPCParameters.Ny  = 3; %the number of output variables      
    MPCParameters.Nu  = 2; %the number of control inputs
    
    global CostWeights; 
    CostWeights.Q   = [ 10      0       0;
                        0      10       0;
                        0      0       10];  %state vector =[beta,yawrate,e_phi,s,e_y]
 
    CostWeights.R   = 10000; % on Du
    
    global Constraints;  
    Constraints.dumax   = 0.08;      % Units: rad  
    Constraints.umax    = 0.4;      % Units: rad appro.23deg
    
    global WayPoints_IndexPre;
    WayPoints_IndexPre = 1;
    
    global Reftraj;
    Reftraj = load('WayPoints_Alt3fromFHWA_Overall.mat');
%     Local_reftraj = load('WayPoints_Alt3fromFHWA_Portion.mat');    
    
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

Ctrl_SteerSW    = 0;
t_Elapsed       = 0;
PosX            = 0;
PosY            = 0;
PosPsi          = 0;
Vel             = 0;
e_psi           = 0;
e_y             = 0;

if InitialGapflag < 2 %  get rid of the first two inputs,  because no data from CarSim
    InitialGapflag = InitialGapflag + 1;
else % start control
%***********Step (2). State estimation and Location **********************% 
    %-----Update State Estimation of measured Vehicle Configuration--------%
    [VehStateMeasured] = func_StateEstimation(u); %u��S����ģ�������
    Vel     = VehStateMeasured.Vx;     
    PosX    = VehStateMeasured.Xc;
    PosY    = VehStateMeasured.Yc;
    PosPsi  = VehStateMeasured.psi;    
    Ax      = VehStateMeasured.Ax;
    fwa     = VehStateMeasured.fwa;    

    %********Step(3): Given reference trajectory, update vehicle state and bounds *******************% 
    % Local vehicle coordinates, y=K[3]x^3 + K[2]x^2 + K[1]x +K[0].
    [PrjP, RefP, RefU, WPIndex] = func_RefTraj_LocalPlanning( MPCParameters, WayPoints_IndexPre, Reftraj.WayPoints_Collect, VehStateMeasured ); % reference path is a straight line
    if ( WPIndex <= 0)
        %����
    else
        WayPoints_IndexPre = WPIndex;        
    end

    %****Step(4):  MPC formulation;********************%
    %----Update  An, Al, B, dn,dl of the StateSpaceModel
    [StateSpaceModel] = func_StateSpaceModel_StraightLane(VehiclePara, MPCParameters,  PrjP ); 
    Xm = [PosX; PosY; PosPsi];
    
    %================CVXGEN solver==================================%
    settings.verbose    = 0;       % 0-Silence; 1-display
    settings.max_iters  = 25;    %Limits the total iterations
    
    params.xm       = Xm;
    params.um       = fwa; % measured front whee angle
    params.Pxr      = [PrjP.xr; PrjP.yr; PrjP.psir];
    params.Pur      = PrjP.fwar;
    params.An       = StateSpaceModel.An;
    params.Bn       = StateSpaceModel.Bn;
    params.Q        = CostWeights.Q;  
    params.R	    = CostWeights.R;
    params.umax     = Constraints.umax;
    params.dumax    = Constraints.dumax; 
    params.RefP     = RefP; 
    params.RefU     = RefU;  
   
    t_Start = tic; % ��ʼ��ʱ  
    [vars, status] = csolve_StraightLane(params, settings);
    if (1 == status.converged) %if optimization succeeded.
        fwa_opt = vars.u_0;          
%         ah_des  = vars.u_0(2); 
    else
        fwa_opt =  0;
        fprintf('CVXGEN converged = 0 \n');                  
    end
    
    %====================================================================%
    Ctrl_SteerSW0 = 19 * fwa_opt*180/pi; % in deg.    
%     [Throttle, Brake] = func_AccelerationTrackingController(ah_opt);
      
    t_Elapsed = toc( t_Start ); %computation time
    
     %---4.Publish command********************%
    Ctrl_SteerSW = round(10*Ctrl_SteerSW0)/10;
    e_y            = PrjP.ey;
    e_psi          = PrjP.epsi;   
end % end of if Initialflag < 2 % 

   
sys = [Ctrl_SteerSW; t_Elapsed; PosX; PosY; PosPsi; Vel; e_psi; e_y];     
% end  %End of mdlOutputs.

%==============================================================
% sub functions
%==============================================================    

%***************************************************************%
% **** State estimation
%***************************************************************%
function [VehStatemeasured] = func_StateEstimation(ModelInput)
%***************************************************************%
% we should do state estimation, but for simplicity we deem that the
% measurements are accurate
% Update the state vector according to the input of the S function,
%           usually do State Estimation from measured Vehicle Configuration
%***************************************************************%  
    %******����ӿ�ת��***%        
    VehStatemeasured.Vx      = ModelInput(1)/3.6; %Unit:km/h-->m/s������1λС��  
    VehStatemeasured.Xc      = round(100*ModelInput(2))/100;%��λΪm, ����2λС��
    VehStatemeasured.Yc      = round(100*ModelInput(3))/100;%��λΪm, ����2λС��    
    VehStatemeasured.psi     = (round(100*ModelInput(4))/100)*pi/180; %����ǣ�Unit��deg-->rad������2λС��    
    VehStatemeasured.Ax      = 9.8*ModelInput(5);%��λΪm/s^2, ����2λС��
    VehStatemeasured.fwa     = (round(10*0.5*(ModelInput(6)+ ModelInput(7)))/10)*pi/180; % deg-->rad   
    
% end % end of func_StateEstimation

%***************************************************************%
% Augmented vehicle state space model
%***************************************************************%
function [StateSpaceModel] = func_StateSpaceModel_StraightLane(VehiclePara, MPCParameters, PrjP)
    % generate State-space model
    L       = VehiclePara.L;  %a = 1.11;  
    Ts      = MPCParameters.Ts;
    Nx      = MPCParameters.Nx;
    Velr    = PrjP.Velr;    
    xr      = PrjP.xr;
    yr      = PrjP.yr;
    psir    = PrjP.psir;  
    fwar    = PrjP.fwar; 
   
    
    Acn = [0,        0,        -Velr*sin(psir);
           0,        0,        Velr*cos(psir);
           0,        0,        0];
      
    Bcn = [0,       0,     Velr/(L*cos(fwar)*cos(fwar))]';%
   
    % SSM discretization for the near term
    Adn = eye(Nx) + Ts*Acn;
    Bdn = Ts*Bcn;
 
    StateSpaceModel.An = Adn;
    StateSpaceModel.Bn = Bdn; 
                        
% end % end of func_SpatialDynamicalModel


