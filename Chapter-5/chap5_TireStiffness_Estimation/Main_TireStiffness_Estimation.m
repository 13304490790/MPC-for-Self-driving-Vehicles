function [sys,x0,str,ts] =Main_TireStiffness_Estimation(t,x,u,flag)
%***************************************************************%
% Simulation for estimation of cornering stiffness using RLS method
% Assume: lf, lr are known; 
% Assume: Vy, Vel, steering_angle and side-slip angle are measurable
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
% Return the sizes, initial conditions, and sample times for the S-function
%==============================================================
sizes = simsizes;%��������ģ������Ľṹ����simsizes������
sizes.NumContStates  = 0;  %ģ������״̬�����ĸ���
sizes.NumDiscStates  = 6;  %ģ����ɢ״̬�����ĸ���,ʵ����û���õ������ֵ
sizes.NumOutputs     = 12; %S������������еĸ���
sizes.NumInputs      = 21; %S����ģ����������ĸ�������CarSim�������
sizes.DirFeedthrough = 1;  %ģ���Ƿ����ֱ�ӹ�ͨ(direct feedthrough). 
sizes.NumSampleTimes = 1;  %ģ��Ĳ���������>=1
sys = simsizes(sizes);    %������󸳸�sys���

x0 = zeros(sizes.NumDiscStates,1);%initial the  state vector
str = [];             % ����������Set str to an empty matrix.
ts  = [0.05 0];       % ts=[period, offset].��������sample time=0.05s 

%------------Global parameters and initialization--------------------%
    global InitialGapflag; 
    InitialGapflag = 0; % Ignore the first few inputs from CarSim
    % vehicle parameters initialization
    global VehicleParams; % for SUV
    VehicleParams.Lf  = 1.12;  % 1.05
    VehicleParams.Lr  = 1.48;  % 1.55

    
    % RLS for longitudinal stiffness initialization
    [y, Ccf] = func_RLSEstimation_Clf('initial', 0.95, 1, 10);
    [y, Ccr] = func_RLSEstimation_Clr('initial', 0.95, 1, 10);

    % RLS for cornering stiffness initialization
    [y, Clf] = func_RLSEstimation_Ccf('initial', 0.95, 1, 10);
    [y, Clr] = func_RLSEstimation_Ccr('initial', 0.95, 1, 10);
    
%     global RLS_params; 
%     RLS_params.nDataTuple    = 10;
%     RLS_params.nCoefficients = 1;
%     RLS_params.initialCoefficients = -90000* ones(RLS_params.nCoefficients,1);    
%     RLS_params.delta         = 10;
%     RLS_params.lambda = 0.95;
%     [y, e, c] = func_RLS_Alt_New('initial', 0, params);   
% 
%     global pre_regressor;
%     nc = 1;
%     nd = 10;
%     pre_regressor.input = zeros(nc,nd);
%     pre_regressor.d     = zeros(nd,1);
    
%  End of mdlInitializeSizes

function sys = mdlUpdates(t,x,u)
%==============================================================
% Update the discrete states, flag = 2�� mdlUpdate
% Handle discrete state updates, sample time hits, and major time step
% requirements.
%==============================================================
%  Ŀǰû���õ�������̣��ں��ڵĳ���ģ�黯ʱ���Լ�������������ܡ�
    sys = x;    
% End of mdlUpdate.

function sys = mdlOutputs(t,x,u)
%==============================================================
% Calculate outputs, flag = 3�� mdlOutputs
% Return the block outputs. 
%==============================================================
global InitialGapflag;
global VehicleParams;

Ccf_Hat        = 0;
Ccr_Hat        = 0;
Clf_Hat        = 0;
Clr_Hat        = 0;

Fyf_Hat_err    = 0;
Fyr_Hat_err    = 0;
Fxf_Hat_err    = 0;
Fxr_Hat_err    = 0;

alpha_f_Hat    = 0;
alpha_r_Hat    = 0; 
alpha_f_Direct = 0;
alpha_r_Direct = 0;

if InitialGapflag < 3 %  get rid of the first two inputs,  because no data from CarSim
    InitialGapflag = InitialGapflag + 1;
