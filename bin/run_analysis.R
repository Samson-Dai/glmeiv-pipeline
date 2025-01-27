#!/usr/bin/env Rscript

##############################
# 0. Set a few hyperparameters
##############################
n_em_rep <- 15
pi_guess_range <- c(0.001, 0.03)
m_perturbation_guess_range <- log(c(0.1, 1.5))
g_perturbation_guess_range <- log(c(5,15))

########################################
# 1. Load packages and command-line args
########################################
library(magrittr)
library(ondisc)
args <- commandArgs(trailingOnly = TRUE)
n_args <- length(args)
covariate_matrix_fp <- args[1L]
gene_odm_fp <- args[2L]
gene_metadata_fp <- args[3L]
m_offsets_fp <- args[4L]
gRNA_odm_fp <- args[5L]
gRNA_metadata_fp <- args[6L]
g_offsets_fp <- args[7L]
other_args <- args[seq(8L, n_args)]

#########################################
# 2. Load ODMs, covariate matrix, offsets
#########################################
gene_odm <- read_odm(gene_odm_fp, gene_metadata_fp)
gRNA_odm <- read_odm(gRNA_odm_fp, gRNA_metadata_fp)
m_offset <- readRDS(m_offsets_fp)
g_offset <- readRDS(g_offsets_fp)
covariate_matrix <- readRDS(covariate_matrix_fp)

#############################################################
# 3. Set vectors of gene IDs, gRNA IDs, and precomp locations
#############################################################
gene_ids <- other_args[seq(from = 1L, by = 4, to = length(other_args))]
gRNA_ids <- other_args[seq(from = 2L, by = 4, to = length(other_args))]
gene_precomp_fps <- other_args[seq(from = 3L, by = 4, to = length(other_args))]
gRNA_precomp_fps <- other_args[seq(from = 4L, by = 4, to = length(other_args))]
n_pairs <- length(gene_ids)

############################################################
# 4. Loop through pairs, running method given precomputation
############################################################
out_l <- vector(mode = "list", length = n_pairs)
for (i in seq(1L, n_pairs)) {
  gene <- gene_ids[i]
  if (i == 1 || gene_ids[i] != gene_ids[i - 1]) { # only load gene data if necessary
    m <- as.numeric(gene_odm[[gene,]]); m_precomp <- readRDS(gene_precomp_fps[i])
  }
  gRNA <- gRNA_ids[i]
  if (i == 1 || gRNA_ids[i] != gRNA_ids[i - 1]) { # likewise for gRNAs
    g <- as.numeric(gRNA_odm[[gRNA,]]); g_precomp <- readRDS(gRNA_precomp_fps[i])
  }
  time <- system.time({fit <- glmeiv::run_glmeiv_given_precomputations(m = m, g = g,
                                                                      m_precomp = m_precomp,
                                                                      g_precomp = g_precomp,
                                                                      covariate_matrix = covariate_matrix,
                                                                      m_offset = m_offset,
                                                                      g_offset = g_offset,
                                                                      n_em_rep = n_em_rep,
                                                                      pi_guess_range = pi_guess_range,
                                                                      m_perturbation_guess_range = m_perturbation_guess_range,
                                                                      g_perturbation_guess_range = g_perturbation_guess_range)
                      s <- glmeiv::run_inference_on_em_fit(fit)})[["elapsed"]]
  s_long <- glmeiv::wrangle_glmeiv_result(s, time, fit) %>% dplyr::mutate(gene_id = gene, gRNA_id = gRNA)
  out_l[[i]] <- s_long
}

out <- do.call(rbind, out_l) %>% dplyr::mutate_at(c("parameter", "target", "gene_id", "gRNA_id"), factor)
saveRDS(object = out, file = "raw_result.rds")
