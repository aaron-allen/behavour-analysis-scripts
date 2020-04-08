% Aaron M. Allen, 2020.03.15

% Function to attempt to correct orientation flip-flops in tracking data.
% The function looks for frames that have had a change of more than the
% 'low_cutoff'. It then uses pairs of these frame values to define windows
% were the orientation has likely been flipped. It rewrites the tract and 
% feat files, changing the 'ori', 'facing_angle', and 'angle_between'.

% Backups of the 'track.mat' and 'feat.mat' file are made and placed in the 
% 'Backups/' directory. If the 'Backups/' directory doesn't exist, then it 
% is created. The first run will create a
% '_oriCorrectionBackup_initial_yyyymmdd_HHMMSS.mat' file. Any subsequent
% runs will create separate backups named
% '_oriCorrectionBackup_yyyymmdd_HHMMSS.mat'.


% Parameters:
% 'input_dir' - the full path to the directory of tracked videos, assuming
%               the usual directory structure generated from our tracking 
%               pipeline (i.e. the directory like '2020_03_02_Courtship')
% 'low_cutoff' - value in radians of the minimum change in angle to be
%                treated as an orientation flip
% 'high_cuttoff' - value in radians of the maximum change in angle to be
%                  treated as an orientation flip (this is to exclude the
%                  times when the orientation angle crosses the -pi/pi line
%                  which results in a 2pi change in angle - I have been
%                  using 5 for this value)
% 'diag_plots' - 'true' or 'false', whether to generate diagnostic plots of
%                the current changes. This was the 'diagnostic_plots' pdf
%                will be up to date and reflect any changes made. Also
%                useful in conjunction with 'save_changes' if you want to
%                test values for 'low_cutoff' and 'high_cuttoff'.
% 'save_changes' - 'true' or 'false', whether to save any changes to the
%                  'track' and 'feat' files.



% Other requirements:

% Although it's not a parameter for the function, you also need to have a
% file names 'correct_frames.xlsx' for every video. This file needs to be
% placed in the directory with the 'track.mat' and 'feat.mat'. This file is
% 3 columned spreadsheet with the first row filled in with the Id's of the 
% flies that you want to correct. The second column is start point that you
% want to be correcting from (Important: the orientation needs to already
% be correct in this frame). The third column is the frame you want to
% correct to.




function correct_orientation_flips(input_dir,low_cutoff,high_cutoff,diag_plots,save_changes)
    cd(input_dir);
    dirs = dir();
    for p = 1:numel(dirs)
        if ~dirs(p).isdir
          continue;
        end
        name = dirs(p).name;
        if ismember(name,{'.','..'})
          continue;
        end
        cd(name);
        cd(name);
        disp(['Correcting video:  ' name]);
        
        % correct_frames = csvread('correct_frames.csv');
        correct_frames = xlsread('correct_frames.xlsx');
        
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

        if save_changes == true
            disp('Saving backups');
            if ~exist('../Backups/', 'dir')
                mkdir('../Backups/')
            end

            backups = dir('../Backups/*_oriCorrectionBackup*');
            if isempty(backups)
                save(['../Backups/' name '-track_oriCorrectionBackup_initial_' ...
                    datestr(now,'yyyymmdd_HHMMSS') '.mat'], 'trk')
                save(['../Backups/' name '-feat_oriCorrectionBackup_initial_' ...
                    datestr(now,'yyyymmdd_HHMMSS') '.mat'], 'feat')
            else
                save(['../Backups/' name '-track_oriCorrectionBackup_' ...
                    datestr(now,'yyyymmdd_HHMMSS') '.mat'], 'trk')
                save(['../Backups/' name '-feat_oriCorrectionBackup_' ...
                    datestr(now,'yyyymmdd_HHMMSS') '.mat'], 'feat')
            end
        end
        
        for A = 1:size(correct_frames,1)
          % disp(['Correcting fly:  ' A]);
          fly_id = correct_frames(A,1);
          wrong_angle_indices = find_wrong_indices(trk.data(fly_id,:,3), ...
              correct_frames(A,2),correct_frames(A,3),low_cutoff,high_cutoff);
          if ~isempty(wrong_angle_indices)
              trk.data(fly_id,wrong_angle_indices,3) = ...
                  trk.data(fly_id,wrong_angle_indices,3) - pi;
              trk.data(fly_id,:,3) = wrapToPi(trk.data(fly_id,:,3));
              feat.data(fly_id,wrong_angle_indices,12) = ...
                  pi - feat.data(fly_id,wrong_angle_indices,12);
              feat.data(fly_id,wrong_angle_indices,11) = ...
                  pi - feat.data(fly_id,wrong_angle_indices,11);
          end
        end

         
        if save_changes == true
            disp('Saving new track and feat files');
            save([name '-track.mat'], 'trk')
            save([name '-feat.mat'], 'feat')
        end
        
        cd(input_dir);
    end
    
    if diag_plots == true
        diagnostic_plots(input_dir) 
    end

end



function wrong_angle_indices=find_wrong_indices(input,first_frame,last_frame,low_cutoff,high_cutoff)
    delta_angle = diff(input);
    delta_angle_ind = find((delta_angle>low_cutoff & delta_angle<high_cutoff) ...
        | (delta_angle<-low_cutoff & delta_angle>-high_cutoff));
    delta_angle_ind(delta_angle_ind < first_frame) = [];
    delta_angle_ind(delta_angle_ind > last_frame) = [];
    starting_ind = delta_angle_ind(1:2:end);
    if ~isempty(starting_ind)
        starting_ind = starting_ind + 1;
        ending_ind = delta_angle_ind(2:2:end);

        if isempty(ending_ind)
            ending_ind = [ending_ind, last_frame];
        elseif max(starting_ind) > max(ending_ind)
            ending_ind = [ending_ind, last_frame];
        end
        
        wrong_angle_indices = [];
        for B = 1:(length(starting_ind))
            wrong_angle_indices = [wrong_angle_indices, starting_ind(B):ending_ind(B)];
        end
    else
        wrong_angle_indices = [];
    end
end