else % start control
    InitialGapflag = InitialGapflag + 1;
    %-----Update State Estimation of measured Vehicle Configuration------%
    [Carsim_export] = func_CarsimData_Parse(u);   
    Vx            = Carsim_export.x_dot; 
    Vy            = Carsim_export.y_dot; 
    yawrate       = Carsim_export.phi_dot; % rad/s
    fwa           = Carsim_export.fwa;
    
    Fyf_Direct    = Carsim_export.Fyf;
    Fyr_Direct    = Carsim_export.Fyr;   
    alpha_f_Direct = Carsim_export.alphaf;
    alpha_r_Direct = Carsim_export.alphar;
    
    kappa_f_Direct = Carsim_export.kappa_f;
    kappa_r_Direct = Carsim_export.kappa_r;
    Fxf_Direct     = Carsim_export.Fxf;
    Fxr_Direct     = Carsim_export.Fxr;
    
    %-----1. Estimate Cornering stiffness use estimated sideslip angle----%  
    %for front tire
    alpha_f_Hat = (Vy + yawrate*VehicleParams.Lf)/Vx - fwa;
    [Fyf_hat, Ccf_Hat] = func_RLSEstimation_Ccf(alpha_f_Hat, Fyf_Direct);
    Fyf_Hat_err = Fyf_hat - Fyf_Direct;
    %for rear tire 
    alpha_r_Hat = (Vy - yawrate*VehicleParams.Lr)/Vx;
    [Fyr_hat, Ccr_Hat] = func_RLSEstimation_Ccr(alpha_r_Hat, Fyr_Direct);
    Fyr_Hat_err = Fyr_hat - Fyr_Direct;
    
    %-----2. Estimate longitudinal stiffness use direct tire slip ratio---%  
    %for front tire
    [Fxf_hat, Clf_Hat] = func_RLSEstimation_Clf(kappa_f_Direct, Fxf_Direct);
    Fxf_Hat_err = Fxf_hat - Fxf_Direct;
    %for rear tire 
    [Fxr_hat, Clr_Hat] = func_RLSEstimation_Clr(kappa_r_Direct, Fxr_Direct);
    Fxr_Hat_err = Fxr_hat - Fxr_Direct;

end % end of if Initialflag < 2 % 
    
sys = [Ccf_Hat; Ccr_Hat; Fyf_Hat_err; Fyr_Hat_err; Clf_Hat; Clr_Hat; Fxf_Hat_err; Fxr_Hat_err; alpha_f_Hat; alpha_r_Hat; alpha_f_Direct; alpha_r_Direct]; % 

% sys = [t_Elapsed; Ax; Ay_G_SM; fwa; Beta; Vel; Vy; yawrate; Roll; Rollrate; vx_hat; vy_hat; yawrate_hat; roll_hat; rollrate_hat; CafHat; CarHat; C_alpha_f_hat_ay; C_alpha_r_hat_ay]; % 
    
%  sys = [Ctrl_SteerSW; CafHat; CarHat; Fyf; Fyr; alphaf; alphar; Arfa_f; Arfa_r];  

% end  %End of mdlOutputs.

%==============================================================
% sub functions
%==============================================================    

%***************************************************************%
% **** State estimation
%***************************************************************%
function [Sparsed_Carsim_Data] = func_CarsimData_Parse(CarsimData)
%***************************************************************%
% Parse data exported from CarSim, ����˳����CarSim�����һ��
%***************************************************************%       
    Sparsed_Carsim_Data.x_dot   = CarsimData(1)/3.6; %Unit:km/h-->m/s������1λС��  
    Sparsed_Carsim_Data.y_dot   = CarsimData(2)/3.6; %Unit:km/h-->m/s������1λС��   
    Sparsed_Carsim_Data.phi_dot = (round(10*CarsimData(3))/10)*pi/180; %Unit��deg/s-->rad/s������1λС��      
    Sparsed_Carsim_Data.fwa     = (round(10*0.5*(CarsimData(4)+ CarsimData(5)))/10)*pi/180; % deg-->rad
    Sparsed_Carsim_Data.alphaf     = (round(10*0.5 * (CarsimData(6)+ CarsimData(8)))/10)*pi/180; % deg-->rad������1λС��   
    Sparsed_Carsim_Data.alphar     = (round(10*0.5 * (CarsimData(7)+ CarsimData(9)))/10)*pi/180; % deg-->rad������1λС��  
    
    Fy_l1      = round(10*CarsimData(10))/10; %Unit:N������1λС��  
    Fy_l2      = round(10*CarsimData(11))/10; %Unit:N������1λС��  
    Fy_r1      = round(10*CarsimData(12))/10; %Unit:N������1λС��  
    Fy_r2      = round(10*CarsimData(13))/10; %Unit:N������1λС��  
    Sparsed_Carsim_Data.Fyf  = Fy_l1 + Fy_r1;
    Sparsed_Carsim_Data.Fyr  = Fy_l2 + Fy_r2;
    
    KappaL1 = CarsimData(14);
    KappaL2 = CarsimData(15);
    KappaR1 = CarsimData(16);
    KappaR2 = CarsimData(17);
    Sparsed_Carsim_Data.kappa_f = 0.5*(KappaL1 + KappaR1);
    Sparsed_Carsim_Data.kappa_r = 0.5*(KappaL2 + KappaR2);
    
    Fx_l1      = round(10*CarsimData(18))/10; %Unit:N������1λС��  
    Fx_l2      = round(10*CarsimData(19))/10; %Unit:N������1λС��  
    Fx_r1      = round(10*CarsimData(20))/10; %Unit:N������1λС��  
    Fx_r2      = round(10*CarsimData(21))/10; %Unit:N������1λС��  
    Sparsed_Carsim_Data.Fxf  = Fx_l1 + Fx_r1;
    Sparsed_Carsim_Data.Fxr  = Fx_l2 + Fx_r2;
    
% end % end of func_StateEstimation


