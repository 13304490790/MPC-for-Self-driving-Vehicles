function [WPIndex, RefP, RefK, Uaug, PrjP] = func_RefTraj_LocalPlanning( MPCParameters, VehiclePara, WayPoints_Index, WayPoints_Collect, VehStateMeasured)
%***************************************************************%
% �����ҵ�ȫ��·���Ͼ��복������ĵ� (�൱��ͶӰ��)
% ��Σ����ݲ���������sѡ��һЩ�вο��㲢ת������������ϵ�¡��ο������Ϣ����[s,x,y]
% �ٴΣ��Գ�������ϵ�µ�x,y��Bezier���߲�ֵ����������������������ĺ���Ǻ����ʡ�
% ��󣬽��ο���Ĳ�������RefP, RefU��Uaug
%
% Input:
% MPCParameters��
% WayPoints_Index
% WayPoints_Collect
% VehStateMeasured
% 
% Output:
% WPIndex�� 
%     > 0��Normal, WPIndex = index_min;
%     0:error,index_min<1
%     -1: index_min = WPNum,����ȫ��·���ľ�ͷ��ͣ��

%---------------------------------------------------------------%
% Published by: Kai Liu
% Email:leoking1025@gmail.com
% My homepage: https://sites.google.com/site/kailiumiracle/  
%***************************************************************%

%*********** Parameters Initialization *************************% 
    L       = VehiclePara.L;   % �������
    Np      = MPCParameters.Np;% Ԥ��ʱ��
    Ts      = MPCParameters.Ts; % Set the sample time

    %------Measured or Estimated vehicle status
    Vel     = VehStateMeasured.x_dot;
    PosX    = VehStateMeasured.X;
    PosY    = VehStateMeasured.Y;
    PosPsi  = VehStateMeasured.phi;      
    
%*********** WaypointData2VehicleCoords ************************% 
    ds          = 0.1;%unit:m, ·����֮��ľ���
    WPNum       = length(WayPoints_Collect(:,1));
    
    %--------���ҵ��ο�·���Ͼ��복������ĵ�--------------------------%  
    Dist_MIN    = 10000;
    index_min   = 0;
    for i = WayPoints_Index:1:WPNum 
        deltax  = WayPoints_Collect(i,2) - PosX;
        deltay  = WayPoints_Collect(i,3) - PosY;
        Dist    = sqrt(power(deltax,2) + power(deltay,2));% ·�㵽�������ĵľ���
        if Dist < Dist_MIN
            Dist_MIN  = Dist; 
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
    

    if( WPIndex > 0 )   % ����ҵ��������
    %% ѡ��ͶӰ�㣬 ȫ��·����ѡ��ο��㣬��ת�������������¡�   
        %--------------ͨ��������ͶӰ��--------------------------%
        [PPx,PPy,ey]=func_GetProjectPoint(WayPoints_Collect(index_min,2),... 
                                            WayPoints_Collect(index_min,3),... 
                                            WayPoints_Collect(index_min+1,2),... 
                                            WayPoints_Collect(index_min+1,3),... 
                                            PosX,... 
                                            PosY);
        Dy          = WayPoints_Collect(index_min+1,3) - WayPoints_Collect(index_min,3);
        Dx          = WayPoints_Collect(index_min+1,2) - WayPoints_Collect(index_min,2);
        Psi0        = atan2(Dy, Dx); % [-pi, pi]
        epsi        = PosPsi - Psi0;% �������� - ��·���򣬣���ʱ��Ϊ����
        
        PrjP.epsi   = epsi;%
        PrjP.ey     = ey;%ey�ķ�����Ϊ������,��������ڲο���·
        PrjP.Velr   = Vel;                                        
        PrjP.xr     = PPx;
        PrjP.yr     = PPy;
        PrjP.psir   = Psi0;
        PrjP.fwar   = 0; %atan(Kprj*L);  

        %-------------------i=1:Np--���ݳ�����ȫ�ֲο�·����ѡ��ο���-------%
        Local_Sx        = [];
        Local_Sy        = [];
        StepLength_S    = Vel * Ts *  (Np+1);% ���һ����Ϊ������������ʱ׼��
            
        tempDx          = WayPoints_Collect(index_min+1,2) - PPx;
        tempDy          = WayPoints_Collect(index_min+1,3) - PPy;
        Dist_1          = sqrt(power(tempDx,2) + power(tempDy,2)); %·�㵽ͶӰ��ľ��� 

        for i=index_min:1:WPNum %�ڲο�·����ѡ��ο���,��ͨ��������תת������������ϵ��
            deltax          = WayPoints_Collect(i,2) - PosX;
            deltay          = WayPoints_Collect(i,3) - PosY;
            CarCoord_x      = deltax * cos(PosPsi) + deltay * sin(PosPsi);
            CarCoord_y      = deltay * cos(PosPsi) - deltax * sin(PosPsi); % ȫ��·����ת�����ֲ�������              
            Local_Sx        = [Local_Sx; CarCoord_x];
            Local_Sy        = [Local_Sy; CarCoord_y];  %�洢�ֲ������µĵ�  
                    
            Dist_SumS       = Dist_1 + WayPoints_Collect(i,7) - WayPoints_Collect(index_min+1,7);  
            if(Dist_SumS >= StepLength_S)
                break;
            end            
        end % end of   for I=index_min+1:1:WPNum           
        
        %%
        %------------����ʽ�������------------%
        if(Dist_SumS < StepLength_S)
           WPIndex = 0; %���û���ҵ��򡣡� % reaching the end ... %--����û�п���������ȫ��·����󼸸���ʱ������������걸���п��ܻᱨ������           
        else
             %----Bezier������ϣ��ŵ����ڿ��Զ������-----%
            MatS(:,1)=Local_Sx; 
            MatS(:,2)=Local_Sy;             
            [ps0,ps1,ps2,ps3,ts] = func_FindBezierControlPointsND(MatS,'u'); %uniform parameterization
            Scale                = round(Vel*Ts/ds);
            tlocS                = linspace(0,1,Scale*(Np+1)+1);   %����㵽�յ�Ⱦ�=0.1m����,����Np+1���Σ�Scale*��Np+1��+1����
            MatLocalInterpS      = func_bezierInterp( ps0, ps1, ps2, ps3,tlocS);   % ���߲�ֵ�õ�������       
            
            Bezier_Sx       = zeros(Np,1);
            Bezier_Sy       = zeros(Np,1);
            Bezier_Spsi     = zeros(Np,1);
            Bezier_SK       = zeros(Np,1);         
            for i = 2:1:Np+1
                Bezier_Sx(i-1)    = MatLocalInterpS(Scale*(i-1),1);
                Bezier_Sy(i-1)    = MatLocalInterpS(Scale*(i-1),2);
                tempDx            = MatLocalInterpS(Scale*(i-1)+1,1) - MatLocalInterpS(Scale*(i-1),1);
                tempDy            = MatLocalInterpS(Scale*(i-1)+1,2) - MatLocalInterpS(Scale*(i-1),2);
                Bezier_Spsi(i-1)  = atan2(tempDy, tempDx);
                
                Bezier_SK(i-1)    = func_CalPathCurve_Patent(MatLocalInterpS(Scale*(i-1)-1,1),... 	% XA
                                       MatLocalInterpS(Scale*(i-1)-1,2),...    % YA
                                       MatLocalInterpS(Scale*(i-1),1),...      % XB
                                       MatLocalInterpS(Scale*(i-1),2),...      % YB
                                       MatLocalInterpS(Scale*(i-1)+1,1),...    % XC
                                       MatLocalInterpS(Scale*(i-1)+1,2));      % YC            
            end % end of  for i = 2:1:length(MatLocalInterp(:,1))-1
            
    %%
        RefP    = cell(Np,1);        
        RefK    = cell(Np,1); 
        Uaug    = cell(Np,1);      
        for i = 1:1:Np
           Uaug{i,1} = atan(Bezier_SK(i)*L);  
           RefK{i,1} = -Bezier_SK(i);     
           RefP{i,1} = [Bezier_Sx(i);
                        Bezier_Sy(i);
                        Bezier_Spsi(i)]; 
        end

        end % end of if(Dist_SumS < StepLength_S) || (Dist_SumL < StepLength_L)
        
    end % end of if( WPIndex > 0 )   % ����ҵ��������

