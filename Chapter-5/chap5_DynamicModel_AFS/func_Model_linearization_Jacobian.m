function    [Ad, Bd] = func_Model_linearization_Jacobian(kesi, Sf, Sr, Ccf, Ccr, Clf, Clr, MPCParameters, VehiclePara)
%***************************************************************%
% ���ݼ򻯶���ѧģ��(����С�Ƕȼ�����)�����ſ˱Ⱦ���
% ��������ſ˱Ⱦ������복�����в����������
%---------------------------------------------------------------%
% Published by: Kai Liu
% Email:leoking1025@gmail.com
% My homepage: https://sites.google.com/site/kailiumiracle/  
%***************************************************************%
    %----------������������ -----------%
    syms y_dot x_dot phi phi_dot Y X;%����״̬��
    syms delta_f  %ǰ��ƫ��,������
    
    Ts = MPCParameters.Ts;
    a  = VehiclePara.Lf;
    b  = VehiclePara.Lr;
    m  = VehiclePara.m;
    Iz = VehiclePara.Iz;

    %----��������ѧģ��-------------%
    dy_dot = -x_dot*phi_dot + 2*(Ccf*((y_dot+a*phi_dot)/x_dot - delta_f) + Ccr*(y_dot - b*phi_dot)/x_dot)/m;
    dx_dot = y_dot*phi_dot + 2*(Clf*Sf + Clr*Sr + Ccf*((y_dot + phi_dot*a)/x_dot - delta_f)*delta_f)/m;
    dphi_dot = (2*a*Ccf*((y_dot+a*phi_dot)/x_dot - delta_f) - 2*b*Ccr*(y_dot - b*phi_dot)/x_dot)/Iz;
    Y_dot = x_dot*sin(phi) + y_dot*cos(phi);
    X_dot = x_dot*cos(phi) - y_dot*sin(phi);

    %----�ſ˱Ⱦ������-------------%
    Dynamics_func = [dy_dot; dx_dot; phi_dot; dphi_dot; Y_dot; X_dot];%����ѧģ��
    state_vector = [y_dot,x_dot,phi,phi_dot,Y,X];%ϵͳ״̬��
    control_input = delta_f;
    A_t = jacobian(Dynamics_func, state_vector);  %����A(t)-����
    B_t = jacobian(Dynamics_func, control_input); %����B(t)-����

    %----����������ת��Ϊ��ɢ����-------------%
    % ����Forward Euler Method�����㷨  A = I+Ts*A(t),B = Ts*B(t)
    I_6 = eye(6);
    Ad_temp = I_6 + Ts * A_t;
    Bd_temp = Ts * B_t;

    %----��ȡ����״̬����-------------%
    y_dot   = kesi(1);
    x_dot   = kesi(2);
    phi     = kesi(3);
    phi_dot = kesi(4);
    Y       = kesi(5);
    X       = kesi(6);
    delta_f = kesi(7);
    
    Ad = eval(Ad_temp);
    Bd = eval(Bd_temp);
    
end % end of func.