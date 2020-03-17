% Aaron M. Allen, 2020.03.17

% Function to flips the orientation of flies in user specified frames in 
% tracking data. The function takes frames specified by the user and rewrites 
% the tract and feat files, changing the 'ori', 'facing_angle', and 
% 'angle_between'. This version does not 'auto' detect frames that might be
% flipped.


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


% Other requirements:

% Although it's not a parameter for the function, you also need to have a
% file names 'incorrect_frames.xlsx' for every video. This file needs to be
% placed in the directory with the 'track.mat' and 'feat.mat'. The first
% column of the excel sheet is the Id of the fly that you want to correct.
% Then starting at the second column, you file the row with all frame
% numbers that you want the orientation flipped by 180 degrees (pi
% radians). You don't need to have the same number of columns for each fly,
% just let the list of frames extend as long as you want.



function manually_correct_orientation_flips(input_dir)
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
        
        incorrect_frames = xlsread('incorrect_frames.xlsx');
        
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
         
        for A = 1:size(incorrect_frames,1)
          fly_id = incorrect_frames(A,1);
          wrong_angle_indices = incorrect_frames(A,2:end);
          wrong_angle_indices = wrong_angle_indices(~isnan(wrong_angle_indices));
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

        disp('Saving new track and feat files');
        save([name '-track.mat'], 'trk')
        save([name '-feat.mat'], 'feat')
        
        cd(input_dir);
    end
end




