function [Ql, Rdun] = func_CostWeightingRegulation(CostWeights, Constraints)

%% ������ʼ��
    Qephi   = CostWeights.Wephi;
    Qey     = CostWeights.Wey;
    RDdeltaf= CostWeights.deltaf;    

    DPhimax = Constraints.DPhimax;  %  0.15 rad ==> 8.5deg
    Dymax   = Constraints.Dymax;
    dumax   = Constraints.dumax;
    
    %% Ȩ�����ӹ�һ��
    Qephi_DPhimax2  = Qephi/(DPhimax*DPhimax);
    Qey_Dymax2      = Qey/(Dymax*Dymax);    
    Ql              = diag([Qephi_DPhimax2, Qey_Dymax2]);
   
    dumax2   = (dumax * dumax);% 
    Rdun     = RDdeltaf/dumax2;
    
    
end % end of func_CostWeightingRegulation