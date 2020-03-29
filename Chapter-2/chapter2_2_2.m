%---------------------------------------------------------------%
% Published by: Kai Liu
% Email:leoking1025@bit.edu.cn
% My github: https://github.com/leoking99-BIT
%---------------------------------------------------------------%
%% 
% Calculate lateral tire force under pure side slip angle 
% default friction coefficient mu=1.0
alpha=linspace(-10,10,100);   %-10deg~10deg��ֵ20�������ɲ�ƫ�Ǻ�����
r=0;  %����ǣ���Ϊ��
%*************lateral coefficients*******************************%
a0 = 1.65;
a1 = -34;
a2 = 1250;
a3 = 3036;
a4 = 12.8;
a5 = 0.00501;
a6 = -0.02103;
a7 = 0.77394;
a8 = 0.0022890;
a9 = 0.013442;
a10 = 0.003709;
a11 = 19.1656;
a12 = 1.21356;
a13 = 6.26206;

% Calc lateral tire force with Fz=2.5 kN%
Fz   = 2.5;%��ֱ�غɣ���λ��KN

%**********parameters *********************%
Cy   = a0;%������״����
Dy   = a1*Fz^2+a2*Fz;%����������
BCDy = a3*sin(2*atan(Fz/a4))*(1-a5*abs(r));%��������㴦�Ĳ���ն�
By   = BCDy/(Cy*Dy);%�ն�����
Shy  = a9*Fz+a10+a8*r;%���ߵ�ˮƽ����Ư��
ky   = alpha+Shy;%�������X
Svy  = a11*Fz*r+a12*Fz+a13;%���ߵĴ�ֱ����Ư��
Ey   = a6*Fz^2+a7;%������������

%***********lateral force formulation************%
Fy_2_5kN = Dy*sin(Cy*atan(By*ky-Ey*(By*ky-atan(By*ky))))+Svy;%unit:N
Fy_2_5kN = -Fy_2_5kN./1000;%unit:kN

% Calc lateral tire force with Fz=5 kN%
Fz   = 5;%��ֱ�غɣ���λ��KN
Cy   = a0;%������״����
Dy   = a1*Fz^2+a2*Fz;%����������
BCDy = a3*sin(2*atan(Fz/a4))*(1-a5*abs(r));%��������㴦�Ĳ���ն�
By   = BCDy/(Cy*Dy);%�ն�����
Shy  = a9*Fz+a10+a8*r;%���ߵ�ˮƽ����Ư��
ky   = alpha+Shy;%�������X
Svy  = a11*Fz*r+a12*Fz+a13;%���ߵĴ�ֱ����Ư��
Ey   = a6*Fz^2+a7;%������������
Fy_5kN = Dy*sin(Cy*atan(By*ky-Ey*(By*ky-atan(By*ky))))+Svy;%unit:N
Fy_5kN = -Fy_5kN./1000;%unit:kN

% Calc lateral tire force with Fz=8.5 kN%
Fz   = 8.5;%��ֱ�غɣ���λ��KN
Cy   = a0;%������״����
Dy   = a1*Fz^2+a2*Fz;%����������
BCDy = a3*sin(2*atan(Fz/a4))*(1-a5*abs(r));%��������㴦�Ĳ���ն�
By   = BCDy/(Cy*Dy);%�ն�����
Shy  = a9*Fz+a10+a8*r;%���ߵ�ˮƽ����Ư��
ky   = alpha+Shy;%�������X
Svy  = a11*Fz*r+a12*Fz+a13;%���ߵĴ�ֱ����Ư��
Ey   = a6*Fz^2+a7;%������������
Fy_8_5kN = Dy*sin(Cy*atan(By*ky-Ey*(By*ky-atan(By*ky))))+Svy; %unit:N
Fy_8_5kN = -Fy_8_5kN./1000; %unit:kN

% Calc lateral tire force with Fz=14 kN%
Fz   = 14;%��ֱ�غɣ���λ��KN
Cy   = a0;%������״����
Dy   = a1*Fz^2+a2*Fz;%����������
BCDy = a3*sin(2*atan(Fz/a4))*(1-a5*abs(r));%��������㴦�Ĳ���ն�
By   = BCDy/(Cy*Dy);%�ն�����
Shy  = a9*Fz+a10+a8*r;%���ߵ�ˮƽ����Ư��
ky   = alpha+Shy;%�������X
Svy  = a11*Fz*r+a12*Fz+a13;%���ߵĴ�ֱ����Ư��
Ey   = a6*Fz^2+a7;%������������
Fy_14kN = Dy*sin(Cy*atan(By*ky-Ey*(By*ky-atan(By*ky))))+Svy;%unit:N
Fy_14kN = -Fy_14kN./1000;%unit:kN

%% plot result
figure (1);
plot(alpha,Fy_2_5kN,'k',alpha,Fy_5kN,'k+',alpha,Fy_8_5kN,'k--',alpha,Fy_14kN,'k.','LineWidth',2);
grid  
set(gca,'xlim',[-8 8]);                         %����x�᷶Χ 
set(gca,'xtick',[-8:1:8]);                      %����x���� 
set(gca,'ylim',[-15 15])                        %����y�᷶Χ 
set(gca,'ytick',[-15:3:15]);                  %����y���� 
legend('Fz=2.5kN','Fz=5 kN','Fz=8.5 kN','Fz=14 kN');
xlabel('��ƫ��/ (deg)'); 
ylabel('������/��kN��'); 
title('��ͬ��ֱ�غ��µ���̥������(����ƫ)');
