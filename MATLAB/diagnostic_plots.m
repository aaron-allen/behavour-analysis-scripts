% Aaron M. Allen, 2020.03.18

% DiagnosticPlots.m loads the tracking data .mat files and generates plots of different features.
% These include: area, facing angle, distance to other, x and y postion, amoung others.



function diagnostic_plots(input_dir)

    % Diagnostic Plots
    % =====================================================================
    cd(input_dir); 

    dirs = dir();
    for ii = 1:numel(dirs)
        if ~dirs(ii).isdir
            continue;
        end
        WatchaMaCallIt = dirs(ii).name;
        if ismember(WatchaMaCallIt,{'.','..'})
            continue;
        end
        cd (WatchaMaCallIt);
        errorlogfile = strcat(WatchaMaCallIt,'DiagnosticPlot_errors.log');
        try

            if ~exist('Results/', 'dir')
                mkdir('Results/')
            end
            cd('Results')
            ResultsFolder = pwd;
            cd ..

            load('calibration.mat');
            NumberOfArenas = (calib.n_chambers);
            cd (WatchaMaCallIt);

            % Load Data
            % =====================================================================
            IdCorr = dir('*_id_corrected.mat');
            if length(IdCorr) >=1
                TrackFile = dir('*-track_id_corrected.mat');
                FeatFile = dir('*-feat_id_corrected.mat');

            else
                TrackFile = dir('*-track.mat');
                FeatFile = dir('*-feat.mat');
            end
            load(TrackFile.name);
            load(FeatFile.name);

            % cd ([WatchaMaCallIt '_JAABA']);
            disp(['Now Plotting: ' WatchaMaCallIt]);


            % Setup Current folder name for saving files etc
            % =====================================================================
            CurrFolder = regexp(pwd,'[^/\\]+(?=[/\\]?$)','once','match');



            % Rolling Average to Smooth data:
            % Set the windowsize (in frames) the range you want to average over.
            windowSize = 1; % a value of 1 means no smoothing
            b = (1/windowSize)*ones(1,windowSize);
            a = 1;
            % NB: The velocity plot is very noisy without smoothing, so I have set its
            % own smoothing function with its own window size that you have to be
            % manipulated independently. The Velocity plot code is at line ~210-235.



            NumberOfFlies = 0;
            for A = 1:size(trk.flies_in_chamber,2)
                NumberOfFlies = NumberOfFlies + size(trk.flies_in_chamber{1,A},2);
            end

            PSName = [CurrFolder '_diagnostic_plots.ps'];
            
            for F = 1:size(trk.data,1)/2
                G = (2.*F)-1;     

                % Figure 1
                % =====================================================================
                % =====================================================================
                % Setup Plot - be be saved to the size of A4
                % =====================================================================
                DiagnosticFigure1 = figure('rend','painters','pos',[10 10 900 1200]);
                DiagnosticFigure1.Units = 'centimeters';
                DiagnosticFigure1.PaperType='A4';


                % Area - if a male and female were tracked, and assuming the male is
                % smaller than the female, this lets us see if there were any identity
                % swaps and if the male was correctly identified as track 1.
                % =====================================================================
                y1 = filter(b,a,trk.data(G,:,6)/calib.PPM);
                y2 = filter(b,a,trk.data(G+1,:,6)/calib.PPM);
                subplot(6,1,1)                 
                plot(y2,'m','LineWidth',1)
                fly1 = G;
                fly2 = G+1;
                title([CurrFolder '_Flies_' char(string(fly1)) '_and_' char(string(fly2))], 'Interpreter', 'none');
                xlabel('Frame Number');
                ylabel('Area (unit ?)');
                hold on
                ylim([0 40])
                plot(y1,'b','LineWidth',1)
                hold off

                % Distance to Other - pretty self explanitory
                % =====================================================================
                y11 = filter(b,a,feat.data(G,:,10));
                y12 = filter(b,a,feat.data(G+1,:,10));
                subplot(6,1,2)
                plot(y12,'m','LineWidth',1)
                xlabel('Frame Number');
                ylabel('Distance to Other (mm)');
                ylim([0 20])
                hold on
                plot(y11,'b','LineWidth',1)
                hold off

                % Change in Angle - To identify orientation errors
                % =====================================================================
                % Calculating the instantaneous rate of change in the angle of the fly 
                dThetaM=diff(trk.data(G,:,3));
                dThetaF=diff(trk.data(G+1,:,3));
                % Values of +/-2pi are due to the fly's angle crossing the "zero" line and
                % don't represent 'true' large changes in angle. So I've reset anything
                % larger than 5 to 0.1, making the plot more informative to find the times
                % when the fly's angle changes by pi, which would be an orientation
                % miss-annotation.
                for i = 1:length(dThetaM)
                    if dThetaM(i) > 4
                        dThetaM(i) = 0.1;
                    end
                end
                for i = 1:length(dThetaF)
                    if dThetaF(i) > 4
                        dThetaF(i) = 0.1;
                    end
                end
                for i = 1:length(dThetaM)
                    if dThetaM(i) < -4
                        dThetaM(i) = -0.1;
                    end
                end
                for i = 1:length(dThetaF)
                    if dThetaF(i) < -4
                        dThetaF(i) = -0.1;
                    end
                end
                subplot(6,1,3)
                plot(dThetaF,'m')
                ylim([-4 4])
                xlabel('Frame Number');
                ylabel('Change in Angle');
                hold on
                plot(dThetaM,'b')
                hold off

                % Facing Angle
                % =====================================================================
                y13 = filter(b,a,feat.data(G,:,12));
                y14 = filter(b,a,feat.data(G+1,:,12));
                subplot(6,1,4)
                plot(y14,'m','LineWidth',1)
                xlabel('Frame Number');
                ylabel('Facing Angle (rad)');
                hold on
                ylim([-1 4])
                plot(y13,'b','LineWidth',1)
                hold off

                % Angular Velocity
                % =====================================================================
                % VelWindowSize = 200; 
                % bVel = (1/VelWindowSize)*ones(1,VelWindowSize);
                % y3 = filter(bVel,a,feat.data(G,:,2));
                % y4 = filter(bVel,a,feat.data(G+1,:,2));
                
                y3 = feat.data(G,:,2);
                y4 = feat.data(G+1,:,2);
                               
                subplot(6,1,5)
                plot(y4,'m','LineWidth',1)
                xlabel('Frame Number');
                ylabel('Angular Velocity (rad/s)');
                hold on
                ylim([0 40])
                plot(y3,'b','LineWidth',1)
                hold off
                
                
                % Velocity
                % =====================================================================
                VelWindowSize = 200; 
                bVel = (1/VelWindowSize)*ones(1,VelWindowSize);
                y3 = filter(bVel,a,feat.data(G,:,1));
                y4 = filter(bVel,a,feat.data(G+1,:,1));
                subplot(6,1,6)
                plot(y4,'m','LineWidth',1)
                xlabel('Frame Number');
                ylabel('Velocity (mm/s)');
                hold on
                ylim([0 12])
                plot(y3,'b','LineWidth',1)
                hold off

                % Save PS
                %=====================================================================
                print(DiagnosticFigure1, PSName, '-fillpage',  '-dpsc', '-append', '-r300')





                % Figure 2
                % =====================================================================
                % =====================================================================
                % Setup Plot - be be saved to the size of A4
                % =====================================================================
                DiagnosticFigure2 = figure('rend','painters','pos',[10 10 900 1200]);
                DiagnosticFigure2.Units = 'centimeters';
                DiagnosticFigure2.PaperType='A4';

                % Angle
                % =====================================================================
                y5 = filter(b,a,trk.data(G,:,3));
                y6 = filter(b,a,trk.data(G+1,:,3));
                subplot(6,1,1)
                plot(y6,'m','LineWidth',1)
                fly1 = G;
                fly2 = G+1;
                title([CurrFolder '_Flies_' char(string(fly1)) '_and_' char(string(fly2))], 'Interpreter', 'none');
                xlabel('Frame Number');
                ylabel('Angle (rad)');
                hold on
                ylim([-4 4])
                plot(y5,'b','LineWidth',1)
                hold off

                % X
                % =====================================================================
                y7 = filter(b,a,trk.data(G,:,1));
                y8 = filter(b,a,trk.data(G+1,:,1));
                subplot(6,1,2)
                plot(y8,'m','LineWidth',1)
                xlabel('Frame Number');
                ylabel('X position (px)');
                hold on
                plot(y7,'b','LineWidth',1)
                hold off

                % Y
                % =====================================================================
                y9 = filter(b,a,trk.data(G,:,2));
                y10 = filter(b,a,trk.data(G+1,:,2));
                subplot(6,1,3)
                plot(y10,'m','LineWidth',1)
                xlabel('Frame Number');
                ylabel('Y position (px)');
                hold on
                plot(y9,'b','LineWidth',1)
                hold off

                % a
                % =====================================================================
                y17 = filter(b,a,trk.data(G,:,4)/calib.PPM);
                y18 = filter(b,a,trk.data(G+1,:,4)/calib.PPM);
                subplot(6,1,4)
                plot(y18,'m','LineWidth',1)
                xlabel('Frame Number');
                ylabel('Major Axis (mm)');
                hold on
                ylim([0 5])
                plot(y17,'b','LineWidth',1)
                hold off

                % b
                % =====================================================================
                y17 = filter(b,a,trk.data(G,:,5)/calib.PPM);
                y18 = filter(b,a,trk.data(G+1,:,5)/calib.PPM);
                subplot(6,1,5)
                plot(y18,'m','LineWidth',1)
                xlabel('Frame Number');
                ylabel('Minor Axis (mm)');
                hold on
                ylim([0 3])
                plot(y17,'b','LineWidth',1)
                hold off

                % Axis Ratio
                % =====================================================================
                y15 = filter(b,a,feat.data(G,:,6));
                y16 = filter(b,a,feat.data(G+1,:,6));
                subplot(6,1,6)
                plot(y16,'m','LineWidth',1)
                xlabel('Frame Number');
                ylabel('Axis Ratio');
                hold on
                ylim([0 6])
                plot(y15,'b','LineWidth',1)
                hold off




                % Save PS
                %=====================================================================
                print(DiagnosticFigure2, PSName, '-fillpage',  '-dpsc', '-append', '-r300')

 
                close all
            end
            
            

            
        % Make and move PDFs
        % =====================================================================
        PDFName = [CurrFolder '_diagnostic_plots.pdf'];
        PSList = dir('*.ps');
        ps2pdf('psfile', PSList.name,...
                'pdffile', PDFName, ...
                'gspapersize', 'a4', 'deletepsfile', 1, ...
                'gscommand', 'C:\Program Files\gs\gs9.51\bin\gswin64.exe', ...
                'gsfontpath', 'C:\Program Files\gs\gs9.51\Resource\Font', ...
                'gslibpath', 'C:\Program Files\gs\gs9.51\lib');    
        
        PDFList = dir('*.pdf');
        disp(['Now moving PDFs for: ' WatchaMaCallIt]);
        for x = 1:length(PDFList)
            movefile(PDFList(x).name, ResultsFolder)
        end
        % =====================================================================
    
            
            
        catch ME
            errorMessage= ME.message;
            disp(errorMessage);
            cd (input_dir);
            fidd = fopen(errorlogfile, 'a');
            fprintf(fidd, '%s\n', errorMessage); % To file
            fclose(fidd);
        end
        cd (input_dir);    
    end
    disp('All done plotting.');
end


