% Aaron M. Allen, 2020.03.18

% Little function to go into the 'Backups/' directory and copy the
% 'oriCorrectionBackup_initial' track and feat files back into the primary
% tracking folder. Also saves a copy of what were the current (ie modified)
% track and feat files in the 'Backups/' directory with filenames like
% '_oriCorrectionBackup_yyyymmdd_HHMMSS.mat'. 


% Parameters:
% 'input_dir' - the full path to the directory of tracked videos, assuming
%               the usual directory structure generated from our tracking 
%               pipeline (i.e. the directory like '2020_03_02_Courtship')




function reset_track_and_feat(input_dir)
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

        disp(['Reseting old track and feat files for video: ' name]);
        
        disp('Saving modified track and feat files in Backups directory');
        TrackFile = dir('*-track.mat');
        FeatFile = dir('*-feat.mat');
        load(TrackFile.name);
        load(FeatFile.name);

        save(['../Backups/' name '-track_oriCorrectionBackup_' ...
            datestr(now,'yyyymmdd_HHMMSS') '.mat'], 'trk')
        save(['../Backups/' name '-feat_oriCorrectionBackup_' ...
            datestr(now,'yyyymmdd_HHMMSS') '.mat'], 'feat')
        
        feat_backup = dir('../Backups/*feat_oriCorrectionBackup_initial_*');
        track_backup = dir('../Backups/*track_oriCorrectionBackup_initial_*');
        load(['../Backups/' feat_backup.name]);
        load(['../Backups/' track_backup.name]);
        
        disp('Reseting original track and feat files');
        save([name '-track.mat'], 'trk')
        save([name '-feat.mat'], 'feat')
        cd(input_dir);

    end
end
    
    
    
    
    