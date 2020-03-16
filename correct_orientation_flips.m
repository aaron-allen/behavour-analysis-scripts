% Aaron M. Allen, 2020.03.15

% Function to attempt to correct orientation flip-flops in tracking data.
% The function looks for frames that have had a change of more than the
% 'low_cutoff'. It then uses pairs of these frame values to define windows
% were the orientation has likely been flipped. It rewrites the tract and 
% feat files, changing the 'ori', 'facing_angle', and 'angle_between'. 


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

% Other requirements:
% Although it's not a parameter for the function, you also need to have a
% file names 'correct_frames.csv' for every video. This file needs to be
% placed in the directory with the 'track.mat' and 'feat.mat' files. This
% file is simply a comma separated list of frames numbers for which the
% orientation is correct for every fly in the video. The first value in the
% list should be for fly id 1, the second value for fly id 2, etc. You need
% to include a value for every fly in the tracking (including the females).


function correct_orientation_flips(input_dir,low_cutoff,high_cutoff)
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
        
        correct_frames = csvread('correct_frames.csv');
        
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
        backups = dir('../Backups/*_oriCorrectionBackup.mat');
        if isempty(backups)
            save(['../Backups/' name '-track_oriCorrectionBackup.mat'], 'trk')
            save(['../Backups/' name '-feat_oriCorrectionBackup.mat'], 'feat')
        end
        
        
        dims = size(trk.data);
        for A = 1:dims(1)
          % disp(['Correcting fly:  ' A]);
          wrong_angle_indices = find_wrong_indices(trk.data(A,:,3),correct_frames(A),low_cutoff,high_cutoff);
          if ~isempty(wrong_angle_indices)
              trk.data(A,wrong_angle_indices,3) = trk.data(A,wrong_angle_indices,3) - pi;
              trk.data(A,:,3) = wrapToPi(trk.data(A,:,3));
              feat.data(A,wrong_angle_indices,12) = pi - feat.data(A,wrong_angle_indices,12);
              feat.data(A,wrong_angle_indices,11) = pi - feat.data(A,wrong_angle_indices,11);
          end
        end

        disp('Saving new track and feat files');
        save([name '-track.mat'], 'trk')
        save([name '-feat.mat'], 'feat')
        
        cd(input_dir);
    end
end



function wrong_angle_indices=find_wrong_indices(input,correct_frame,low_cutoff,high_cutoff)
    delta_anle = diff(input);
    delta_angle_ind = find((delta_anle>low_cutoff & delta_anle<high_cutoff) | (delta_anle<-low_cutoff & delta_anle>-high_cutoff));
    delta_angle_ind(delta_angle_ind < correct_frame) = [];
    starting_ind = delta_angle_ind(1:2:end);
    if ~isempty(starting_ind)
        starting_ind = starting_ind + 1;
        ending_ind = delta_angle_ind(2:2:end);

        if max(starting_ind)>max(ending_ind)
            ending_ind = [ending_ind, length(input)];
        end
        wrong_angle_indices = [];
        for B = 1:(length(starting_ind))
            wrong_angle_indices = [wrong_angle_indices, starting_ind(B):ending_ind(B)];
        end
    else
        wrong_angle_indices = [];
    end
end