end % end of function 


%==============================================================%
% sub functions
%==============================================================%   
function K=GetPathHeading(Xb,Yb,Xn,Yn)
    %***Way I.��Heading Angle ��[-pi,pi]֮�� *******%
    AngleY=Yn-Yb;
    AngleX=Xn-Xb;
    K= atan2(AngleY, AngleX);
    
    %***Way II. ��Heading Angle ��0~2*pi֮�� *******%
%     AngleY=Yn-Yb;
%     AngleX=Xn-Xb;    
%     
%     if Xb==Xn
%         if Yn>Yb
%             K=pi/2;
%         else
%             K=3*pi/2;
%         end
%     else
%         if Yb==Yn
%             if Xn>Xb
%                 K=0;
%             else
%                 K=pi;
%             end
%         else
%             K=atan(AngleY/AngleX);
%         end    
%     end
% 
%     %****����K,ʹ֮��0~360��֮��*****%
%    if (AngleY>0&&AngleX>0)%��һ����
%         K=K;
%     elseif (AngleY>0&&AngleX<0)||(AngleY<0&&AngleX<0)%�ڶ���������
%         K=K+pi;
%     else if (AngleY<0&&AngleX>0)%��������
%             K=K+2*pi;  
%         else
%             K=K;
%         end
%    end
    
end % end of function

function [PPx,PPy,de]=func_GetProjectPoint(Xb,Yb,Xn,Yn,Xc,Yc)
%-------------------------------------------------------%
% ͨ���㵽ֱ�ߵľ��붨��Ϊ�������Ҹ�
% ����de��㵽ֱ�ߵľ���ķ����岻ͬ�������෴��
% ���� de�ķ�����Ϊ������
%-------------------------------------------------------%

    if Xn==Xb
        x=Xn;
        y=Yc;
        de=Xc-Xn;
    else if Yb==Yn
            x=Xc;
            y=Yn;
            de=Yn-Yc;
        else
            DifX=Xn-Xb;
            DifY=Yn-Yb;
            Kindex=DifY/DifX;
            bindex=Yn-Kindex*Xn;
            
            K=(-1)*1/Kindex;
            b=Yc-K*Xc;
            x=(bindex-b)/(K-Kindex);
            y=K*x+b;
            de=(Kindex*Xc+bindex-Yc)/sqrt(1+Kindex*Kindex);
        end     
    end
    PPx=x;
    PPy=y;
       
end

function K=func_CalPathCurve_Patent(XA,YA,XB,YB,XC,YC)
    %% 
    x_dot       = XC - XA;
    y_dot       = YC - YA;
    x_dotdot    = XC + XA - 2*XB;
    y_dotdot    = YC + YA - 2*YB;
    temp        = x_dot*x_dot + y_dot*y_dot;
    K= 4*(x_dot*y_dotdot - x_dotdot*y_dot )/ power(temp, 1.5);

end








