function [true_positive_count, multi_match_count, false_positive_count, false_negative_count, bout_matches, machine_bout_lengths] = compute_bout_precision_recall(movie, fly, bout_candidates, behav_labels, labels_of_interest)
    % Match bouts from human annotation w. frame-wise behavior labels
    % (integer or binary) generated by any anutomated analysis program, 
    % for a single fly
    
    % Convert behav_labels to a flymat-like structure, by compiling bouts
    % of the behavior type that is of interest
    behav_mask_cell = arrayfun(@(label) behav_labels == label, labels_of_interest, 'UniformOutput', false);
    behav_mask = sum(horzcat(behav_mask_cell{:}), 2);
    if sum(behav_mask)
        behav_frame_numbers = find(behav_mask);
        behav_bout_end_idxs = find(diff(behav_frame_numbers) ~= 1);
        behav_bout_start_idxs = [1; behav_bout_end_idxs + 1];
        behav_bout_end_idxs = [behav_bout_end_idxs; length(behav_frame_numbers)];
        behav_bout_lengths = behav_bout_end_idxs - behav_bout_start_idxs + 1; 
        behav_bouts_cell = mat2cell(behav_frame_numbers, behav_bout_lengths, 1);
        machine_bout_starts = cellfun(@min, behav_bouts_cell); 
        machine_bout_ends = cellfun(@max, behav_bouts_cell) + 1; 
        machine_bout_lengths = machine_bout_ends - machine_bout_starts; 
    else
        machine_bout_starts = [];
        machine_bout_ends = [];
        machine_bout_lengths = [];
    end
    
    bout_matches_new_fields = {'machine_bout_start', 'machine_bout_end', ...
                'multi_match', 'virtual_machine_match'};
    
    bout_matches = bout_candidates;
    bout_matches_old_fields = fieldnames(bout_matches);
    for i=1:length(bout_matches_old_fields)
        if any(contains(bout_matches_old_fields{i}, {'jaaba', 'invalid_match'}))
            bout_matches = rmfield(bout_matches, bout_matches_old_fields{i});
        end
    end
    
    if isempty(bout_candidates)
        bout_matches(1).annot_union_start = nan; 
    end
    for i=1:length(bout_matches)
        for j=1:length(bout_matches_new_fields)
            bout_matches(i).(bout_matches_new_fields{j}) = nan;
        end
    end
    if isempty(bout_candidates)
        bout_matches(1) = [];
    end
    
    init_bout_matches_args = [fieldnames(bout_matches)'; cell(1,length(fieldnames(bout_matches)))];
    
    for k=1:length(machine_bout_starts)
        matched = 0;
        for m=1:length(bout_matches)
            % Declare a match if there is any overlap between annotated
            % bout and machine bout
            if (machine_bout_starts(k) <= bout_matches(m).annot_union_start ...
                    && machine_bout_ends(k) > bout_matches(m).annot_union_start) ...
                || ...
                (machine_bout_starts(k) > bout_matches(m).annot_union_start ...
                    && machine_bout_starts(k) < bout_matches(m).annot_union_end)
                if isnan(bout_matches(m).machine_bout_start)
                    bout_matches(m).machine_bout_start = ...
                        machine_bout_starts(k); 
                    bout_matches(m).machine_bout_end = ...
                        machine_bout_ends(k);
                else
                    bout_matches(m).machine_bout_start = ...
                        [bout_matches(m).machine_bout_start, machine_bout_starts(k)]; 
                    bout_matches(m).machine_bout_end = ...
                        [bout_matches(m).machine_bout_end, machine_bout_ends(k)];
                end
                bout_matches(m).virtual_machine_match = false;
                if ~matched
                    matched = m;
                    bout_matches(m).multi_match = false;
                else
                    % bout_matches(matched).multi_match = true;
                    bout_matches(m).multi_match = true;
                end
            end
        end
        % If no match is found for a machine-identified bout, add it to bout_matches
        if ~matched
            bout_match = struct(init_bout_matches_args{:});
            bout_match.movie = movie;
            bout_match.fly = fly;
            bout_match.annot_union_start = nan;
            bout_match.annot_union_end = nan;
            bout_match.annot_score = 0;
            bout_match.machine_bout_start = machine_bout_starts(k);
            bout_match.machine_bout_end = machine_bout_ends(k);
            bout_match.virtual_machine_match = false;
            bout_match.multi_match = false; 
            bout_matches(length(bout_matches)+1) = bout_match;
        end
    end

    % If no match is found for an existing human annotation, use
    % intersection of human annotation (consensus) as a virtual machine bout 
    for j=1:length(bout_matches)
        if isnan(bout_matches(j).machine_bout_start)
            bout_matches(j).machine_bout_start = nan;
            bout_matches(j).machine_bout_end = nan;
            bout_matches(j).virtual_machine_match = true;
        end
    end
    
    % Compute bout-wise precision and recall
    annot_score = cellfun(@(scores) max(scores), {bout_matches(:).annot_score});
    false_negat_idxs = [bout_matches(:).virtual_machine_match];
    multi_match_idxs = [bout_matches(:).multi_match];
    multi_match_idxs(isnan(multi_match_idxs)) = 0;
    
    true_positive_count = sum(bitand(annot_score > 0, ~false_negat_idxs));
    multi_match_count = sum(multi_match_idxs);
    false_positive_count = sum(bitand(annot_score == 0, ~false_negat_idxs));
    false_negative_count = sum(false_negat_idxs);
    % recall = 1 - sum(false_negat_idxs)/sum(bitand(annot_score > 0, ~multi_match_idxs));
    % precision = sum(bitand(annot_score > 0, ~false_negat_idxs))/sum(~false_negat_idxs);
end