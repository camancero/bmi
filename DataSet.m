classdef DataSet
    %% Define Properties
    properties (Constant)
    Nt = 570;
    Nd = 8;
    Ntr = 100;
    dt = 0.001;
    end
    
    properties
    Nn = 98
    Dir = {};    
    end
    
    methods
        %% Constructor
        function D = DataSet(data,N)  
            %Look for every direction
            for d = 1:D.Nd
                %Temp Struct Time
                temp = struct;
                S = zeros(D.Nn,D.Nt-1);
                X = zeros(2,D.Nt);
                V = zeros(2,D.Nt-1);  
                %Look for every trial
                for n = N(1):N(2)
                    %Local Data    
                    trial = data(n,d);
                    s = trial.spikes(:,2:D.Nt);
                    x = trial.handPos(1:2,1:D.Nt);
                    v = diff(x')';
                    %Spike, Position, Velocity,TrialMean
                    %Trial
                    S = S + s;
                    X = X + x;
                    V = V + v;
                end
            %Average   
            Ntr = N(2) - N(1) + 1;   
            temp.Spikes = S/Ntr;
            temp.Position = X/Ntr;
            temp.Velocity = V/Ntr;
            %Append
            D.Dir{d} = temp;
            end
        end
        %% Operations
        %Convolution
        function D = Convolution(D,w,FieldIn,FieldOut)
            Nw = length(w);
            Nw_half = floor(Nw/2);
            for d = 1:D.Nd
                temp = [];
                    for i = 1:D.Nn
                        f = D.Dir{d}.(FieldIn);
                        %Convolution with Window
                        r = conv(w,f(i,:));
                        %Trim
                        temp(i,:) = r(Nw_half+1:end-Nw_half);
                    end
                D.Dir{d}.(FieldOut) = temp;
            end 
        end
        %% Edit
        %Eliminate Neurons
        function D = EliminateUnit(D,Index,Field)
            for d = 1:D.Nd
                D.Dir{d}.(Field) = removerows(D.Dir{d}.(Field),'ind',Index);
            end
            D.Nn = D.Nn - length(Index);
        end
        %Normalisation
        function D = BaseLineNormalisation(D,Field,Tcut)
            for d = 1:D.Nd
                F = D.Dir{d}.(Field);
                f = [];
                for i = 1:D.Nn
                    %Base Firing
                    B = mean(F(i,1:Tcut));
                    %Normalise
                    f(i,:) = (F(i,:)-B)/(max(F(i,:))- B); 
                end
                %Append
                D.Dir{d}.(Field) = f;
            end
        end
        
        %% Output
        function [W,E,N] = GetPreDirection(D,a)
        %Preferred Direction
        temp = [];
            V = [];
            F = [];
            for d = 1:D.Nd
                v = D.Dir{d}.Velocity';
                V = [V;v];
                %Firing Matrix
                f = D.Dir{d}.FiringRate'; 
                F = [F;f];               
            end
            %Add Line Constant
            [Nv,~]  = size(V); 
            V = [ones(Nv,1),V];
            
            B = (V'*V+a(1)*ones(3,3))^-1*V'*F;
            Bm = mean(B,2);
            
            %Norm
            N = [];
            for i = 1:D.Nn
                %B(:,i) = B(:,i) - Bm; 
                N(i) = norm(B(:,i));
            end
            
            %Preferred Direction
            figure
            hold on
            for i = 1:D.Nn
                plot([0,B(2,i)],[0,B(3,i)])
            end
            %Error
            E = F-V*B;
            %Error Bar 
            figure
            bar(mean(abs(E)))
            
            %Variance of the Residuals
            s = ones(1,D.Nn)./var(E);
            S = diag(s);
            W = pinv(B*S*B' + a(2)*ones(3,3))*B*S;
        end
        
        %% Test
        function L = MeanTest(W,Test)
            %Create Figure
            h1 = figure();
            hold on
            axis equal
            h2 = figure();
            subplot(2,4,1);
            
            %For Each Direction
            L = {};
            for d = 1:Test.Nd
                %Plot X and V
                F = Test.Dir{d}.FiringRate;
                X = zeros(3,Test.Nt);
                V = zeros(3,Test.Nt-1);
                    for t = 1:Test.Nt-1
                        %Regress
                        V(:,t) = W*(F(:,t));
                        X(:,t+1) = X(:,t) + V(:,t);    
                    end
                    
                %Position
                figure(h1)
                plot(X(2,:),X(3,:))
                
                %Error
                Vreal = Test.Dir{d}.Velocity;
                L{d} = [ones(1,Test.Nt-1);Vreal] - V;
                
                figure(h2)
                subplot(2,4,d)
                hold on
                l = plot(V');
                set(l(2),'Color','b')
                set(l(3),'Color','b','LineStyle','--')
                l = plot(Vreal');
                set(l(1),'Color','r')
                set(l(2),'Color','r','LineStyle','--')
            end 
        end
    end

    methods (Static)
        %Produce Unit Vector
        function V = UnitVector(V,Nn)
           for i = 1:Nn
               v = norm(V(:,i));
               V(:,i) = V(:,i)/v; 
           end
        end
    end
end