#!/bin/bash
# -*- coding: utf-8 -*-
# Copyright 2012-2014 Jan-Philip Gehrcke, BIOTEC, TU Dresden
# http://gehrcke.de

python merge_per_run_data.py
python evaluate_merged_data.py per_run_data_merged.dat



if [ ! -d cluster_analysis ]; then
    mkdir cluster_analysis
fi
cd cluster_analysis

cluster-pdb-structures --cluster-dir-prefix "dbscan_opt_minmembers_4" \
    --cluster-method dbscan --optimize --min-members=4 \
    --clean-directories --not-interactive \
    ../system_state_pdb_files/freemd_final_states_aftermin_recaligned_ligandonly/*.pdb

cluster-pdb-structures --cluster-dir-prefix "dbscan_opt_minmembers_3" \
    --cluster-method dbscan --optimize --min-members=3 \
    --clean-directories --not-interactive \
    ../system_state_pdb_files/freemd_final_states_aftermin_recaligned_ligandonly/*.pdb

cluster-pdb-structures --cluster-dir-prefix "dbscan_opt_minmembers_5" \
    --cluster-method dbscan --optimize --min-members=5 \
    --clean-directories --not-interactive \
    ../system_state_pdb_files/freemd_final_states_aftermin_recaligned_ligandonly/*.pdb

cluster-pdb-structures --cluster-dir-prefix "dbscan_minp4_eps3" \
    --cluster-method dbscan --epsilon 3 --minpoints 4 \
    --clean-directories --not-interactive \
    ../system_state_pdb_files/freemd_final_states_aftermin_recaligned_ligandonly/*.pdb

for DIR in *; do
    if [ ! -d "$DIR" ]; then
        continue
    fi
    python ../get_cluster_stats.py --histogrampdffile \
        "$DIR"_histograms.pdf "$DIR" ../per_run_data_merged.dat
    if [ $? -ne 0 ]; then
        echo "Abort loop due to error." >&2
        exit 1
    fi
done

